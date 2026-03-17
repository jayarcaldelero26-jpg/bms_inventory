import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/sync_pull_service.dart';
import '../services/map_point_builder_service.dart';

import '../services/cloudinary_service.dart';

class SyncService {
  static String _mapCollection(String type) {
    switch (type) {
      case 'species':
        return 'species_records';
      case 'threat':
      case 'threat_edit':
        return 'threat_records';
      case 'habitat':
        return 'habitat_records';
      case 'human_activity':
        return 'human_activity_records';
      default:
        throw Exception('Unknown type: $type');
    }
  }

  /// 🔄 MAIN SYNC (SAFE + PHOTO-FIRST)
  static Future<void> sync({bool fromAuto = false}) async {
    if (Firebase.apps.isEmpty) {
      debugPrint('❌ Firebase not initialized');
      return;
    }

    final box = Hive.box('offline_logs');

    debugPrint(fromAuto ? '🤖 AUTO SYNC RUNNING' : '👆 MANUAL SYNC RUNNING');

    for (final key in box.keys) {
      final log = box.get(key);
      if (log == null) continue;

      if (log['status'] != 'pending' && log['status'] != 'error') continue;

      final localId = log['localId'];
      final type = log['type'];

      debugPrint('📦 SYNCING LOG: $localId');

      await box.put(key, {...log, 'syncing': true});

      try {
        final data = Map<String, dynamic>.from(log['data'] ?? {});

        // =====================================================
        // 1️⃣ PHOTO UPLOAD PHASE (NO FIRESTORE TOUCH YET)
        // =====================================================
        final List<String> localPhotos =
            (data['localPhotoPaths'] as List?)?.cast<String>() ?? [];

        final uploadedUrls = <String>[];

        if (localPhotos.isNotEmpty) {
          debugPrint('📸 ${localPhotos.length} PHOTOS FOUND');

          int i = 0;
          for (final path in localPhotos) {
            final file = File(path);

            if (!file.existsSync()) {
              throw Exception('Missing photo file: $path');
            }

            debugPrint('⬆️ Uploading photo $i');

            final url = await CloudinaryService.uploadImage(
              imageFile: file,
              folder: 'bms_photos/$type',
              publicId: '${type}_${localId}_$i',
            );

            if (url == null || !url.startsWith('http')) {
              throw Exception('Cloudinary upload failed');
            }

            uploadedUrls.add(url);
            i++;
          }
        }

        // If photos were expected but none uploaded → STOP
        if (localPhotos.isNotEmpty &&
            uploadedUrls.length != localPhotos.length) {
          throw Exception('Incomplete photo upload');
        }

        // =====================================================
        // 2️⃣ PREPARE FINAL PAYLOAD
        // =====================================================
        if (uploadedUrls.isNotEmpty) {
          data['photoUrls'] = uploadedUrls;
          data.remove('localPhotoPaths'); // 🔒 SAFE TO REMOVE NOW
        }

        data['updatedAt'] = FieldValue.serverTimestamp();
        data['createdAt'] ??= FieldValue.serverTimestamp();

        // =====================================================
        // 3️⃣ FIRESTORE COMMIT (EDIT vs NEW)
        // =====================================================
        if (type == 'species_edit') {
          final String docId = data['docId'];

          data.remove('docId');
          data.remove('editedOffline');

          await FirebaseFirestore.instance
              .collection('species_records')
              .doc(docId)
              .update(data);
        } else if (type == 'threat_edit') {
          final String docId = data['docId'];

          data.remove('docId');
          data.remove('editedOffline');

          await FirebaseFirestore.instance
              .collection('threat_records')
              .doc(docId)
              .update(data);
        } else {
          // 🆕 NEW RECORD (species, threat, etc.)
          await FirebaseFirestore.instance
              .collection(_mapCollection(type))
              .doc(localId)
              .set(data, SetOptions(merge: true));
        }

        // =====================================================
        // 4️⃣ MARK AS SYNCED ONLY IF CLEAN
        // =====================================================
        final stillHasLocal =
            (data['localPhotoPaths'] as List?)?.isNotEmpty ?? false;

        if (stillHasLocal) {
          throw Exception('Local photos still present — sync not finalized');
        }

        await box.put(key, {
          ...log,
          'status': 'synced',
          'syncing': false,
          'syncedAt': DateTime.now().toIso8601String(),
          'error': null,
        });

        debugPrint('✅ SYNC SUCCESS: $localId');
      } catch (e, stack) {
        debugPrint('🔥 SYNC FAILED: $e');
        debugPrint(stack.toString());

        await box.put(key, {
          ...log,
          'status': 'error',
          'syncing': false,
          'error': e.toString(),
        });
      }
    }
    // ================= PULL GLOBAL DATA =================
    try {
      await SyncPullService.pullAll();
      await MapPointBuilderService.rebuildFromCloud();
      debugPrint('🌍 Map data rebuilt from cloud');
    } catch (e) {
      debugPrint('⚠️ Pull failed: $e');
    }
  }
}
