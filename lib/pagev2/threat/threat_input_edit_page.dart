import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/local_photo_service.dart';
import '../../widgets/flat_card.dart';
import '../../pagev2/threat/widgets/threat_save_button.dart';

class ThreatInputV2 extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> existingData;

  const ThreatInputV2({
    super.key,
    required this.docId,
    required this.existingData,
  });

  @override
  State<ThreatInputV2> createState() => _ThreatInputV2State();
}

class _ThreatInputV2State extends State<ThreatInputV2> {
  static const Color kThreatRed = Color(0xFFD32F2F);

  // ================= STATE =================
  String assessmentPeriod = '';
  String assessmentYear = '';
  String station = '';
  String bmsLocation = '';

  String threatType = '';
  String conditionOfEvidence = '';
  String remarks = '';

  double? latitude;
  double? longitude;

  // ================= PHOTOS =================
  final List<String> existingPhotoUrls = [];
  final List<String> localPhotoPaths = [];
  bool _savingPhoto = false;

  // ================= OPTIONS =================
  final stations = [
    'Station 0',
    'Station 1',
    'Station 2',
    'Station 3',
    'Station 4',
    'Station 5',
    'Station 6',
    'Station 7',
    'Station 8',
  ];

  final threatTypes = [
    'Illegal Logging',
    'Kaingin',
    'Poaching',
    'Mining',
    'Encroachment',
    'Pollution',
    'Forest Fire / Grass Fire',
    'Invasive Species',
  ];

  final evidenceConditions = ['Fresh', 'Old', 'Ongoing', 'Unknown'];

  // =========================================================
  // INIT
  // =========================================================
  @override
  void initState() {
    super.initState();
    _loadExisting(widget.existingData);
  }

  void _loadExisting(Map<String, dynamic> d) {
    assessmentPeriod = d['assessmentPeriod'] ?? '';
    assessmentYear = d['assessmentYear']?.toString() ?? '';
    station = d['station'] ?? '';
    bmsLocation = d['bmsLocation'] ?? '';

    threatType = d['threatType'] ?? '';
    conditionOfEvidence = d['conditionOfEvidence'] ?? '';
    remarks = d['remarks'] ?? '';

    latitude = d['latitude'];
    longitude = d['longitude'];

    if (d['photoUrls'] is List) {
      existingPhotoUrls.addAll(List<String>.from(d['photoUrls']));
    }

    if (d['localPhotoPaths'] is List) {
      localPhotoPaths.addAll(List<String>.from(d['localPhotoPaths']));
    }
  }

  // =========================================================
  // PHOTO
  // =========================================================
  Future<void> _addPhoto() async {
    if (_savingPhoto) return;
    _savingPhoto = true;

    try {
      final path = await LocalPhotoService.captureAndSave(prefix: 'threat');
      if (path != null && mounted) {
        setState(() => localPhotoPaths.add(path));
      }
    } finally {
      _savingPhoto = false;
    }
  }

  void _showImageViewer(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: url.startsWith('http')
                  ? Image.network(url, fit: BoxFit.contain)
                  : Image.file(File(url), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),
      appBar: AppBar(
        title: const Text('Edit Threat'),
        backgroundColor: kThreatRed,
      ),
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 140),
        children: [
          /// ================= GPS (READ ONLY) =================
          FlatCard(
            title: 'GPS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (latitude != null && longitude != null)
                      ? 'GPS Loaded'
                      : 'No GPS',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (latitude != null && longitude != null) ...[
                  const SizedBox(height: 6),
                  Text('Lat: ${latitude!.toStringAsFixed(6)}'),
                  Text('Lng: ${longitude!.toStringAsFixed(6)}'),
                ],
              ],
            ),
          ),

          /// ================= PHOTO =================
          FlatCard(
            title: 'Photo Evidence',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                /// 🌐 CLOUD PHOTOS
                ...existingPhotoUrls.map((url) {
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _showImageViewer(context, url),
                        child: Image.network(
                          url,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => existingPhotoUrls.remove(url));
                          },
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.red,
                            child: Icon(Icons.close, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                }),

                /// 📂 LOCAL PHOTOS
                ...localPhotoPaths.map((path) {
                  return Stack(
                    children: [
                      Image.file(
                        File(path),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => localPhotoPaths.remove(path));
                          },
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.red,
                            child: Icon(Icons.close, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                }),

                /// ➕ ADD PHOTO
                GestureDetector(
                  onTap: _addPhoto,
                  child: Container(
                    width: 90,
                    height: 90,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kThreatRed),
                    ),
                    child: _savingPhoto
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : const Icon(Icons.camera_alt),
                  ),
                ),
              ],
            ),
          ),

          /// ================= DETAILS =================
          FlatCard(
            title: 'Threat Details',
            child: Column(
              children: [
                _dropdown(
                  'Station',
                  station,
                  stations,
                  (v) => setState(() => station = v),
                ),
                _dropdown(
                  'Threat Type',
                  threatType,
                  threatTypes,
                  (v) => setState(() => threatType = v),
                ),
                _dropdown(
                  'Condition of Evidence',
                  conditionOfEvidence,
                  evidenceConditions,
                  (v) => setState(() => conditionOfEvidence = v),
                ),
              ],
            ),
          ),

          /// ================= REMARKS =================
          FlatCard(
            title: 'Remarks',
            child: TextField(
              maxLines: 3,
              controller: TextEditingController(text: remarks),
              onChanged: (v) => remarks = v,
              decoration: _dec('Remarks'),
            ),
          ),

          /// ================= SAVE =================
          ThreatSaveButton(
            isEdit: true,
            docId: widget.docId,
            scaffoldContext: context,
            payload: {
              'assessmentPeriod': assessmentPeriod,
              'assessmentYear': assessmentYear,
              'station': station,
              'bmsLocation': bmsLocation,
              'threatType': threatType,
              'conditionOfEvidence': conditionOfEvidence,
              'remarks': remarks,
              'latitude': latitude,
              'longitude': longitude,
              'photoUrls': existingPhotoUrls,
              'localPhotoPaths': localPhotoPaths,
            },
          ),
        ],
      ),
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================
  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value.isEmpty ? null : value,
        decoration: _dec(label),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );
}
