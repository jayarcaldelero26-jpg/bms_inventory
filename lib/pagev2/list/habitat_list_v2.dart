import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../view/habitat_view_page.dart';

class HabitatListV2 extends StatefulWidget {
  static const Color kHabitatColor = Color(0xFFC8A97E);

  final String station;
  final int assessmentYear;

  const HabitatListV2({
    super.key,
    required this.station,
    required this.assessmentYear,
  });

  @override
  State<HabitatListV2> createState() => _HabitatListV2State();
}

class _HabitatListV2State extends State<HabitatListV2> {
  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('habitat_records')
        .where('station', isEqualTo: widget.station)
        .where('assessmentYear', isEqualTo: widget.assessmentYear)
        .orderBy('habitatType');

    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),

      appBar: AppBar(
        title: const Text('Habitat Records'),
        backgroundColor: HabitatListV2.kHabitatColor,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No habitat records found',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,

                /// 👁 TAP → VIEW DETAILS
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HabitatViewPage(
                        docId: doc.id,
                        data: data,
                      ),
                    ),
                  );

                  if (result == true) {
                    setState(() {}); // 🔁 refresh after delete/update
                  }
                },

                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.park,
                      color: Colors.teal,
                      size: 32,
                    ),

                    title: Text(
                      data['habitatType'] ?? 'Unknown Habitat',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    subtitle: Text(
                      'Forest Cover: ${data['forestCover'] ?? '—'}\n'
                      'Water: ${data['waterCondition'] ?? '—'}\n'
                      'Station: ${data['station'] ?? '—'}',
                      style: const TextStyle(height: 1.4),
                    ),

                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
