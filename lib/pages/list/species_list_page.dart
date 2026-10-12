import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cds_smart_mobile/pagev2/view/species_view_page.dart';

class SpeciesListPage extends StatefulWidget {
  static const Color kSpeciesGreen = Color(0xFF4CAF50);

  const SpeciesListPage({super.key});

  @override
  State<SpeciesListPage> createState() => _SpeciesListPageState();
}

class _SpeciesListPageState extends State<SpeciesListPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = value.toLowerCase().trim();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),
      appBar: AppBar(
        title: const Text('Species Records'),
        backgroundColor: SpeciesListPage.kSpeciesGreen,
      ),

      body: Column(
        children: [
          // ================= SEARCH =================
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search scientific or common name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          // ================= LIST =================
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('species_records')
                  .orderBy('observedAt', descending: true)
                  .snapshots(),

              builder: (context, snapshot) {
                // ⏳ Loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // ❌ Error
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Failed to load species records',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                // 📭 Empty
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No species recorded',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                // 🔍 FILTER (CLIENT-SIDE, FAST)
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final sci = (data['scientificName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final com = (data['commonName'] ?? '')
                      .toString()
                      .toLowerCase();

                  if (_query.isEmpty) return true;
                  return sci.contains(_query) || com.contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No matching species found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final category = data['category']?.toString() ?? '—';
                    final isFlora = category == 'Flora';

                    final scientificName =
                        data['scientificName']?.toString() ?? 'Unknown species';

                    final commonName = data['commonName']?.toString();

                    final count = data['count']?.toString() ?? '—';
                    final station = data['station']?.toString() ?? '—';

                    final floraStatus = (data['floraStatus'] is List)
                        ? (data['floraStatus'] as List).join(', ')
                        : null;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,

                      // 👁 VIEW DETAILS
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SpeciesViewPage(docId: doc.id, data: data),
                          ),
                        );

                        if (result == true && mounted) {
                          setState(() {});
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
                            scientificName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                          ),

                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (commonName != null && commonName.isNotEmpty)
                                Text(
                                  commonName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),

                              const SizedBox(height: 2),

                              Text(
                                'Category: $category',
                                style: const TextStyle(height: 1.3),
                              ),

                              Text(
                                'Count: $count  |  Station: $station',
                                style: const TextStyle(height: 1.3),
                              ),

                              if (isFlora && floraStatus != null)
                                Text(
                                  'Flora status: $floraStatus',
                                  style: TextStyle(
                                    height: 1.3,
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
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
          ),
        ],
      ),
    );
  }
}
