import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class OfflinePhotoRepair {
  /// 🔧 Repairs offline_logs by restoring localPhotoPaths
  static Future<void> repair() async {
    final offlineBox = Hive.box('offline_logs');

    for (final key in offlineBox.keys) {
      final log = offlineBox.get(key);
      if (log == null) continue;

      final data = Map<String, dynamic>.from(log['data'] ?? {});
      final type = log['type'];

      // already has photos → skip
      if (data['localPhotoPaths'] is List &&
          (data['localPhotoPaths'] as List).isNotEmpty) {
        continue;
      }

      // try to recover from Excel-style fields
      final rawPhotos = data['photoPaths'] ?? data['photos'] ?? data['images'];

      if (rawPhotos == null) continue;

      List<String> recovered = [];

      if (rawPhotos is String) {
        recovered = rawPhotos
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.startsWith('/data/') && File(e).existsSync())
            .toList();
      }

      if (rawPhotos is List) {
        recovered = rawPhotos
            .map((e) => e.toString())
            .where((e) => e.startsWith('/data/') && File(e).existsSync())
            .toList();
      }

      if (recovered.isEmpty) continue;

      debugPrint('🛠 REPAIRED ${recovered.length} PHOTOS → $type');

      await offlineBox.put(key, {
        ...log,
        'status': 'pending',
        'syncing': false,
        'data': {...data, 'localPhotoPaths': recovered},
      });
    }
  }
}
