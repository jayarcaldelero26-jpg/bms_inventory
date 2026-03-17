import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class OfflineService {
  static Future<void> save({
    required String type,
    required Map<String, dynamic> data,
    String? localId,
  }) async {
    final box = Hive.box('offline_logs');
    final id = localId ?? const Uuid().v4();

    await box.put(id, {
      'localId': id,
      'type': type, // species | threat | habitat | human_activity
      'data': data,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
      'syncedAt': null,
      'error': null,
    });
  }
}
