import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'transect_view_page.dart';

class TransectListPage extends StatelessWidget {
  const TransectListPage({super.key});
  DateTime? parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is Timestamp) return v.toDate();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),
      appBar: AppBar(
        title: const Text("Transect Reports"),
        backgroundColor: Colors.green.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('transects').snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No transects recorded yet.",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final transects = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transects.length,
            itemBuilder: (context, index) {
              final doc = transects[index];
              final data = doc.data() as Map<String, dynamic>;
              final String bmsLocation = data['bmsLocation'] ?? '--';
              final String assessmentPeriod = data['assessmentPeriod'] ?? '--';
              final String assessmentYear =
                  data['assessmentYear']?.toString() ?? '--';

              final String transectId = data['transectId'] ?? doc.id;

              final DateTime startTime =
                  parseDate(data['startTime']) ?? DateTime.now();

              final double distance =
                  (data['distance'] ?? data['distanceMeters'] ?? 0).toDouble();

              final double minElev =
                  (data['minElevation'] ?? data['elevationMin'] ?? 0)
                      .toDouble();

              final double maxElev =
                  (data['maxElevation'] ?? data['elevationMax'] ?? 0)
                      .toDouble();

              final String weather =
                  data['weather']?.toString() ?? "No weather";

              return _transectCard(
                context: context,
                transectId: transectId,
                startTime: startTime,
                distance: distance,
                minElev: minElev,
                maxElev: maxElev,
                weather: weather,
                assessmentPeriod: assessmentPeriod,
                assessmentYear: assessmentYear,
                bmsLocation: bmsLocation,
              );
            },
          );
        },
      ),
    );
  }

  Widget _transectCard({
    required BuildContext context,
    required String transectId,
    required DateTime startTime,
    required double distance,
    required double minElev,
    required double maxElev,
    required String weather,
    required String bmsLocation,
    required String assessmentPeriod,
    required String assessmentYear,
  }) {
    String dateLabel() {
      return "${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}";
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransectViewPage(transectId: transectId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.green.shade100,
              child: const Icon(Icons.route, color: Colors.green),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$weather  •  ${(distance / 1000).toStringAsFixed(2)} km",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    "Elev: ${minElev.toStringAsFixed(0)}–${maxElev.toStringAsFixed(0)} m",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    "$bmsLocation • $assessmentPeriod $assessmentYear",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "$weather • ${(distance / 1000).toStringAsFixed(2)} km",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
