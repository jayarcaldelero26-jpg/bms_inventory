import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../widgets/flat_card.dart';
import '../../pagev2/threat/widgets/threat_save_button.dart';
import '../../services/local_photo_service.dart';
import '../../transect/legacy/transect_service.dart';

//////////////////////////////////////////////////////////////
////                 THREAT INPUT PAGE                    ///
//////////////////////////////////////////////////////////////

class ThreatInputPage extends StatefulWidget {
  const ThreatInputPage({super.key});

  @override
  State<ThreatInputPage> createState() => _ThreatInputPageState();
}

class _ThreatInputPageState extends State<ThreatInputPage> {
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
    'Poaching',
    'Kaingin',
    'Mining',
    'Pollution',
    'Encroachment',
    'Invasive Species',
    'Forest Fire / Grass Fire',
  ];

  final evidenceConditions = ['Fresh', 'Old', 'Ongoing', 'Unknown'];

  final threatSeverities = ['Low', 'Medium', 'High', 'Critical'];

  // ================= STATE =================
  String station = '';
  String threatType = '';
  String conditionOfEvidence = '';
  String invasionExtent = '';

  String threatSeverity = '';
  String observerName = '';

  double? latitude;
  double? longitude;
  double? accuracy;
  double? elevation;
  DateTime? observedAt;

  bool gettingGps = true;
  bool hasGpsFix = false;
  String gpsStatus = 'Searching GPS…';

  final remarksCtrl = TextEditingController();

  // ================= PHOTOS =================
  final List<String> localPhotoPaths = [];
  bool _savingPhoto = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    remarksCtrl.dispose();
    super.dispose();
  }

  // ================= GPS =================
  Future<void> _getLocation() async {
    setState(() {
      gettingGps = true;
      gpsStatus = 'Searching GPS…';
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw 'Location disabled';

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw 'Permission denied';
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (!mounted) return;

      setState(() {
        latitude = pos.latitude;
        longitude = pos.longitude;
        accuracy = pos.accuracy;
        elevation = pos.altitude;
        observedAt = DateTime.now();
        hasGpsFix = true;
        gpsStatus = 'GPS Locked';
        gettingGps = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        hasGpsFix = false;
        gpsStatus = 'GPS Failed';
        gettingGps = false;
      });
    }
  }

  // ================= PHOTO =================
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

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    filled: true,
    isDense: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );

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
        isExpanded: true,
        decoration: _dec(label),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }

  String _fmtObserved(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final transect = TransectService();

    if (!transect.hasActiveTransect) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4FBF4),
        appBar: AppBar(
          title: const Text('Species Observation'),
          backgroundColor: const Color(0xFF7FBF7F),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.route, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'No Active Transect',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start a transect first before recording species.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),
      appBar: AppBar(
        title: const Text('Threat Monitoring'),
        backgroundColor: Colors.red,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          /// GPS
          FlatCard(
            title: 'GPS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gpsStatus),
                if (hasGpsFix) ...[
                  Text('Lat: ${latitude!.toStringAsFixed(5)}'),
                  Text('Lng: ${longitude!.toStringAsFixed(5)}'),
                  Text('Elevation: ${elevation?.toStringAsFixed(1)} m'),
                  Text('Observed: ${_fmtObserved(observedAt)}'),
                ],
                ElevatedButton(
                  onPressed: _getLocation,
                  child: const Text('Refresh GPS'),
                ),
              ],
            ),
          ),

          FlatCard(
            title: 'Assessment',
            child: _dropdown(
              'Station',
              station,
              stations,
              (v) => setState(() => station = v),
            ),
          ),

          /// 📸 PHOTO EVIDENCE
          FlatCard(
            title: 'Photo Evidence',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...localPhotoPaths.map(
                  (p) => Image.file(
                    File(p),
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
                GestureDetector(
                  onTap: _addPhoto,
                  child: Container(
                    width: 90,
                    height: 90,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red),
                    ),
                    child: _savingPhoto
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : const Icon(Icons.camera_alt),
                  ),
                ),
              ],
            ),
          ),

          FlatCard(
            title: 'Threat',
            child: Column(
              children: [
                // ================= THREAT TYPE =================
                _dropdown(
                  'Threat Type',
                  threatType,
                  threatTypes,
                  (v) => setState(() {
                    threatType = v;

                    // 🔥 reset if not invasive
                    if (v != 'Invasive Species') {
                      invasionExtent = '';
                    }
                  }),
                ),

                // ================= EXTENT OF INVASION =================
                if (threatType == 'Invasive Species')
                  _dropdown(
                    'Extent of Invasion',
                    invasionExtent,
                    const ['Isolated', 'Scattered', 'Widespread'],
                    (v) => setState(() => invasionExtent = v),
                  ),

                // ================= CONDITION =================
                _dropdown(
                  'Condition of Evidence',
                  conditionOfEvidence,
                  evidenceConditions,
                  (v) => setState(() => conditionOfEvidence = v),
                ),
              ],
            ),
          ),

          FlatCard(
            title: 'Assessment',
            child: Column(
              children: [
                _dropdown(
                  'Threat Severity',
                  threatSeverity,
                  threatSeverities,
                  (v) => setState(() => threatSeverity = v),
                ),
                TextField(
                  decoration: _dec('Observer Name'),
                  onChanged: (v) => observerName = v,
                ),
              ],
            ),
          ),

          FlatCard(
            title: 'Remarks',
            child: TextField(
              controller: remarksCtrl,
              maxLines: 3,
              decoration: _dec('Remarks'),
            ),
          ),

          /// SAVE
          Builder(
            builder: (ctx) {
              final t = TransectService();
              return ThreatSaveButton(
                scaffoldContext: ctx,
                payload: {
                  'transectId': t.activeTransectId,
                  'bmsLocation': t.bmsLocation,
                  'assessmentPeriod': t.assessmentPeriod,
                  'assessmentYear': t.assessmentYear,
                  'station': station,
                  'threatType': threatType,
                  'conditionOfEvidence': conditionOfEvidence,
                  'threatSeverity': threatSeverity,
                  'extentOfInvasion': invasionExtent,
                  'observerName': observerName,
                  'remarks': remarksCtrl.text,
                  'latitude': latitude,
                  'longitude': longitude,
                  'accuracy': accuracy,
                  'elevation_m_asl': elevation,
                  'observedAt': observedAt?.toIso8601String(),
                  'localPhotoPaths': localPhotoPaths,
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
