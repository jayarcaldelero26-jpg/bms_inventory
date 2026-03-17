import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../legacy/transect_service.dart';
import '../../services/firestore_service.dart';
//import '../utils/transect_excel_exporter_local.dart';

DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}

class TransectViewPage extends StatelessWidget {
  final String transectId;

  const TransectViewPage({super.key, required this.transectId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),
      appBar: AppBar(
        title: const Text("Transect Report"),
        backgroundColor: Colors.green.shade700,
        actions: [
          /// 🗑️ DELETE TRANSECT
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transects')
            .doc(transectId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(
              child: Text(
                "Transect was deleted",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final data = snapshot.data!.data()! as Map<String, dynamic>;

          final DateTime? startTime = parseDate(data['startTime']);
          final DateTime? endTime = parseDate(data['endTime']);

          final distance = (data['distance'] ?? data['distanceMeters'] ?? 0)
              .toDouble();

          final minElev = (data['minElevation'] ?? data['elevationMin'] ?? 0)
              .toDouble();
          final maxElev = (data['maxElevation'] ?? data['elevationMax'] ?? 0)
              .toDouble();

          final startLat = (data['startLat'] ?? 0).toDouble();
          final startLng = (data['startLng'] ?? 0).toDouble();
          final endLat = (data['endLat'] ?? 0).toDouble();
          final endLng = (data['endLng'] ?? 0).toDouble();

          final startElev = (data['startElevation'] ?? 0).toDouble();
          final endElev = (data['endElevation'] ?? 0).toDouble();

          final String bmsLocation = data['bmsLocation'] ?? '--';
          final String assessmentPeriod = data['assessmentPeriod'] ?? '--';
          final String assessmentYear =
              data['assessmentYear']?.toString() ?? '--';

          final weather = data['weather'] ?? "--";

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _transectHeader(
                startTime: startTime,
                endTime: endTime,
                distance: distance,
                minElev: minElev,
                maxElev: maxElev,
                weather: weather,
                bmsLocation: bmsLocation,
                assessmentPeriod: assessmentPeriod,
                assessmentYear: assessmentYear,
                startLat: startLat,
                startLng: startLng,
                endLat: endLat,
                endLng: endLng,
                startElev: startElev,
                endElev: endElev,
              ),
              const SizedBox(height: 20),

              _recordSection(
                title: "Species",
                icon: Icons.pets,
                collection: "species_records",
              ),
              _recordSection(
                title: "Threats",
                icon: Icons.warning,
                collection: "threat_records",
              ),
              _recordSection(
                title: "Habitat",
                icon: Icons.terrain,
                collection: "habitat_records",
              ),
              _recordSection(
                title: "Human Activity",
                icon: Icons.groups,
                collection: "human_activity_records",
              ),
            ],
          );
        },
      ),
    );
  }

  // ================= TRANSECT HEADER =================

  Widget _transectHeader({
    required DateTime? startTime,
    required DateTime? endTime,
    required double distance,
    required double minElev,
    required double maxElev,
    required String weather,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required double startElev,
    required double endElev,
    required String bmsLocation,
    required String assessmentPeriod,
    required String assessmentYear,
  }) {
    String fmt(DateTime? d) {
      if (d == null) return "--";
      return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} "
          "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
    }

    String gps(double v) => v == 0 ? "--" : v.toStringAsFixed(6);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.green.shade700,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Transect Summary",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "$bmsLocation • $assessmentPeriod $assessmentYear",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),

          const SizedBox(height: 10),
          Text(
            "Start: ${fmt(startTime)}",
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            "End:   ${fmt(endTime)}",
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            "Weather: $weather",
            style: const TextStyle(color: Colors.white),
          ),

          const SizedBox(height: 10),

          Text(
            "Distance: ${(distance / 1000).toStringAsFixed(2)} km",
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            "Elevation: ${minElev.toStringAsFixed(0)} – ${maxElev.toStringAsFixed(0)} m",
            style: const TextStyle(color: Colors.white),
          ),

          const Divider(color: Colors.white24, height: 20),

          Text(
            "Start GPS: ${gps(startLat)}, ${gps(startLng)}",
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            "End GPS:   ${gps(endLat)}, ${gps(endLng)}",
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            "Start Elevation: ${startElev.toStringAsFixed(1)} m",
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            "End Elevation:   ${endElev.toStringAsFixed(1)} m",
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ================= RECORD SECTIONS =================

  Widget _recordSection({
    required String title,
    required IconData icon,
    required String collection,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('transectId', isEqualTo: transectId)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: Icon(icon, color: Colors.green),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= DELETE =================

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Transect'),
        content: const Text(
          'This will delete this transect and ALL linked records.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteTransect();
      if (!context.mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _deleteTransect() async {
    final transectService = TransectService();

    await FirestoreService.deleteTransect(transectId);
    await transectService.deleteTransectFully(
      transectId,
      deleteRemote: false,
    );

    transectService.clearSelectedTransect();
  }
}
