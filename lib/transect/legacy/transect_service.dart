import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../kalman_filter_2d.dart';

enum AccuracyMode { openTrail, forest }

class TransectService {
  static const EventChannel _gnssChannel = EventChannel('bms/gnss');
  static const String _activeTransectStateKey = 'active_transect_state';

  // ================= SINGLETON =================
  static final TransectService _instance = TransectService._internal();
  factory TransectService() => _instance;
  TransectService._internal();

  AccuracyMode accuracyMode = AccuracyMode.forest;
  // ================= METADATA =================
  double _accuracyAvg = 0;
  int _accuracySamples = 0;
  DateTime _lastGnssTime = DateTime.fromMillisecondsSinceEpoch(0);

  String? ecosystemType; // Mossy Forest, Dipterocarp, etc
  List<String> observers = []; // Names
  String speciesGroup = 'Flora'; // Flora / Fauna
  String? weather;
  String? bmsLocation;
  String? assessmentPeriod;
  int? assessmentYear;

  // ================= ORIENTATION =================
  double gpsBearing = 0;
  double compassHeading = 0;
  double _stableHeading = 0;
  Position? _lastPosition;
  double _lastBearing = 0;
  double? committedLat;
  double? committedLng;

  DateTime? _lastAcceptedTime;
  DateTime? _lastKalmanTime;

  StreamSubscription? _gpsSub;
  StreamSubscription? _compassSub;
  StreamSubscription? _gnssSub;
  final ValueNotifier<int> hudTick = ValueNotifier(0);
  final ValueNotifier<int> mapTick = ValueNotifier(0);

  // 🔧 Tuned for walking (AlpineQuest-like)
  final KalmanFilter2D _kalman = KalmanFilter2D(
    processNoise: 0.8,
    measurementNoise: 4,
  );

  // ================= CORE =================
  String? activeTransectId;
  DateTime? transectStart;
  DateTime? transectEnd;

  double startLat = 0;
  double startLng = 0;
  double endLat = 0;
  double endLng = 0;

  double startElevation = 0;
  double endElevation = 0;

  // 🔥 DISPLAY POSITION (USED BY MAP)
  double currentLat = 0;
  double currentLng = 0;
  double currentElevation = 0;
  double? _lastRawLat;
  double? _lastRawLng;

  // 🔥 RAW GPS (NOT USED FOR DISPLAY)
  double rawLat = 0;
  double rawLng = 0;

  String? selectedTransectId;

  double distanceMeters = 0;
  double minElevation = 99999;
  double maxElevation = 0;

  double? _lastSmoothLat;
  double? _lastSmoothLng;

  bool get hasActiveTransect => activeTransectId != null && transectEnd == null;
  StreamSubscription<Position>? _previewGpsSub;
  String? selectedSpeciesId;

  // FAST DISPLAY POSITION
  double arrowLat = 0;
  double arrowLng = 0;

  bool compassEnabled = true;
  bool get isGnssActive {
    return DateTime.now().difference(_lastGnssTime).inSeconds <= 2;
  }

  void setCompassEnabled(bool value) {
    compassEnabled = value;
  }

  List<String> get missingRecordContextFields {
    final missing = <String>[];

    if (activeTransectId == null || activeTransectId!.isEmpty) {
      missing.add('transectId');
    }
    if ((bmsLocation ?? '').trim().isEmpty) {
      missing.add('bmsLocation');
    }
    if ((assessmentPeriod ?? '').trim().isEmpty) {
      missing.add('assessmentPeriod');
    }
    if (assessmentYear == null) {
      missing.add('assessmentYear');
    }
    if (transectStart == null) {
      missing.add('transectStart');
    }

    return missing;
  }

  Future<void> _persistActiveTransectState() async {
    if (!Hive.isBoxOpen('transects')) {
      await Hive.openBox('transects');
    }

    final box = Hive.box('transects');

    if (activeTransectId == null) {
      await box.delete(_activeTransectStateKey);
      return;
    }

    await box.put(_activeTransectStateKey, {
      'transectId': activeTransectId,
      'transectStart': transectStart?.toIso8601String(),
      'transectEnd': transectEnd?.toIso8601String(),
      'weather': weather,
      'bmsLocation': bmsLocation,
      'assessmentPeriod': assessmentPeriod,
      'assessmentYear': assessmentYear,
      'ecosystemType': ecosystemType,
      'observers': observers,
      'speciesGroup': speciesGroup,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
      'startElevation': startElevation,
      'endElevation': endElevation,
      'currentLat': currentLat,
      'currentLng': currentLng,
      'currentElevation': currentElevation,
      'distanceMeters': distanceMeters,
      'minElevation': minElevation,
      'maxElevation': maxElevation,
      'selectedTransectId': selectedTransectId,
    });
  }

  String _pointIdForKey(String transectId, int hiveKey) =>
      '${transectId}_point_$hiveKey';

  Future<void> _clearPersistedActiveTransectState() async {
    if (!Hive.isBoxOpen('transects')) {
      await Hive.openBox('transects');
    }
    await Hive.box('transects').delete(_activeTransectStateKey);
  }

  // =========================================================
  // 👀 PREVIEW GPS (BEFORE TRANSECT STARTS)
  // =========================================================
  void setAccuracyMode(AccuracyMode mode) {
    accuracyMode = mode;
  }

  Future<void> startPreviewLocation() async {
    await _ensureLocationPermission();

    if (hasActiveTransect) return;

    _previewGpsSub?.cancel();

    _previewGpsSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 2,
          ),
        ).listen((pos) {
          currentLat = pos.latitude;
          currentLng = pos.longitude;
          currentElevation = pos.altitude;

          if (!pos.heading.isNaN) {
            gpsBearing = pos.heading;
          }
          hudTick.value++;
        });
  }

  void stopPreviewLocation() {
    _previewGpsSub?.cancel();
    _previewGpsSub = null;
  }

  int satCount = 0;
  double avgSnr = 0;

  void startGnssFeed() {
    if (_gnssSub != null) return;
    _gnssSub?.cancel();

    _gnssSub = _gnssChannel.receiveBroadcastStream().listen((data) {
      if (!hasActiveTransect) return;
      _lastGnssTime = DateTime.now();
      final lat = data['lat'] as double;
      final lng = data['lng'] as double;
      final acc = data['accuracy'] as double;
      final bearing = (data['bearing'] as num?)?.toDouble() ?? 0.0;

      // FAST VISUAL (NO FILTER)
      // 🔥 SMOOTH VISUAL ARROW (NO EFFECT ON SAVED TRACK)
      arrowLat = arrowLat == 0 ? lat : (arrowLat * 0.7 + lat * 0.3);

      arrowLng = arrowLng == 0 ? lng : (arrowLng * 0.7 + lng * 0.3);

      gpsBearing = bearing;

      // GNSS-based canopy detection
      if (acc > 22) {
        accuracyMode = AccuracyMode.forest;
      } else if (acc < 14) {
        accuracyMode = AccuracyMode.openTrail;
      }
    });
  }

  void resumeTransect(String transectId) {
    activeTransectId = transectId;
    transectEnd = null;

    Hive.box('transects').put('active_transect_id', transectId);
    Hive.box('transects').put('selected_transect_id', transectId);

    // 🔥 STOP preview if running
    _previewGpsSub?.cancel();
    _previewGpsSub = null;

    // 🔥 RESUME SENSORS
    startGnssFeed();
    _startCompass();
    _startGpsTracking();
    _persistActiveTransectState();
  }

  Future<void> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Location services disabled';
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw 'Location permission denied';
    }
  }

  // =========================================================
  // 🔥 START TRANSECT
  // =========================================================
  Future startTransect({
    required String weather,
    required String bmsLocation,
    required String assessmentPeriod,
    required int assessmentYear,
  }) async {
    if (hasActiveTransect) {
      throw 'A transect is already running';
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'GPS is OFF';
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      throw 'Location permission permanently denied';
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );

    activeTransectId = const Uuid().v4();
    transectStart = DateTime.now();
    transectEnd = null;

    this.weather = weather;
    this.bmsLocation = bmsLocation;
    this.assessmentPeriod = assessmentPeriod;
    this.assessmentYear = assessmentYear;

    startLat = pos.latitude;
    startLng = pos.longitude;
    startElevation = pos.altitude;

    arrowLat = startLat;
    arrowLng = startLng;
    currentLat = startLat;
    currentLng = startLng;
    currentElevation = startElevation;

    minElevation = startElevation;
    maxElevation = startElevation;
    distanceMeters = 0;

    _lastPosition = null;
    _lastAcceptedTime = null;
    _lastKalmanTime = null;
    _lastSmoothLat = null;
    _lastSmoothLng = null;
    // 🔄 RESET accuracy auto-detection

    _kalman.reset(startLat, startLng);

    _accuracyAvg = 0;
    _accuracySamples = 0;
    accuracyMode = AccuracyMode.forest;

    await Hive.openBox('transect_points');
    await Hive.box('transects').put('active_transect_id', activeTransectId);

    final pointMap = {
      'transectId': activeTransectId!,
      'lat': startLat,
      'lng': startLng,
      'alt': startElevation,
      'time': DateTime.now().toIso8601String(),
      'accuracy': pos.accuracy,
      'synced': false,
    };

    final box = Hive.box('transect_points');
    final key = await box.add(pointMap);
    pointMap['pointId'] = _pointIdForKey(activeTransectId!, key);
    await box.put(key, pointMap);
    _uploadPointToFirestore(activeTransectId!, pointMap, key);
    mapTick.value++;
    // 🛑 STOP PREVIEW MODE
    await _previewGpsSub?.cancel();
    _previewGpsSub = null;
    startGnssFeed();
    _startCompass();
    _startGpsTracking();
    selectedTransectId = activeTransectId;
    Hive.box('transects').put('selected_transect_id', activeTransectId);
    await _persistActiveTransectState();
  }

  // =========================================================
  // 🗂️ TRANSECT SELECTION (UI STATE)
  // =========================================================
  void selectTransect(String transectId) {
    selectedTransectId = transectId;
    Hive.box('transects').put('selected_transect_id', transectId);
  }

  void clearSelectedTransect() {
    selectedTransectId = null;
    Hive.box('transects').delete('selected_transect_id');
  }

  // =========================================================
  // 🧭 COMPASS
  // =========================================================
  void _startCompass() {
    _compassSub?.cancel();
    _compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading == null) return;
      compassHeading = event.heading!.clamp(0, 360);
    });
  }
  // safe default

  // =========================================================
  // 📍 GPS — ALPINEQUEST STYLE
  // =========================================================
  Future<void> _startGpsTracking() async {
    await _ensureLocationPermission();

    _gpsSub?.cancel();

    _gpsSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 1,
          ),
        ).listen((pos) async {
          if (!hasActiveTransect) return;
          if (activeTransectId == null) return;
          if (transectEnd != null) return;

          final transectId = activeTransectId!;

          // 🔥 FAST VISUAL UPDATE (NO FILTER)
          final now = DateTime.now();
          final lat = pos.latitude;
          final lng = pos.longitude;
          final alt = pos.altitude;
          // ================= ACCURACY AUTO MODE =================
          if (_gnssSub == null) {
            _accuracySamples++;
            _accuracyAvg =
                ((_accuracyAvg * (_accuracySamples - 1)) + pos.accuracy) /
                _accuracySamples;

            if (_accuracySamples > 6) {
              if (_accuracyAvg > 22) {
                accuracyMode = AccuracyMode.forest;
              } else if (_accuracyAvg < 14) {
                accuracyMode = AccuracyMode.openTrail;
              }
            }
          }

          final maxAccuracy = accuracyMode == AccuracyMode.openTrail
              ? 20.0
              : 45.0;
          if (pos.accuracy > maxAccuracy) return;
          final speed = pos.speed.isNaN ? 0.0 : pos.speed;

          // allow slow walking
          if (speed < 0.3 && _lastAcceptedTime != null) {
            final waited = now.difference(_lastAcceptedTime!).inSeconds >= 4;
            if (!waited) return;
          }
          // ================= FIRST POINT =================
          if (_lastPosition == null) {
            _lastPosition = pos;
            _lastAcceptedTime = now;
            _lastKalmanTime = now;
            _lastRawLat = lat;
            _lastRawLng = lng;
            currentLat = lat;
            currentLng = lng;
            currentElevation = alt;

            _lastSmoothLat = lat;
            _lastSmoothLng = lng;

            gpsBearing = pos.heading.isNaN ? 0 : pos.heading;
            _lastBearing = gpsBearing;

            _kalman.reset(lat, lng);

            final box = Hive.box('transect_points');
            final pointMap = {
              'transectId': transectId,
              'lat': lat,
              'lng': lng,
              'alt': alt,
              'time': now.toIso8601String(),
              'accuracy': pos.accuracy,
              'synced': false,
            };
            final key = await box.add(pointMap);
            pointMap['pointId'] = _pointIdForKey(transectId, key);
            await box.put(key, pointMap);

            _uploadPointToFirestore(
              transectId,
              Map<String, dynamic>.from(pointMap),
              key,
            );

            // 🔥 MAO NI ANG IMPORTANTE
            hudTick.value++;

            return;
          }
          if (_lastRawLat == null || _lastRawLng == null) {
            _lastRawLat = lat;
            _lastRawLng = lng;
          }
          final rawDist = Geolocator.distanceBetween(
            _lastRawLat!,
            _lastRawLng!,
            lat,
            lng,
          );

          final minStep = accuracyMode == AccuracyMode.openTrail ? 3.0 : 1.2;
          final maxJump = accuracyMode == AccuracyMode.openTrail ? 20.0 : 35.0;

          final movedEnough = rawDist >= minStep;
          final waitedLongEnough =
              _lastAcceptedTime != null &&
              now.difference(_lastAcceptedTime!).inSeconds >= 5;

          if (rawDist > maxJump) return;
          if (!movedEnough && !waitedLongEnough) return;

          // ================= BEARING (ANTI SHAKE) =================
          final moveBearing = pos.speed > 1.0
              ? Geolocator.bearingBetween(_lastRawLat!, _lastRawLng!, lat, lng)
              : _lastBearing;

          _lastBearing = moveBearing;
          gpsBearing = moveBearing;

          // ================= KALMAN =================
          final dt = now.difference(_lastKalmanTime!).inMilliseconds / 1000.0;

          _kalman.predict(dt.clamp(0.15, 0.6));
          _kalman.update(lat, lng, pos.accuracy);

          final alpha = pos.speed > 1.2 ? 0.7 : 0.85;

          final smoothLat = (_kalman.x[0] * alpha) + (lat * (1 - alpha));
          final smoothLng = (_kalman.x[1] * alpha) + (lng * (1 - alpha));
          final smoothAlt = ((_lastPosition?.altitude ?? alt) + alt) / 2;

          final stepDist = Geolocator.distanceBetween(
            _lastSmoothLat!,
            _lastSmoothLng!,
            smoothLat,
            smoothLng,
          );

          // 🚫 ignore jitter / backtrack wiggle
          if (stepDist < 2.0) return;

          // ✅ ONLY ONCE
          distanceMeters += stepDist;

          _lastSmoothLat = smoothLat;
          _lastSmoothLng = smoothLng;

          committedLat = smoothLat;
          committedLng = smoothLng;

          currentLat = smoothLat;
          currentLng = smoothLng;
          currentElevation = smoothAlt;
          final nowTs = DateTime.now();
          if (nowTs.difference(_lastGnssTime).inSeconds > 2) {
            arrowLat = currentLat;
            arrowLng = currentLng;
          }

          // 🧭 ARROW FALLBACK — kung walay GNSS update

          final pointMap = {
            'transectId': transectId,
            'lat': smoothLat,
            'lng': smoothLng,
            'alt': smoothAlt,
            'time': now.toIso8601String(),
            'accuracy': pos.accuracy,
            'synced': false,
          };

          final box = Hive.box('transect_points');
          final key = await box.add(pointMap);
          pointMap['pointId'] = _pointIdForKey(transectId, key);
          await box.put(key, pointMap);

          // 🔥 IMPORTANT
          _uploadPointToFirestore(transectId, pointMap, key);
          hudTick.value++; // 🔥 notify distance / HUD
          mapTick.value++;
          _lastPosition = pos;
          _lastAcceptedTime = now;
          _lastKalmanTime = now;
          _lastRawLat = lat;
          _lastRawLng = lng;
        });
  }

  // =========================================================
  // 🔴 END TRANSECT
  // =========================================================
  Future endTransect() async {
    if (!hasActiveTransect) return;

    final transectId = activeTransectId!;
    transectEnd = DateTime.now();

    endLat = currentLat;
    endLng = currentLng;
    endElevation = currentElevation;

    // STOP SENSORS
    await _gnssSub?.cancel();
    await _gpsSub?.cancel();
    await _compassSub?.cancel();

    final data = {
      'transectId': transectId,
      'bmsLocation': bmsLocation,
      'assessmentPeriod': assessmentPeriod,
      'assessmentYear': assessmentYear,
      'startTime': transectStart,
      'endTime': transectEnd,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
      'distance': distanceMeters,
      'weather': weather,
      'alt': currentElevation,
      'status': 'ended',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // ================= TRY FIRESTORE (OPTIONAL) =================
    try {
      await FirebaseFirestore.instance
          .collection('transects')
          .doc(transectId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      // 🔥 OFFLINE OK — DO NOTHING
    }

    // ================= ALWAYS SAVE LOCALLY =================
    await Hive.box('transects').put(transectId, {
      ...data,
      'startTime': transectStart?.toIso8601String(),
      'endTime': transectEnd?.toIso8601String(),
      'offline': true,
    });

    final pointMap = {
      'transectId': transectId,
      'lat': currentLat,
      'lng': currentLng,
      'alt': currentElevation,
      'time': DateTime.now().toIso8601String(),
      'accuracy': 0,
      'synced': false,
    };

    final box = Hive.box('transect_points');
    final key = await box.add(pointMap);
    pointMap['pointId'] = _pointIdForKey(transectId, key);
    await box.put(key, pointMap);
    _uploadPointToFirestore(transectId, pointMap, key);
    await _persistActiveTransectState();

    // ❗ IMPORTANT: DO NOT RESET HERE
    // ❗ Summary page pa ang mo finalize
  }

  Future<void> retryUnsyncedPoints() async {
    if (!Hive.isBoxOpen('transect_points')) {
      await Hive.openBox('transect_points');
    }

    final box = Hive.box('transect_points');

    final unsynced = box.keys.where((k) {
      final v = box.get(k);
      return v is Map && v['synced'] == false;
    }).toList();

    debugPrint('🔁 Retrying ${unsynced.length} unsynced points');

    for (final key in unsynced) {
      final p = box.get(key);
      if (p is! Map) continue;

      await _uploadPointToFirestore(
        p['transectId'],
        Map<String, dynamic>.from(p),
        key,
      );
    }
  }

  Future<void> _uploadPointToFirestore(
    String transectId,
    Map<String, dynamic> point,
    int hiveKey,
  ) async {
    try {
      final pointId =
          (point['pointId'] as String?) ?? _pointIdForKey(transectId, hiveKey);
      point['pointId'] = pointId;
      await FirebaseFirestore.instance
          .collection('transects')
          .doc(transectId)
          .collection('points')
          .doc(pointId)
          .set({
            'pointId': pointId,
            'lat': point['lat'],
            'lng': point['lng'],
            'alt': point['alt'],
            'time': point['time'],
            'accuracy': point['accuracy'],
            'createdAt': FieldValue.serverTimestamp(),
          });

      // ✅ mark as synced
      point['synced'] = true;
      await Hive.box('transect_points').put(hiveKey, point);
    } catch (e) {
      // 🔕 offline OK — retry later
    }
  }

  Future<void> restoreActiveTransect({bool startSensors = true}) async {
    // 🔍 Check kung naay active transect saved
    if (!Hive.isBoxOpen('transects')) {
      await Hive.openBox('transects');
    }

    final transectBox = Hive.box('transects');
    final savedId = transectBox.get('active_transect_id');
    final savedStateRaw = transectBox.get(_activeTransectStateKey);
    final savedState = savedStateRaw is Map
        ? Map<String, dynamic>.from(savedStateRaw.cast<dynamic, dynamic>())
        : <String, dynamic>{};
    final restoredId = (savedState['transectId'] ?? savedId)?.toString();

    if (restoredId == null || restoredId.isEmpty) return;

    activeTransectId = restoredId;
    selectedTransectId =
        (savedState['selectedTransectId'] ?? restoredId)?.toString();
    transectStart = DateTime.tryParse(
      (savedState['transectStart'] ?? '').toString(),
    );
    transectEnd = DateTime.tryParse(
      (savedState['transectEnd'] ?? '').toString(),
    );
    weather = savedState['weather']?.toString();
    bmsLocation = savedState['bmsLocation']?.toString();
    assessmentPeriod = savedState['assessmentPeriod']?.toString();
    final restoredYear = savedState['assessmentYear'];
    if (restoredYear is int) {
      assessmentYear = restoredYear;
    } else if (restoredYear is String) {
      assessmentYear = int.tryParse(restoredYear);
    }
    ecosystemType = savedState['ecosystemType']?.toString();
    observers = (savedState['observers'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    speciesGroup = (savedState['speciesGroup'] ?? speciesGroup).toString();

    // 🔥 Ensure points box
    if (!Hive.isBoxOpen('transect_points')) {
      await Hive.openBox('transect_points');
    }

    final points = Hive.box(
      'transect_points',
    ).values.whereType<Map>().where((e) => e['transectId'] == restoredId).toList()
      ..sort((a, b) {
        final ta = (a['time'] ?? '').toString();
        final tb = (b['time'] ?? '').toString();
        return ta.compareTo(tb);
      });

    if (points.isNotEmpty) {
      final first = points.first;
      final last = points.last;

      startLat = (first['lat'] as num).toDouble();
      startLng = (first['lng'] as num).toDouble();
      startElevation = (first['alt'] as num?)?.toDouble() ?? 0;

      currentLat = (last['lat'] as num).toDouble();
      currentLng = (last['lng'] as num).toDouble();
      currentElevation = (last['alt'] as num?)?.toDouble() ?? 0;

      if (transectEnd != null) {
        endLat = currentLat;
        endLng = currentLng;
        endElevation = currentElevation;
      }

      minElevation = startElevation;
      maxElevation = startElevation;
      distanceMeters = 0;

      for (int i = 0; i < points.length; i++) {
        final point = points[i];
        final alt = (point['alt'] as num?)?.toDouble() ?? 0;
        if (i > 0) {
          final prev = points[i - 1];
          distanceMeters += Geolocator.distanceBetween(
            (prev['lat'] as num).toDouble(),
            (prev['lng'] as num).toDouble(),
            (point['lat'] as num).toDouble(),
            (point['lng'] as num).toDouble(),
          );
        }
        if (alt < minElevation) minElevation = alt;
        if (alt > maxElevation) maxElevation = alt;
      }
    } else {
      startLat = (savedState['startLat'] as num?)?.toDouble() ?? 0;
      startLng = (savedState['startLng'] as num?)?.toDouble() ?? 0;
      endLat = (savedState['endLat'] as num?)?.toDouble() ?? 0;
      endLng = (savedState['endLng'] as num?)?.toDouble() ?? 0;
      startElevation =
          (savedState['startElevation'] as num?)?.toDouble() ?? 0;
      endElevation = (savedState['endElevation'] as num?)?.toDouble() ?? 0;
      currentLat = (savedState['currentLat'] as num?)?.toDouble() ?? startLat;
      currentLng = (savedState['currentLng'] as num?)?.toDouble() ?? startLng;
      currentElevation =
          (savedState['currentElevation'] as num?)?.toDouble() ??
          startElevation;
      distanceMeters =
          (savedState['distanceMeters'] as num?)?.toDouble() ?? 0;
      minElevation =
          (savedState['minElevation'] as num?)?.toDouble() ?? currentElevation;
      maxElevation =
          (savedState['maxElevation'] as num?)?.toDouble() ?? currentElevation;
    }

    if (minElevation == 99999) {
      minElevation = currentElevation;
    }

    _lastRawLat = currentLat;
    _lastRawLng = currentLng;
    _lastSmoothLat = currentLat;
    _lastSmoothLng = currentLng;
    committedLat = currentLat;
    committedLng = currentLng;
    arrowLat = currentLat;
    arrowLng = currentLng;
    accuracyMode = AccuracyMode.forest;
    _accuracyAvg = 0;
    _accuracySamples = 0;

    _lastPosition = Position(
      latitude: currentLat,
      longitude: currentLng,
      altitude: currentElevation,
      accuracy: 5,
      speed: 0,
      heading: 0,
      timestamp: DateTime.now(),
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );

    _kalman.reset(currentLat, currentLng);

    await _persistActiveTransectState();

    if (startSensors && transectEnd == null) {
      try {
        startGnssFeed();
        _startCompass();
        await _startGpsTracking();
      } catch (e) {
        debugPrint('Transect restore sensor startup skipped: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> pendingChildSyncLogs({
    String? transectId,
  }) async {
    if (!Hive.isBoxOpen('offline_logs')) {
      await Hive.openBox('offline_logs');
    }

    final activeId = transectId ?? activeTransectId;
    if (activeId == null) return [];

    return Hive.box('offline_logs').values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((log) {
          final status = log['status'];
          if (status != 'pending' && status != 'error') return false;
          final data = log['data'];
          return data is Map && data['transectId'] == activeId;
        })
        .toList();
  }

  /// 🗺️ LOAD ALL LOCAL TRANSECTS FOR MAP (READ-ONLY, PER DEVICE)
  Future<void> restoreAllLocalTransectsForMap() async {
    if (!Hive.isBoxOpen('transect_points')) {
      await Hive.openBox('transect_points');
    }

    if (!Hive.isBoxOpen('transects')) {
      await Hive.openBox('transects');
    }

    final tpBox = Hive.box('transect_points');

    if (tpBox.isEmpty) {
      debugPrint('⚠️ No local transect points to restore');
      return;
    }

    debugPrint('🗺️ Restored ${tpBox.length} local transect points');

    // optional UX: auto-select last transect
    final last = tpBox.values.whereType<Map>().last;
    final lastId = last['transectId'];

    if (lastId != null) {
      Hive.box('transects').put('selected_transect_id', lastId);
    }
  }

  // =========================================================
  // ✅ FINAL SUMMARY (SAVE + RESET)
  // =========================================================
  Future saveSummary({
    required String notes,
    required DateTime conductedDate,
  }) async {
    await _compassSub?.cancel();
    _compassSub = null;

    if (activeTransectId == null) return;

    final transectId = activeTransectId!;

    bool savedOnline = false;

    final firestoreData = {
      'notes': notes,
      'conductedDate': conductedDate.toIso8601String(),
      'status': 'finalized',

      // ANNEX 1-C.1 REQUIRED
      'bmsLocation': bmsLocation,
      'weather': weather,
      'ecosystemType': ecosystemType,
      'observers': observers,
      'speciesGroup': speciesGroup,
      'distance': distanceMeters,
      'minElevation': minElevation,
      'maxElevation': maxElevation,

      'updatedAt': DateTime.now().toIso8601String(),
    };

    // ================= TRY ONLINE SAVE =================
    try {
      await FirebaseFirestore.instance
          .collection('transects')
          .doc(transectId)
          .update(firestoreData);

      savedOnline = true;
    } catch (e) {
      // 🔥 WALAY INTERNET / FAILED — OK RA
      savedOnline = false;
    }

    // ================= ALWAYS SAVE TO HIVE =================
    await Hive.box('transects').put(transectId, {
      'transectId': transectId,
      'bmsLocation': bmsLocation,
      'weather': weather,
      'ecosystemType': ecosystemType,
      'observers': observers,
      'speciesGroup': speciesGroup,

      // TIME
      'startTime': transectStart?.toIso8601String(),
      'endTime': transectEnd?.toIso8601String(),

      // GPS
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,

      // METRICS
      'distance': distanceMeters,
      'minElevation': minElevation,
      'maxElevation': maxElevation,

      // STATUS
      'status': savedOnline ? 'finalized' : 'offline_finalized',
    });

    // ================= RESET ACTIVE STATE =================
    activeTransectId = null;
    transectStart = null;
    transectEnd = null;

    weather = null;
    bmsLocation = null;
    assessmentPeriod = null;
    assessmentYear = null;

    distanceMeters = 0;
    minElevation = 99999;
    maxElevation = 0;

    startLat = startLng = endLat = endLng = 0;
    startElevation = endElevation = 0;
    currentLat = currentLng = currentElevation = 0;

    _lastPosition = null;
    _lastAcceptedTime = null;
    _lastKalmanTime = null;

    await Hive.box('transects').delete('active_transect_id');
    await _clearPersistedActiveTransectState();
  }

  Future<void> autoCleanupOldLocalTransects({
    int maxAgeDays = 14, // 👈 pwede nimo usbon
  }) async {
    if (!Hive.isBoxOpen('transects')) {
      await Hive.openBox('transects');
    }
    if (!Hive.isBoxOpen('transect_points')) {
      await Hive.openBox('transect_points');
    }

    final transectBox = Hive.box('transects');
    final pointsBox = Hive.box('transect_points');

    final now = DateTime.now();

    for (final key in transectBox.keys) {
      final t = transectBox.get(key);

      if (t is! Map) continue;

      // ❌ Skip active transect
      if (key == transectBox.get('active_transect_id')) continue;

      final status = t['status'];
      if (status != 'finalized' && status != 'offline_finalized') continue;

      final endTimeStr = t['endTime'];
      if (endTimeStr == null) continue;

      final endTime = DateTime.tryParse(endTimeStr);
      if (endTime == null) continue;

      final ageDays = now.difference(endTime).inDays;
      if (ageDays < maxAgeDays) continue;

      debugPrint('🧹 Cleaning old transect: $key ($ageDays days old)');

      // 🗑 DELETE TRANSECT POINTS
      final keysToDelete = pointsBox.keys.where((k) {
        final p = pointsBox.get(k);
        return p is Map && p['transectId'] == key;
      }).toList();

      await pointsBox.deleteAll(keysToDelete);

      // 🗑 DELETE TRANSECT RECORD
      await transectBox.delete(key);
    }

    await pointsBox.flush();
    await transectBox.flush();

    debugPrint('✅ Auto cleanup finished');
  }

  Future<void> importTransectFromFirestore(String transectId) async {
    final snap = await FirebaseFirestore.instance
        .collection('transects')
        .doc(transectId)
        .collection('points')
        .orderBy('time')
        .get();

    if (snap.docs.isEmpty) return;

    await Hive.openBox('transect_points');
    final box = Hive.box('transect_points');

    // avoid duplicates
    final exists = box.values.whereType<Map>().any(
      (e) => e['transectId'] == transectId,
    );

    if (exists) return;

    for (final d in snap.docs) {
      final p = d.data();

      box.add({
        'transectId': transectId,
        'lat': (p['lat'] as num).toDouble(),
        'lng': (p['lng'] as num).toDouble(),
        'alt': (p['alt'] as num?)?.toDouble() ?? 0,
        'time': p['time'],
      });
    }

    // restore last known position (for arrow/map center)
    startLat = box.values.whereType<Map>().firstWhere(
      (e) => e['transectId'] == transectId,
    )['lat'];

    startLng = box.values.whereType<Map>().firstWhere(
      (e) => e['transectId'] == transectId,
    )['lng'];

    final last = box.values.whereType<Map>().lastWhere(
      (e) => e['transectId'] == transectId,
    );

    currentLat = last['lat'];
    currentLng = last['lng'];

    _lastSmoothLat = currentLat;
    _lastSmoothLng = currentLng;
  }

  // =========================================================
  // 🗑️ DELETE TRANSECT FULLY (FIRESTORE + LOCAL MAP DATA)
  // =========================================================
  Future<void> deleteTransectFully(
    String transectId, {
    bool deleteRemote = true,
  }) async {
    // 🛑 STOP SENSORS
    await _gpsSub?.cancel();
    await _compassSub?.cancel();
    await _gnssSub?.cancel();

    _gnssSub = null;
    _gpsSub = null;
    _compassSub = null;

    // 🔥 DELETE FROM FIRESTORE
    if (deleteRemote) {
      await FirebaseFirestore.instance
          .collection('transects')
          .doc(transectId)
          .delete();
    }

    // 🔥 ENSURE BOXES
    if (!Hive.isBoxOpen('transect_points')) {
      await Hive.openBox('transect_points');
    }
    if (!Hive.isBoxOpen('species_points')) {
      await Hive.openBox('species_points');
    }

    // 🔥 DELETE ONLY POINTS BELONGING TO THIS TRANSECT
    final tpBox = Hive.box('transect_points');
    final tpKeys = tpBox.keys.where((k) {
      final v = tpBox.get(k);
      return v is Map && v['transectId'] == transectId;
    }).toList();

    await tpBox.deleteAll(tpKeys);
    await tpBox.flush();

    final spBox = Hive.box('species_points');
    final spKeys = spBox.keys.where((k) {
      final v = spBox.get(k);
      return v is Map && v['transectId'] == transectId;
    }).toList();

    await spBox.deleteAll(spKeys);
    await spBox.flush();

    // 🔥 CLEAR ACTIVE FLAG IF SAME
    final visibleId = Hive.box('transects').get('visible_transect_id');

    if (visibleId == transectId) {
      await Hive.box('transects').delete('visible_transect_id');
    }

    // 🔄 RESET STATE
    if (activeTransectId == transectId) {
      activeTransectId = null;
      transectStart = null;
      transectEnd = null;

      distanceMeters = 0;
      minElevation = 99999;
      maxElevation = 0;

      startLat = startLng = endLat = endLng = 0;
      startElevation = endElevation = 0;
      currentLat = currentLng = currentElevation = 0;

      _lastPosition = null;
      _lastAcceptedTime = null;
      _lastKalmanTime = null;
    }

    final transectBox = Hive.box('transects');
    if (transectBox.get('active_transect_id') == transectId) {
      await transectBox.delete('active_transect_id');
    }
    if (transectBox.get('selected_transect_id') == transectId) {
      await transectBox.delete('selected_transect_id');
    }
    await _clearPersistedActiveTransectState();
  }

  void selectSpecies(String speciesId) {
    selectedSpeciesId = speciesId;
    Hive.box('species').put('selected_species_id', speciesId);
  }

  void clearSelectedSpecies() {
    selectedSpeciesId = null;
    Hive.box('species').delete('selected_species_id');
  }

  // =========================================================
  // 🧠 HEADING FOR MAP
  // =========================================================
  double get effectiveHeading {
    final target = compassEnabled ? compassHeading : gpsBearing;

    // smooth blend (anti-lukso)
    _stableHeading = (_stableHeading * 0.85) + (target * 0.15);

    return _stableHeading;
  }
}
