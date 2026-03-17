import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// 🔥 OFFLINE SERVICE (AYAW ILISI / AYAW TANGALA)
import '../../../offline/offline_service.dart';

class HumanActivitySaveButton extends StatefulWidget {
  final Map<String, dynamic> payload;
  final BuildContext scaffoldContext;

  const HumanActivitySaveButton({
    super.key,
    required this.payload,
    required this.scaffoldContext,
  });

  @override
  State<HumanActivitySaveButton> createState() =>
      _HumanActivitySaveButtonState();
}

class _HumanActivitySaveButtonState extends State<HumanActivitySaveButton> {
  bool isSaving = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isSaving
            ? const Text('Saving...')
            : const Text(
                'Save',
                style: TextStyle(fontSize: 16),
              ),
      ),
    );
  }

  // =========================================================
  // SAVE LOGIC (FINAL – OFFLINE SAFE, EDIT SAFE)
  // =========================================================
  Future<void> _save() async {
    final p = widget.payload;

    // ================= VALIDATION (UNCHANGED) =================
    if ((p['assessmentPeriod'] ?? '').toString().isEmpty ||
        (p['assessmentYear'] ?? '').toString().isEmpty ||
        (p['station'] ?? '').toString().isEmpty ||
        (p['bmsLocation'] ?? '').toString().isEmpty ||
        (p['activityType'] ?? '').toString().isEmpty) {
      _showErrorSnackBar(
        'Please complete all required fields before saving.',
      );
      return;
    }

    // GPS REQUIRED (UNCHANGED)
    if (p['latitude'] == null || p['longitude'] == null) {
      _showErrorSnackBar(
        'GPS location is required before saving.',
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final results = await Connectivity().checkConnectivity();
      final bool isOnline =
          results.contains(ConnectivityResult.mobile) ||
              results.contains(ConnectivityResult.wifi);

      final bool isEdit = p['isEdit'] == true;
      final String? docId = p['docId'];

      final data = {
        ...p,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // =====================================================
      // 🟢 ONLINE SAVE (ONLY PART THAT CHANGED)
      // =====================================================
      if (isOnline) {
        if (isEdit && docId != null && docId.isNotEmpty) {
          // ✏️ EDIT → UPDATE SAME DOCUMENT
          await FirebaseFirestore.instance
              .collection('human_activity_records')
              .doc(docId)
              .update(data);
        } else {
          // ➕ ADD → NEW DOCUMENT
          await FirebaseFirestore.instance
              .collection('human_activity_records')
              .add({
            ...data,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }

        await _showSuccessPopup(
          title: isEdit ? 'Updated Successfully' : 'Saved Successfully',
          message: 'Record has been saved online.',
        );
      }

      // =====================================================
      // 🔴 OFFLINE SAVE (AYAW GYUD USABA)
      // =====================================================
      else {
        await OfflineService.save(
          type: 'human_activity',
          data: {
            ...data,
            'createdAt': DateTime.now().toIso8601String(),
          },
        );

        await _showSuccessPopup(
          title: 'Saved Offline',
          message: 'Record saved to offline logs.',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Save failed: $e');
    } finally {
      setState(() => isSaving = false);
    }
  }

  // =========================================================
  // SUCCESS POPUP (UNCHANGED)
  // =========================================================
  Future<void> _showSuccessPopup({
    required String title,
    required String message,
  }) async {
    showDialog(
      context: widget.scaffoldContext,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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

    Navigator.pop(widget.scaffoldContext); // close popup
    Navigator.pop(widget.scaffoldContext, true); // exit input page
  }

  // =========================================================
  // ERROR (UNCHANGED)
  // =========================================================
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(widget.scaffoldContext)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
  }
}
