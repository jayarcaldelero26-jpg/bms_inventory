import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../transect/legacy/transect_service.dart';
import '../../../offline/offline_service.dart';

class ThreatSaveButton extends StatefulWidget {
  final Map<String, dynamic> payload;
  final BuildContext scaffoldContext;
  final bool isEdit;
  final String? docId;

  const ThreatSaveButton({
    super.key,
    required this.payload,
    required this.scaffoldContext,
    this.isEdit = false,
    this.docId,
  });

  @override
  State<ThreatSaveButton> createState() => _ThreatSaveButtonState();
}

class _ThreatSaveButtonState extends State<ThreatSaveButton> {
  bool isSaving = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          isSaving
              ? 'Saving...'
              : widget.isEdit
              ? 'Update'
              : 'Save',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  // ============================================================
  // SAVE LOGIC (MATCHES SPECIES DISCIPLINE)
  // ============================================================
  Future<void> _save() async {
    Map<String, dynamic> p = Map<String, dynamic>.from(widget.payload);
    final transect = TransectService();
    final threatId =
        widget.payload['id'] as String? ?? const Uuid().v4();
    p['id'] = threatId;

    // 🔒 REQUIRE TRANSECT ONLY FOR NEW RECORDS
    if (!widget.isEdit && !transect.hasActiveTransect) {
      _showErrorSnackBar('No active transect. Start transect first.');
      return;
    }

    // 🔥 ATTACH TRANSECT META
    if (!widget.isEdit) {
      p['bmsLocation'] ??= transect.bmsLocation;
      p['assessmentPeriod'] ??= transect.assessmentPeriod;
      p['assessmentYear'] ??= transect.assessmentYear;
      p['transectId'] ??= transect.activeTransectId;
      p['transectStart'] = transect.transectStart?.toIso8601String();
      p['distanceAtCapture'] = transect.distanceMeters;

      final missingContext = transect.missingRecordContextFields;
      if (missingContext.isNotEmpty) {
        _showErrorSnackBar(
          'Incomplete transect context: ${missingContext.join(', ')}.',
        );
        return;
      }
    }

    // ================= VALIDATION =================
    if ((p['threatType'] ?? '').toString().trim().isEmpty ||
        (p['station'] ?? '').toString().trim().isEmpty ||
        (p['conditionOfEvidence'] ?? '').toString().trim().isEmpty ||
        p['latitude'] == null ||
        p['longitude'] == null) {
      _showErrorSnackBar('Please complete all required fields.');
      return;
    }

    setState(() => isSaving = true);

    try {
      final results = await Connectivity().checkConnectivity();
      final isOnline =
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi);

      final data = {
        ...p,
        'type': 'threat',
        'updatedAt': DateTime.now().toIso8601String(),
      }..removeWhere((k, v) => v == null);

      final threatBox = Hive.box('threats');

      // =====================================================
      // 🟢 ONLINE SAVE
      // =====================================================
      if (isOnline) {
        DocumentReference ref;

        if (widget.isEdit && widget.docId != null) {
          await FirebaseFirestore.instance
              .collection('threat_records')
              .doc(widget.docId)
              .update(data);

          ref = FirebaseFirestore.instance
              .collection('threat_records')
              .doc(widget.docId);
        } else {
          ref = FirebaseFirestore.instance
              .collection('threat_records')
              .doc(threatId);
          await ref.set({
            ...data,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }

        final id = ref.id;

        // 🔥 MIRROR TO HIVE FOR MAP/OFFLINE VIEW
        await threatBox.put(id, {
          ...data,
          'id': id,
          'docId': id,
          'source': 'cloud',
          'synced': true,
        });

        await _showSuccessPopup(
          title: widget.isEdit ? 'Updated Successfully' : 'Saved Successfully',
          message: 'Threat record saved online.',
        );
      }
      // =====================================================
      // 🔴 OFFLINE SAVE
      // =====================================================
      else {
        final safeData = Map<String, dynamic>.from(data);

        safeData['threatType'] = safeData['threatType']?.toString() ?? '';
        safeData['conditionOfEvidence'] =
            safeData['conditionOfEvidence']?.toString() ?? '';
        safeData['localPhotoPaths'] =
            (safeData['localPhotoPaths'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        // 🟡 OFFLINE EDIT (SAME AS SPECIES)
        if (widget.isEdit && widget.docId != null) {
          await OfflineService.save(
            type: 'threat_edit',
            data: {
              ...safeData,
              'docId': widget.docId,
              'editedOffline': true,
              'updatedAt': DateTime.now().toIso8601String(),
            },
            localId: widget.docId,
          );

          await _showSuccessPopup(
            title: 'Saved Offline',
            message: 'Changes will sync when online.',
          );
          return; // 🔥 IMPORTANT
        }

        // 🟢 OFFLINE NEW RECORD
        await OfflineService.save(
          type: 'threat',
          data: {
            ...safeData,
            'id': threatId,
            'createdAt': DateTime.now().toIso8601String(),
          },
          localId: threatId,
        );

        await threatBox.put(threatId, {
          ...safeData,
          'id': threatId,
          'source': 'local',
          'synced': false,
        });

        await _showSuccessPopup(
          title: 'Saved Offline',
          message: 'Threat record saved to offline logs.',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Save failed: $e');
    } finally {
      setState(() => isSaving = false);
    }
  }

  // ============================================================
  // SUCCESS POPUP
  // ============================================================
  Future<void> _showSuccessPopup({
    required String title,
    required String message,
  }) async {
    showDialog(
      context: widget.scaffoldContext,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 900));
    Navigator.pop(widget.scaffoldContext);
    Navigator.pop(widget.scaffoldContext, true);
  }

  // ============================================================
  // ERROR
  // ============================================================
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(widget.scaffoldContext)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
  }
}
