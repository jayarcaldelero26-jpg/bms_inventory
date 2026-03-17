import 'package:flutter/material.dart';

import 'widgets/gps_status_card.dart';
import 'widgets/assessment_section.dart';
import 'widgets/activity_section.dart';
import 'widgets/additional_details_section.dart';
import 'widgets/human_save_button.dart';

class HumanActivityInputV2 extends StatefulWidget {
  final String docId;
  final Map<String, dynamic>? existingData;

  const HumanActivityInputV2({
    super.key,
    required this.docId,
    this.existingData,
  });

  @override
  State<HumanActivityInputV2> createState() =>
      _HumanActivityInputV2State();
}

class _HumanActivityInputV2State extends State<HumanActivityInputV2> {
  static const Color kPrimaryGreen = Color(0xFF4CAF50);

  double? latitude;
  double? longitude;

  String assessmentPeriod = '';
  String assessmentYear = '';
  String station = '';

  /// ✅ NEW FIELD
  String bmsLocation = '';

  String activityType = '';
  String intensity = '';
  String frequency = '';

  String locationDescription = '';
  String remarks = '';
 


  bool get isEdit => widget.existingData != null;

  final bmsLocations = const [
    'San Isidro',
    'Governor Generoso',
    'Mati City',
  ];

  @override
  void initState() {
    super.initState();

    final d = widget.existingData;
    if (d != null) {
      assessmentPeriod = d['assessmentPeriod'] ?? '';
      assessmentYear = d['assessmentYear']?.toString() ?? '';
      station = d['station'] ?? '';
      bmsLocation = d['bmsLocation'] ?? '';


      /// ✅ LOAD BMS LOCATION (EDIT MODE SAFE)
      bmsLocation = d['bmsLocation'] ?? '';

      activityType = d['activityType'] ?? '';
      intensity = d['intensity'] ?? '';
      frequency = d['frequency'] ?? '';

      locationDescription = d['locationDescription'] ?? '';
      remarks = d['remarks'] ?? '';

      latitude = d['latitude'];
      longitude = d['longitude'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Human Activity' : 'Add Human Activity'),
        backgroundColor: kPrimaryGreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 📍 GPS
            GpsStatusCard(
              onLocationReady: (lat, lng) {
                latitude = lat;
                longitude = lng;
              },
            ),
            const SizedBox(height: 16),

            /// 📋 ASSESSMENT
            AssessmentSection(
              initialPeriod: assessmentPeriod,
              initialYear: assessmentYear,
              initialStation: station,
              initialBmsLocation: bmsLocation,
              onChanged: (p, y, s, bms) {
              assessmentPeriod = p;
              assessmentYear = y;
              station = s;
              bmsLocation = bms;
            },

            ),
            const SizedBox(height: 16),

            /// 🚶 ACTIVITY
            ActivitySection(
              initialActivityType: activityType,
              initialIntensity: intensity,
              initialFrequency: frequency,
              onChanged: (a, i, f) {
                activityType = a;
                intensity = i;
                frequency = f;
              },
            ),
            const SizedBox(height: 16),

            /// 📝 DETAILS
            AdditionalDetailsSection(
              initialLocation: locationDescription,
              initialRemarks: remarks,
              onChanged: (l, r) {
                locationDescription = l;
                remarks = r;
              },
            ),
            const SizedBox(height: 24),

            /// 💾 SAVE BUTTON (OFFLINE + EDIT SAFE)
            Builder(
              builder: (scaffoldContext) {
                return HumanActivitySaveButton(
                  scaffoldContext: scaffoldContext,
                  payload: {
                    'assessmentPeriod': assessmentPeriod,
                    'assessmentYear': assessmentYear,
                    'station': station,
                    'bmsLocation': bmsLocation, // ✅ INCLUDED
                    'activityType': activityType,
                    'intensity': intensity,
                    'frequency': frequency,
                    'locationDescription': locationDescription,
                    'remarks': remarks,
                    'latitude': latitude,
                    'longitude': longitude,
                    'docId': widget.docId,
                    'isEdit': isEdit,
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
