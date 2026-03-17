import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../transect/legacy/transect_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

// 🔥 OFFLINE SERVICE (AYAW ILISI)
import '../../../offline/offline_service.dart';

class SpeciesSaveButton extends StatefulWidget {
  final Map<String, dynamic> payload;
  final BuildContext scaffoldContext;
  final bool isEdit;
  final String? docId; // used only when editing online
  final Future<Map<String, dynamic>> Function()? onBeforeSave;
  const SpeciesSaveButton({
    super.key,
    required this.payload,
    required this.scaffoldContext,
    this.isEdit = false,
    this.docId,
    this.onBeforeSave,
  });

  @override
  State<SpeciesSaveButton> createState() => _SpeciesSaveButtonState();
}

class _SpeciesSaveButtonState extends State<SpeciesSaveButton> {
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

  // ================= SAVE LOGIC =================
  Future<void> _save() async {
    Map<String, dynamic> p = Map<String, dynamic>.from(widget.payload);

    // 🔥 RUN onBeforeSave IF PRESENT
    if (widget.onBeforeSave != null) {
      final extra = await widget.onBeforeSave!();
      p.addAll(extra);
    }

    final speciesId =
        widget.payload['speciesId'] as String? ??
        widget.payload['id'] as String? ??
        const Uuid().v4();
    p['id'] = speciesId;

    /// ================= VALIDATION =================

    // 🔒 HARD BLOCK if no active transect
    final transect = TransectService();

    // 🔒 HARD BLOCK if no active transect
    if (!widget.isEdit && !transect.hasActiveTransect) {
      _showErrorSnackBar('No active transect. Start transect first.');
      return;
    }

    // 🔥 ATTACH TO TRANSECT
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

    // 🔒 COUNT VALIDATION & NORMALIZATION (NEW RECORDS ONLY)
    final rawCount = widget.payload['count'];

    // 🔥 ALLOW "Prominent"
    if (rawCount == null) {
      _showErrorSnackBar('Please enter count or mark as Prominent.');
      return;
    }

    if (rawCount is int) {
      if (rawCount <= 0) {
        _showErrorSnackBar('Count must be greater than 0.');
        return;
      }
      p['count'] = rawCount;
    } else if (rawCount is String && rawCount == 'Prominent') {
      // ✅ OK — qualitative abundance
      p['count'] = rawCount;
    } else {
      _showErrorSnackBar('Invalid count value.');
      return;
    }

    setState(() => isSaving = true);

    try {
      final results = await Connectivity().checkConnectivity();
      final isOnline =
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi);

      final data = {...p, 'updatedAt': DateTime.now().toIso8601String()};
      data.removeWhere((k, v) => v == null);
      if (isOnline) {
        /// 🟢 ONLINE SAVE
        if (widget.isEdit && widget.docId != null) {
          await FirebaseFirestore.instance
              .collection('species_records')
              .doc(widget.docId)
              .update(data);
        } else {
          await FirebaseFirestore.instance
              .collection('species_records')
              .doc(speciesId)
              .set({
                ...data,
                'createdAt': DateTime.now().toIso8601String(),
              });
        }
        final speciesBox = Hive.box('species');
        final pointsBox = Hive.box('species_points');

        await speciesBox.put(speciesId, {
          'id': speciesId,
          'scientificName': p['scientificName'],
          'commonName': p['commonName'],
          'localPhotoPaths': p['localPhotoPaths'] ?? [],
          'category': p['category'],
          'floraType': p['floraType'],
          'faunaType': p['faunaType'],
          'remarks': p['remarks'],
          'count': p['count'],
          'latitude': p['latitude'],
          'longitude': p['longitude'],
          'elevation_m_asl': p['elevation_m_asl'],
          'observedAt': p['observedAt'],
          'source': 'cloud',
          'synced': true,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        // 🔥 UPDATE existing point instead of add
        for (final k in pointsBox.keys) {
          final v = pointsBox.get(k);
          if (v is Map && v['speciesId'] == speciesId) {
            await pointsBox.put(k, {
              ...v,
              'scientificName': p['scientificName'],
              'commonName': p['commonName'],
              'latitude': p['latitude'],
              'longitude': p['longitude'],
              'elevation_m_asl': p['elevation_m_asl'],
            });
          }
        }

        await _showSuccessPopup(
          title: widget.isEdit ? 'Updated Successfully' : 'Saved Successfully',
          message: 'Species record has been saved online.',
        );
      } else {
        // =================================================
        // 🔥 STEP 1: NORMALIZE PAYLOAD
        // =================================================
        final safeData = Map<String, dynamic>.from(data);

        safeData['scientificName'] =
            safeData['scientificName']?.toString() ?? '';

        safeData['commonName'] = safeData['commonName']?.toString() ?? '';

        safeData['localPhotoPaths'] =
            (safeData['localPhotoPaths'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        // =================================================
        // 🟡 OFFLINE EDIT (UPDATE ONLY)
        // =================================================
        if (widget.isEdit && widget.docId != null) {
          await OfflineService.save(
            type: 'species_edit',
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

        // =================================================
        // 🟢 OFFLINE NEW RECORD
        // =================================================
        await OfflineService.save(
          type: 'species',
          data: {
            ...safeData,
            'id': speciesId,
            'createdAt': DateTime.now().toIso8601String(),
          },
          localId: speciesId,
        );

        await Hive.box('species').put(speciesId, {
          'id': speciesId,
          'scientificName': p['scientificName'],
          'commonName': p['commonName'],
          'localPhotoPaths': List<String>.from(p['localPhotoPaths'] ?? []),
          'category': p['category'],
          'floraType': p['floraType'],
          'faunaType': p['faunaType'],
          'remarks': p['remarks'],
          'count': p['count'],
          'latitude': p['latitude'],
          'longitude': p['longitude'],
          'elevation_m_asl': p['elevation_m_asl'],
          'observedAt': p['observedAt'],
          'source': 'local',
          'synced': false,
          'createdAt': DateTime.now().toIso8601String(),
        });

        await Hive.box('species_points').add({
          'speciesId': speciesId,
          'transectId': p['transectId'],
          'scientificName': p['scientificName'],
          'commonName': p['commonName'],
          'latitude': p['latitude'],
          'longitude': p['longitude'],
          'elevation_m_asl': p['elevation_m_asl'],
          'observedAt': p['observedAt'],
          'category': p['category'],
          'source': 'local',
        });

        await _showSuccessPopup(
          title: 'Saved Offline',
          message: 'Species record saved to offline logs.',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Save failed: $e');
    } finally {
      setState(() => isSaving = false);
    }
  }

  // ================= SUCCESS POPUP =================
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

    Navigator.pop(widget.scaffoldContext); // close dialog
    Navigator.pop(widget.scaffoldContext, true); // exit input page
  }

  // ================= ERROR =================
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(widget.scaffoldContext)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
  }
}
