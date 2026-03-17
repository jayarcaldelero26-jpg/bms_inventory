import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../view/human_activity_view_page.dart';

class HumanActivityListV2 extends StatefulWidget {
  static const Color kHumanYellow = Color(0xFFFFC107);
  final String station;
  final int assessmentYear;

  const HumanActivityListV2({
    super.key,
    required this.station,
    required this.assessmentYear,
  });

  @override
  State<HumanActivityListV2> createState() => _HumanActivityListV2State();
}

class _HumanActivityListV2State extends State<HumanActivityListV2> {
  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('human_activity_records')
        .where('station', isEqualTo: widget.station)
        .where('assessmentYear', isEqualTo: widget.assessmentYear)
        .orderBy('activityType');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Human Activity Records'),
        backgroundColor: HumanActivityListV2.kHumanYellow,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No human activity recorded'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,

                /// 👁 TAP → VIEW DETAILS
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HumanActivityViewPage(
                        docId: doc.id,
                        data: data,
                      ),
                    ),
                  );

                  if (result == true) {
                    setState(() {}); // 🔁 refresh after delete
                  }
                },

                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.people_alt,
                      color: Colors.amber,
                      size: 32,
                    ),
                    title: Text(
                      data['activityType'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'Location: ${data['bmsLocation'] ?? '—'}\n'
                      'Intensity: ${data['intensity']}  |  '
                      'Frequency: ${data['frequency']}  |  '
                      'Station: ${data['station']}',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.amber,
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
