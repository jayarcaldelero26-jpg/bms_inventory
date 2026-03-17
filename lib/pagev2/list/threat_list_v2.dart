import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../view/threat_view_page.dart';

class ThreatListV2 extends StatefulWidget {
  const ThreatListV2({super.key});

  @override
  State<ThreatListV2> createState() => _ThreatListV2State();
}

class _ThreatListV2State extends State<ThreatListV2> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Threat Records'),
        backgroundColor: Colors.red.shade700,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('threat_records')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No threat records'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.warning,
                    color: Colors.red,
                  ),
                  title: Text(
                    data['threatType'] ?? 'Unknown Threat',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Station: ${data['station']}\n'
                    'Year: ${data['assessmentYear']}',
                  ),

                  /// 👁 VIEW DETAILS
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ThreatViewPage(
                          docId: doc.id,
                          data: data,
                        ),
                      ),
                    );

                    if (result == true) {
                      setState(() {}); // 🔁 refresh after delete
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
