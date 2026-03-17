// lib/utils/local_recovery_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class LocalRecoveryService {
  static Future<Map<String, dynamic>> dumpAllLocalData() async {
    final result = <String, dynamic>{};

    result['offline_logs'] = Hive.box('offline_logs').values.toList();

    result['transects'] = Hive.box('transects').toMap();

    result['transect_points'] = Hive.box('transect_points').values.toList();

    if (Hive.isBoxOpen('species_points')) {
      result['species_points'] = Hive.box('species_points').values.toList();
    }

    if (Hive.isBoxOpen('threats')) {
      result['threats'] = Hive.box('threats').values.toList();
    }

    return result;
  }

  static Future<File> exportLocalBackup() async {
    final data = await dumpAllLocalData();

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/BMS_LOCAL_BACKUP_${DateTime.now().millisecondsSinceEpoch}.json',
    );

    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));

    return file;
  }
}
