import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// 🔥 OFFLINE SERVICE (AYAW ILISI)
import '../../../offline/offline_service.dart';

class HabitatSaveButton extends StatefulWidget {
  final Map<String, dynamic> payload;
  final BuildContext scaffoldContext;

  const HabitatSaveButton({
    super.key,
    required this.payload,
    required this.scaffoldContext,
  });

  @override
  State<HabitatSaveButton> createState() => _HabitatSaveButtonState();
}

class _HabitatSaveButtonState extends State<HabitatSaveButton> {
  bool isSaving = false;

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.payload['isEdit'] == true;

    return SizedBox(
      width: 280,
      height: 56,
      child: ElevatedButton(
        onPressed: isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          isSaving
              ? 'Saving...'
              : isEdit
                  ? 'Update Habitat'
                  : 'Save Habitat',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SAVE LOGIC (OFFLINE SAFE, EDIT SAFE)
  // =========================================================
  Future<void> _save() async {
    final p = widget.payload;

    // ================= VALIDATION =================
    if ((p['assessmentPeriod'] ?? '').toString().isEmpty ||
        (p['assessmentYear'] ?? '').toString().isEmpty ||
        (p['station'] ?? '').toString().isEmpty ||
        (p['bmsLocation'] ?? '').toString().isEmpty ||
        (p['habitatType'] ?? '').toString().isEmpty) {
      _showErrorSnackBar(
        'Please complete all required fields before saving.',
      );
      return;
    }

    // GPS REQUIRED
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
      // 🟢 ONLINE SAVE
      // =====================================================
      if (isOnline) {
        if (isEdit && docId != null && docId.isNotEmpty) {
          // ✏️ EDIT → UPDATE SAME DOCUMENT
          await FirebaseFirestore.instance
              .collection('habitat_records')
              .doc(docId)
              .update(data);
        } else {
          // ➕ ADD → NEW DOCUMENT
          await FirebaseFirestore.instance
              .collection('habitat_records')
              .add({
            ...data,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }

        await _showSuccessPopup(
          title: isEdit ? 'Updated Successfully' : 'Saved Successfully',
          message: 'Habitat record has been saved online.',
        );
      }

      // =====================================================
      // 🔴 OFFLINE SAVE (AYAW GYUD USABA)
      // =====================================================
      else {
        await OfflineService.save(
          type: 'habitat',
          data: {
            ...data,
            'createdAt': DateTime.now().toIso8601String(),
          },
        );

        await _showSuccessPopup(
          title: 'Saved Offline',
          message: 'Habitat record saved to offline logs.',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Save failed: $e');
    } finally {
      setState(() => isSaving = false);
    }
  }

  // =========================================================
  // SUCCESS POPUP
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
  // ERROR
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
