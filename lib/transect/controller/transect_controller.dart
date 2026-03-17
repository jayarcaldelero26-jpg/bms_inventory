import 'dart:async';
import '../state/transect_state.dart';
import '../services/gps_service.dart';
import '../services/compass_service.dart';
import '../services/gnss_service.dart';
import '../services/kalman_tracker.dart';
import '../enums/accuracy_mode.dart';
import 'package:geolocator/geolocator.dart';

class TransectController {
  final TransectState state = TransectState();

  final GpsService gps;
  final CompassService compass;
  final GnssService gnss;
  final KalmanTracker kalman;

  StreamSubscription? _gpsSub;
  StreamSubscription? _compassSub;
  StreamSubscription? _gnssSub;

  TransectController({
    required this.gps,
    required this.compass,
    required this.gnss,
    required this.kalman,
  });

  void startSensors() {
    _gpsSub = gps.stream().listen(_onGps);
    _compassSub = compass.stream().listen((h) {
      state.compassHeading = h;
    });
    _gnssSub = gnss.stream().listen(_onGnss);
  }

  void stopSensors() {
    _gpsSub?.cancel();
    _compassSub?.cancel();
    _gnssSub?.cancel();
  }

  void _onGps(Position pos) {
    // 👉 diri nato ibalhin sunod ang GPS logic
  }

  void _onGnss(Map<String, dynamic> d) {
    final acc = d['accuracy'] as double;

    if (acc > 22) {
      state.accuracyMode = AccuracyMode.forest;
    } else if (acc < 14) {
      state.accuracyMode = AccuracyMode.openTrail;
    }
  }
}
