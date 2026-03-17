import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class MapPointBuilderService {
  static Future<void> rebuildFromCloud() async {
    // ================= SPECIES MAP POINTS =================
    if (!Hive.isBoxOpen('species')) {
      await Hive.openBox('species');
    }
    if (!Hive.isBoxOpen('species_points')) {
      await Hive.openBox('species_points');
    }
    if (!Hive.isBoxOpen('threats')) {
      await Hive.openBox('threats');
    }

    final speciesBox = Hive.box('species');
    final speciesPointsBox = Hive.box('species_points');
    final preservedLocalPoints = speciesPointsBox.values
        .whereType<Map>()
        .where((point) => point['source'] != 'cloud')
        .map((point) => Map<String, dynamic>.from(point))
        .toList();

    // 🔥 CLEAR OLD MAP POINTS (IMPORTANT)
    await speciesPointsBox.clear();

    final addedSpeciesIds = <String>{};

    for (final v in speciesBox.values.whereType<Map>()) {
      final lat = v['latitude'];
      final lng = v['longitude'];
      final id = v['id'];

      if (lat == null || lng == null || id == null) continue;

      speciesPointsBox.add({
        'speciesId': id,
        'latitude': lat,
        'longitude': lng,
        'elevation_m_asl': v['elevation_m_asl'],
        'observedAt': v['observedAt'],
        'category': v['category'],
        'source': v['source'] ?? 'cloud',
      });
      addedSpeciesIds.add(id.toString());
    }

    for (final point in preservedLocalPoints) {
      final speciesId = point['speciesId']?.toString();
      if (speciesId == null || addedSpeciesIds.contains(speciesId)) {
        continue;
      }
      speciesPointsBox.add(point);
      addedSpeciesIds.add(speciesId);
    }

    debugPrint('🗺️ Species map points rebuilt');

    // ================= THREATS =================
    final threatBox = Hive.box('threats');

    for (final key in threatBox.keys) {
      final v = threatBox.get(key);
      if (v is! Map) continue;

      if (v['latitude'] == null || v['longitude'] == null) continue;

      threatBox.put(key, {...v, 'source': 'cloud'});
    }

    debugPrint('🗺️ Threat map points ready');
  }
}
