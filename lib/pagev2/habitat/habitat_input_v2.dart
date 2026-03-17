import 'package:flutter/material.dart';

import '../human/widgets/gps_status_card.dart';
import '../human/widgets/assessment_section.dart';
import '../human/widgets/additional_details_section.dart';
import 'widgets/habitat_details_section.dart';
import 'widgets/habitat_disturbance_section.dart';
import 'widgets/habitat_save_button.dart';

class HabitatInputV2 extends StatefulWidget {
  final String docId;
  final Map<String, dynamic>? existingData;

  const HabitatInputV2({
    super.key,
    required this.docId,
    this.existingData,
  });

  @override
  State<HabitatInputV2> createState() => _HabitatInputV2State();
}

class _HabitatInputV2State extends State<HabitatInputV2> {
  static const Color kHabitatColor = Color(0xFFD7B899);

  // ================= STATE =================
  double? latitude;
  double? longitude;

  String assessmentPeriod = '';
  String assessmentYear = '';
  String station = '';
  String bmsLocation = '';

  String habitatType = '';
  String forestCover = '';
  String waterCondition = '';

  bool invasivePresent = false;
  String invasiveDetails = '';

  List<String> disturbances = [];
  String remarks = '';

  bool get isEdit => widget.existingData != null;

  @override
  void initState() {
    super.initState();
    final d = widget.existingData;

    if (d != null) {
      assessmentPeriod = d['assessmentPeriod'] ?? '';
      assessmentYear = d['assessmentYear']?.toString() ?? '';
      station = d['station'] ?? '';
      bmsLocation = d['bmsLocation'] ?? '';

      habitatType = d['habitatType'] ?? '';
      forestCover = d['forestCover'] ?? '';
      waterCondition = d['waterCondition'] ?? '';

      invasivePresent = d['invasivePresent'] ?? false;
      invasiveDetails = d['invasiveDetails'] ?? '';

      disturbances = List<String>.from(d['disturbances'] ?? []);
      remarks = d['remarks'] ?? '';

      latitude = d['latitude'];
      longitude = d['longitude'];
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Habitat' : 'Add Habitat'),
        backgroundColor: kHabitatColor,
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

            /// 🌿 HABITAT DETAILS
            HabitatDetailsSection(
              initialHabitatType: habitatType,
              initialForestCover: forestCover,
              initialWaterCondition: waterCondition,
              initialInvasivePresent: invasivePresent,
              initialInvasiveDetails: invasiveDetails,
              onChanged: (h, f, w, inv, invDet) {
                habitatType = h;
                forestCover = f;
                waterCondition = w;
                invasivePresent = inv;
                invasiveDetails = invDet;
              },
            ),
            const SizedBox(height: 16),

            /// ⚠️ DISTURBANCES
            HabitatDisturbanceSection(
              initialDisturbances: disturbances,
              onChanged: (list) => disturbances = list,
            ),
            const SizedBox(height: 16),

            /// 📝 REMARKS
            AdditionalDetailsSection(
              initialRemarks: remarks,
              onChanged: (_, r) => remarks = r,
            ),
            const SizedBox(height: 24),

            /// 💾 SAVE BUTTON (LOGIC OUTSIDE PAGE)
            Builder(
              builder: (scaffoldContext) {
                return HabitatSaveButton(
                  scaffoldContext: scaffoldContext,
                  payload: {
                    'assessmentPeriod': assessmentPeriod,
                    'assessmentYear': assessmentYear,
                    'station': station,
                    'bmsLocation': bmsLocation,

                    'habitatType': habitatType,
                    'forestCover': forestCover,
                    'waterCondition': waterCondition,
                    'invasivePresent': invasivePresent,
                    'invasiveDetails': invasiveDetails,
                    'disturbances': disturbances,
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
