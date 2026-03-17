import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import '../threat_hazard_layer.dart';
import '../map_legend.dart';
import '../threat_details_card.dart';
import '../species_details_card.dart';

import '../legacy/transect_service.dart';
import '../../services/firestore_service.dart';

class TransectMapPage extends StatefulWidget {
  const TransectMapPage({super.key});

  @override
  State<TransectMapPage> createState() => _TransectMapPageState();
}

class _TransectMapPageState extends State<TransectMapPage> {
  final TransectService t = TransectService();

  final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _showTransectDetails = false;
  bool _showSpeciesDetails = false;
  bool _showLegend = false;

  LatLng _center = const LatLng(7.0, 125.0);

  bool _compassEnabled = true;

  // =========================================================

  @override
  void initState() {
    super.initState();
    _bootMap();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tpBox = Hive.box('transect_points');
      if (tpBox.isNotEmpty) {
        final last = tpBox.values.whereType<Map>().last;
        final tid = last['transectId'];
        if (tid != null) {
          Hive.box('transects').put('selected_transect_id', tid);
          debugPrint('🧭 Auto-selected transect: $tid');
        }
      }
    });
  }

  Future<void> _bootMap() async {
    // ENSURE ALL REQUIRED BOXES
    await Hive.openBox('species');
    await Hive.openBox('species_points');
    await Hive.openBox('threats');
    await Hive.openBox('ui_state');

    if (!Hive.isBoxOpen('transect_points')) {
      await Hive.openBox('transect_points');
    }
    if (!Hive.isBoxOpen('transects')) {
      await Hive.openBox('transects');
    }

    await _cleanOrphanSpeciesPoints();
    // RESTORE TRANSECT STATE
    await t.restoreActiveTransect();

    if (!t.hasActiveTransect) {
      await t.startPreviewLocation();
    }

    await _initLocation();

    setState(() {
      _mapReady = true;
    });
  }

  void _safeMove(LatLng center, double zoom) {
    if (!_mapReady) return;
    _mapController.move(center, zoom);
  }

  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    if (!mounted) return;

    _center = LatLng(pos.latitude, pos.longitude);

    _safeMove(_center, 17);

    setState(() {});
  }

  @override
  void dispose() {
    if (!t.hasActiveTransect) {
      t.stopPreviewLocation();
    }
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Do you want to exit the application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    return shouldExit ?? false;
  }

  Widget _buildHud() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _hudText('Lat', t.currentLat.toStringAsFixed(5)),
              _hudText('Lng', t.currentLng.toStringAsFixed(5)),
              _hudText(
                'Dist',
                t.hasActiveTransect
                    ? '${(t.distanceMeters / 1000).toStringAsFixed(2)} km'
                    : '-',
              ),
              _hudText('Elev', '${t.currentElevation.toStringAsFixed(0)} m'),
              _hudText('Arrow', t.isGnssActive ? 'GNSS' : 'GPS'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hudText(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _validThreats(Box box) {
    return box.values
        .whereType<Map>()
        .where(
          (e) =>
              e['id'] != null &&
              e['latitude'] != null &&
              e['longitude'] != null,
        )
        .map((e) => Map<String, dynamic>.from(e)) // ✅ SAFE CONVERSION
        .toList();
  }

  // =========================================================
  // 🔴 GET THREAT SEVERITIES ON MAP (FOR LEGEND)
  // =========================================================
  Set<String> _getThreatSeveritiesOnMap() {
    final box = Hive.box('threats');
    final Set<String> severities = {};

    for (final v in box.values.whereType<Map>()) {
      final s = v['threatSeverity'];
      if (s != null && s.toString().trim().isNotEmpty) {
        severities.add(s.toString());
      }
    }

    return severities;
  }

  Future<void> _cleanOrphanSpeciesPoints() async {
    final speciesBox = Hive.box('species');
    final pointsBox = Hive.box('species_points');

    final speciesIds = speciesBox.keys
        .where((k) => k is String && k != 'selected_species_id')
        .cast<String>()
        .toSet();

    final toDelete = <dynamic>[];

    for (final k in pointsBox.keys) {
      final v = pointsBox.get(k);
      if (v is! Map) continue;

      final sid = v['speciesId'] ?? v['id'];
      if (sid == null) continue;

      if (!speciesIds.contains(sid)) {
        toDelete.add(k);
      }
    }

    for (final k in toDelete) {
      await pointsBox.delete(k);
    }

    if (toDelete.isNotEmpty) {
      debugPrint('🧹 Cleaned ${toDelete.length} orphan species_points');
    }
  }

  // =========================================================
  // 🧱 BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    if (!_mapReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hasThreats = Hive.box('threats').values.whereType<Map>().isNotEmpty;
    final hasSpecies = Hive.box(
      'species_points',
    ).values.whereType<Map>().isNotEmpty;
    final hasTransects = Hive.box(
      'transect_points',
    ).values.whereType<Map>().isNotEmpty;

    final hasAnyData = hasThreats || hasSpecies || hasTransects;

    final threatSeveritiesOnMap = _getThreatSeveritiesOnMap();

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFEFF6EC),

        // ================= HEADER =================
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 38, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade900, Colors.green.shade700],
              ),
            ),
            child: Row(
              children: [
                Image.asset('assets/denr_logo.png', height: 55),
                const SizedBox(width: 22),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Biodiversity Monitoring System',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Mount Hamiguitan Range Wildlife Sanctuary',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ================= BODY =================
        body: Stack(
          children: [
            // ================= MAP =================
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 17,
                onTap: (_, __) {
                  t.clearSelectedSpecies();
                  t.clearSelectedTransect();

                  setState(() {
                    _showTransectDetails = false;
                    _showSpeciesDetails = false;
                  });
                },
              ),

              children: [
                TileLayer(
                  tileProvider: FMTCStore('bms_offline_map').getTileProvider(),
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.bms_inventory',
                ),
                // ================= THREAT HAZARD (CIRCLE) =================
                ValueListenableBuilder(
                  valueListenable: Hive.box('threats').listenable(),
                  builder: (_, Box box, __) {
                    final threats = _validThreats(box);
                    if (threats.isEmpty) return const SizedBox();
                    return ThreatHazardLayer.circleLayer(threats);
                  },
                ),

                // 🔴 THREAT – DOT (visual)
                ValueListenableBuilder(
                  valueListenable: Hive.box('threats').listenable(),
                  builder: (_, Box box, __) {
                    final threats = _validThreats(box);
                    if (threats.isEmpty) return const SizedBox();
                    return ThreatHazardLayer.dotLayer(threats);
                  },
                ),

                // 🔴 THREAT – CLICKABLE TAP AREA (TOP MOST)
                ValueListenableBuilder(
                  valueListenable: Hive.box('threats').listenable(),
                  builder: (_, Box box, __) {
                    final threats = _validThreats(box);
                    if (threats.isEmpty) return const SizedBox();

                    return ThreatHazardLayer.tapAreaLayer(threats, (id) {
                      Hive.box('ui_state').put('selected_threat_id', id);
                    });
                  },
                ),

                // ================= TRANSECT START MARKERS =================
                ValueListenableBuilder(
                  valueListenable: Hive.box('transect_points').listenable(),
                  builder: (_, Box box, __) {
                    final seen = <String, LatLng>{};

                    for (final v in box.values.whereType<Map>()) {
                      final id = v['transectId'];
                      final lat = v['lat'];
                      final lng = v['lng'];

                      if (id is! String || lat == null || lng == null) continue;

                      seen.putIfAbsent(
                        id,
                        () => LatLng(
                          (lat as num).toDouble(),
                          (lng as num).toDouble(),
                        ),
                      );
                    }

                    return MarkerLayer(
                      markers: seen.entries.map((e) {
                        return Marker(
                          point: e.value,
                          width: 26,
                          height: 26,
                          child: GestureDetector(
                            onTap: () {
                              t.selectTransect(e.key);
                              t.clearSelectedSpecies();

                              setState(() {
                                _showTransectDetails = true;
                                _showSpeciesDetails = false;
                              });
                            },
                            child: const Icon(
                              Icons.adjust,
                              color: Colors.red,
                              size: 22,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                // ================= TRANSECT LINES (LIVE + SMOOTH) =================
                ValueListenableBuilder(
                  valueListenable: t.mapTick, // 🔥 LIVE GPS REBUILD
                  builder: (_, __, ___) {
                    return ValueListenableBuilder(
                      valueListenable: Hive.box('transect_points').listenable(),
                      builder: (_, Box box, __) {
                        final selectedId = Hive.box(
                          'transects',
                        ).get('selected_transect_id');

                        // 1️⃣ GROUP RAW POINTS PER TRANSECT
                        final Map<String, List<Map>> groupedRaw = {};

                        for (final v in box.values.whereType<Map>()) {
                          final id = v['transectId'];
                          final lat = v['lat'];
                          final lng = v['lng'];

                          if (id is! String || lat == null || lng == null)
                            continue;

                          groupedRaw.putIfAbsent(id, () => []);
                          groupedRaw[id]!.add(v);
                        }

                        // 2️⃣ SORT + CONVERT TO LatLng
                        final Map<String, List<LatLng>> grouped = {};

                        groupedRaw.forEach((id, list) {
                          list.sort((a, b) {
                            final ta = a['time'] ?? '';
                            final tb = b['time'] ?? '';
                            return ta.toString().compareTo(tb.toString());
                          });

                          grouped[id] = list
                              .map(
                                (e) => LatLng(
                                  (e['lat'] as num).toDouble(),
                                  (e['lng'] as num).toDouble(),
                                ),
                              )
                              .toList();
                        });

                        // 3️⃣ DRAW POLYLINES
                        return PolylineLayer(
                          polylines: grouped.entries.expand((entry) {
                            final id = entry.key;
                            final isSelected = id == selectedId;

                            final points = [...entry.value];

                            // 🔥 ADD LIVE POSITION WHILE ACTIVE

                            if (t.committedLat != null &&
                                t.committedLng != null) {
                              final live = LatLng(
                                t.committedLat!,
                                t.committedLng!,
                              );

                              if (points.isNotEmpty) {
                                final last = points.last;
                                final d = const Distance().as(
                                  LengthUnit.Meter,
                                  last,
                                  live,
                                );

                                if (d > 3.0) {
                                  points.add(live);
                                }
                              }
                            }

                            if (points.length < 2) return <Polyline>[];

                            return [
                              // SHADOW
                              Polyline(
                                points: points,
                                strokeWidth: isSelected ? 10 : 8,
                                color: Colors.black.withOpacity(0.15),
                              ),

                              // MAIN LINE
                              Polyline(
                                points: points,
                                strokeWidth: isSelected ? 6 : 4,
                                color: isSelected
                                    ? const Color(0xFF1565C0)
                                    : Colors.greenAccent.withOpacity(0.75),
                              ),
                            ];
                          }).toList(),
                        );
                      },
                    );
                  },
                ),
                // ================= ARROW =================
                if (t.hasActiveTransect)
                  ValueListenableBuilder(
                    valueListenable: t.mapTick, // ⭐ IMPORTANTE
                    builder: (_, __, ___) {
                      return MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(t.arrowLat, t.arrowLng),
                            width: 18,
                            height: 18,
                            child: AnimatedRotation(
                              turns: t.effectiveHeading / 360,
                              duration: const Duration(milliseconds: 120),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: t.isGnssActive
                                      ? Colors.blue
                                      : Colors.orange,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.navigation,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                // ================= SPECIES MARKERS =================
                ValueListenableBuilder(
                  valueListenable: Hive.box('species_points').listenable(),
                  builder: (_, Box box, __) {
                    return MarkerLayer(
                      markers: box.values.whereType<Map>().map((e) {
                        return Marker(
                          point: LatLng(e['latitude'], e['longitude']),
                          width: 36,
                          height: 36,
                          child: GestureDetector(
                            onTap: () {
                              final speciesId = e['speciesId'] ?? e['id'];

                              if (speciesId == null) {
                                debugPrint(
                                  'Species point has no speciesId: $e',
                                );
                                return;
                              }

                              Hive.box(
                                'species',
                              ).put('selected_species_id', speciesId);
                              t.selectSpecies(speciesId);

                              t.clearSelectedTransect();

                              setState(() {
                                _showSpeciesDetails = true;
                                _showTransectDetails = false;
                              });
                            },
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.orange,
                              size: 30,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
            ValueListenableBuilder<int>(
              valueListenable: t.hudTick,
              builder: (_, __, ___) {
                return _buildHud();
              },
            ),

            ValueListenableBuilder(
              valueListenable: Hive.box('ui_state').listenable(),
              builder: (_, __, ___) {
                final id = Hive.box('ui_state').get('selected_threat_id');
                if (id == null) return const SizedBox();

                return Positioned(
                  left: 16,
                  right: 16,
                  bottom: 180,
                  child: ThreatDetailsCard(
                    threatId: id, // ⭐ MAO NI ANG IMPORTANTE
                    onClose: () {
                      Hive.box('ui_state').delete('selected_threat_id');
                    },
                  ),
                );
              },
            ),

            Positioned(
              right: 12,
              bottom: 240,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: _compassEnabled ? Colors.blue : Colors.grey,
                child: const Icon(Icons.explore),
                onPressed: () {
                  setState(() => _compassEnabled = !_compassEnabled);

                  // 🔥 IMPORTANT: tell the service
                  t.setCompassEnabled(_compassEnabled);

                  if (_compassEnabled && t.hasActiveTransect) {
                    _mapController.move(
                      LatLng(t.currentLat, t.currentLng),
                      _mapController.camera.zoom,
                    );
                  }
                },
              ),
            ),
            // ================= TRANSECT DETAILS =================
            if (_showTransectDetails)
              Positioned(
                left: 16,
                right: 16,
                bottom: 160,
                child: ValueListenableBuilder(
                  valueListenable: Hive.box('transects').listenable(),
                  builder: (_, __, ___) {
                    return TransectDetailsCard(
                      onClose: () {
                        t.clearSelectedTransect();
                        setState(() => _showTransectDetails = false);
                      },
                    );
                  },
                ),
              ),

            // ================= SPECIES DETAILS =================
            if (_showSpeciesDetails)
              Positioned(
                left: 16,
                right: 16,
                bottom: 110,
                child: ValueListenableBuilder(
                  valueListenable: Hive.box('species').listenable(),
                  builder: (_, __, ___) {
                    return SpeciesDetailsCard(
                      onClose: () {
                        Hive.box(
                          'species',
                        ).delete('selected_species_id'); // 🔥 ADD
                        t.clearSelectedSpecies(); // 🔥 ADD
                        setState(() => _showSpeciesDetails = false);
                      },
                    );
                  },
                ),
              ),

            // ================= MAP LEGEND =================
            if (hasAnyData && _showLegend)
              Positioned(
                bottom: 24,
                left: 16,
                child: MapLegend(
                  hasThreats: threatSeveritiesOnMap.isNotEmpty,
                  hasSpecies: hasSpecies,
                  hasTransects: hasTransects,
                  threatSeverities: threatSeveritiesOnMap.toList(),
                  severityColor: ThreatHazardLayer.severityColor,
                ),
              ),

            Positioned(
              right: 12,
              bottom: 300,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: hasAnyData
                    ? (_showLegend ? Colors.green : Colors.black87)
                    : Colors.grey,
                onPressed: hasAnyData
                    ? () {
                        setState(() => _showLegend = !_showLegend);
                      }
                    : null,
                child: const Icon(Icons.map, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// 🟦 TRANSECT DETAILS CARD (WITH DELETE)
// =======================================================
class TransectDetailsCard extends StatelessWidget {
  final VoidCallback onClose;
  const TransectDetailsCard({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final t = TransectService();
    final box = Hive.box('transects');

    final id = box.get('selected_transect_id');

    if (id == null) return const SizedBox();

    final isActive = t.hasActiveTransect && t.activeTransectId == id;

    final pointsBox = Hive.box('transect_points');

    final pts = pointsBox.values
        .whereType<Map>()
        .where((p) => p['transectId'] == id)
        .map(
          (p) => LatLng(
            (p['lat'] as num).toDouble(),
            (p['lng'] as num).toDouble(),
          ),
        )
        .toList();

    double distance = 0;
    for (int i = 1; i < pts.length; i++) {
      distance += const Distance().as(LengthUnit.Meter, pts[i - 1], pts[i]);
    }

    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  "Transect Details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: onClose),
              ],
            ),
            const SizedBox(height: 8),
            Text("Distance: ${(distance / 1000).toStringAsFixed(2)} km"),
            const SizedBox(height: 12),
            Row(
              children: [
                // ▶️ CONTINUE
                if (!isActive)
                  IconButton(
                    tooltip: 'Continue Transect',
                    icon: const Icon(Icons.play_arrow, color: Colors.green),
                    onPressed: () {
                      // optional: continue logic here
                    },
                  ),
                const SizedBox(width: 8),
                // 📊 EXPORT (DISABLED FOR NOW)
                IconButton(
                  tooltip: 'Export Transect',
                  icon: const Icon(Icons.upload_file, color: Colors.blue),
                  onPressed: () async {},
                ),
                const Spacer(),

                // 🗑 DELETE
                if (!isActive)
                  IconButton(
                    tooltip: 'Delete Transect',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await FirestoreService.deleteTransect(id);
                      await t.deleteTransectFully(id, deleteRemote: false);
                      t.clearSelectedTransect();
                      onClose();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
