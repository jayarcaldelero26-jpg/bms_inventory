import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:bms_inventory/pagev2/view/human_activity_view_page.dart';

class HumanActivityListPage extends StatefulWidget {
  static const Color kHumanYellow = Color(0xFFFFC107);
  const HumanActivityListPage({super.key});

  @override
  State<HumanActivityListPage> createState() =>
      _HumanActivityListPageState();
}

class _HumanActivityListPageState
    extends State<HumanActivityListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),

      appBar: AppBar(
        title: const Text('Human Activity Records'),
        backgroundColor: HumanActivityListPage.kHumanYellow,
      ),


      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('human_activity_records')
            .orderBy('createdAt', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No human activity recorded',
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
                      data['activityType'] ?? 'Unknown Activity',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    subtitle: Text(
                      'Location: ${data['bmsLocation'] ?? '—'}\n'
                      'Intensity: ${data['intensity']}  |  '
                      'Frequency: ${data['frequency']}\n'
                      'Station: ${data['station']}',
                      
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
