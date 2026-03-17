import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class OfflinePhotoRecovery {
  static Future<void> recover() async {
    final box = Hive.box('offline_logs');

    for (final key in box.keys) {
      final log = box.get(key);
      if (log == null) continue;

      final data = Map<String, dynamic>.from(log['data'] ?? {});
      if (data.containsKey('localPhotoPaths')) continue;

      final localId = log['localId'];
      final dir = Directory(
        '/storage/emulated/0/Android/data/com.example.bms_inventory/files',
      );

      if (!dir.existsSync()) continue;

      final matches = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.contains(localId))
          .map((f) => f.path)
          .toList();

      if (matches.isEmpty) continue;

      data['localPhotoPaths'] = matches;

      await box.put(key, {
        ...log,
        'data': data,
        'status': 'pending',
        'syncing': false,
        'error': null,
      });

      debugPrint('♻️ RECOVERED PHOTO PATHS for $localId');
    }
  }
}
