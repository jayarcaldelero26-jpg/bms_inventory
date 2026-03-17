import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:bms_inventory/pagev2/view/species_view_page.dart';

class SpeciesListV2 extends StatefulWidget {
  static const Color kSpeciesGreen = Color(0xFF4CAF50);

  final String category;
  final String station;
  final int assessmentYear;

  const SpeciesListV2({
    super.key,
    required this.category,
    required this.station,
    required this.assessmentYear,
  });

  @override
  State<SpeciesListV2> createState() => _SpeciesListV2State();
}

class _SpeciesListV2State extends State<SpeciesListV2> {
  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('species_records')
        .where('category', isEqualTo: widget.category)
        .where('station', isEqualTo: widget.station)
        .where('assessmentYear', isEqualTo: widget.assessmentYear)
        .orderBy('scientificName');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Species Records'),
        backgroundColor: SpeciesListV2.kSpeciesGreen,
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
                'No species recorded',
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

              final isFlora = data['category'] == 'Flora';

              return GestureDetector(
                behavior: HitTestBehavior.opaque,

                /// 👁 TAP → VIEW DETAILS
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SpeciesViewPage(
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
                    leading: Icon(
                      isFlora ? Icons.eco : Icons.pets,
                      color: isFlora
                          ? Colors.green.shade600
                          : Colors.brown.shade500,
                      size: 32,
                    ),

                    title: Text(
                      data['scientificName'] ?? 'Unknown Species',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    subtitle: Text(
                      'Category: ${data['category'] ?? '—'}\n'
                      'Count: ${data['count'] ?? '—'}  |  '
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
