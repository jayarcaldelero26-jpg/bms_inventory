import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class SyncPullService {
  static Future<void> _pull({
    required String collection,
    required String hiveBox,
  }) async {
    if (!Hive.isBoxOpen(hiveBox)) {
      await Hive.openBox(hiveBox);
    }

    final box = Hive.box(hiveBox);
    final snap = await FirebaseFirestore.instance.collection(collection).get();

    for (final doc in snap.docs) {
      final raw = doc.data();
      final data = _sanitize(raw); // 🔥 VERY IMPORTANT

      final existingKey = box.keys.firstWhere((k) {
        final v = box.get(k);
        return k == doc.id || (v is Map && v['id'] == doc.id);
      }, orElse: () => null);

      if (existingKey != null) {
        box.put(existingKey, {
          ...box.get(existingKey),
          ...data,
          'id': doc.id,
          'source': 'cloud',
          'synced': true,
        });
      } else {
        box.put(doc.id, {
          ...data,
          'id': doc.id,
          'source': 'cloud',
          'synced': true,
        });
      }
    }

    debugPrint('⬇️ Pulled ${snap.docs.length} → $hiveBox');
  }

  static Map<String, dynamic> _sanitize(Map<String, dynamic> data) {
    final clean = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is Timestamp) {
        clean[key] = value.toDate().toIso8601String();
      } else if (value is Map) {
        clean[key] = _sanitize(Map<String, dynamic>.from(value));
      } else if (value is List) {
        clean[key] = value.map((e) {
          if (e is Timestamp) {
            return e.toDate().toIso8601String();
          } else if (e is Map) {
            return _sanitize(Map<String, dynamic>.from(e));
          }
          return e;
        }).toList();
      } else {
        clean[key] = value;
      }
    });

    return clean;
  }

  static Future<void> _pullSpeciesPoints() async {
    const hiveBox = 'species_points';

    if (!Hive.isBoxOpen(hiveBox)) {
      await Hive.openBox(hiveBox);
    }

    final box = Hive.box(hiveBox);
    final snap = await FirebaseFirestore.instance
        .collection('species_points')
        .get();

    for (final doc in snap.docs) {
      final raw = doc.data();
      final data = _sanitize(raw);

      final existingKey = box.keys.firstWhere((k) {
        final v = box.get(k);
        return k == doc.id || (v is Map && v['id'] == doc.id);
      }, orElse: () => null);

      if (existingKey != null) {
        box.put(existingKey, {
          ...box.get(existingKey),
          ...data,
          'id': doc.id,
          'source': 'cloud',
          'synced': true,
        });
      } else {
        box.put(doc.id, {
          ...data,
          'id': doc.id,
          'source': 'cloud',
          'synced': true,
        });
      }
    }

    debugPrint('⬇️ Pulled ${snap.docs.length} → species_points');
  }

  // ================= PUBLIC =================
  static Future<void> pullAll() async {
    await _pull(collection: 'species_records', hiveBox: 'species');
    await _pull(collection: 'threat_records', hiveBox: 'threats');

    // 🔥 THIS WAS MISSING
    await _pullSpeciesPoints();
  }
}
