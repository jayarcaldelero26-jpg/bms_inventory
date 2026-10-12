import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cds_smart_mobile/pagev2/view/habitat_view_page.dart';

class HabitatListPage extends StatefulWidget {
  static const Color kHabitatBrown = Color(0xFFBFA27A);

  const HabitatListPage({super.key});

  @override
  State<HabitatListPage> createState() => _HabitatListPageState();
}

class _HabitatListPageState extends State<HabitatListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),

      // ================= APP BAR =================
      appBar: AppBar(
        title: const Text('Habitat Records'),
        backgroundColor: HabitatListPage.kHabitatBrown,
      ),

      // ================= LIST =================
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('habitat_records')
            .orderBy('createdAt', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No habitat records',
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
                    setState(() {}); // 🔁 refresh after delete / update
                  }
                },

                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.terrain,
                      color: Colors.brown,
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
