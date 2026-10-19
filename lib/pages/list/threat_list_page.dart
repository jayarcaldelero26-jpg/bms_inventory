import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/record_card.dart';
import 'package:cds_smart_mobile/pagev2/view/threat_view_page.dart';

class ThreatListPage extends StatefulWidget {
  const ThreatListPage({super.key});

  @override
  State<ThreatListPage> createState() => _ThreatListPageState();
}

class _ThreatListPageState extends State<ThreatListPage> {
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
        title: const Text('Threat Records'),
        backgroundColor: Colors.red,
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
                hintText: 'Search threat type, station, condition...',
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
                  .collection('threat_records')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),

              builder: (context, snapshot) {
                // ⏳ LOADING
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // ❌ ERROR
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading threat records'),
                  );
                }

                // 📭 EMPTY
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No threat records found'));
                }

                final docs = snapshot.data!.docs;

                // 🔍 FILTER (CLIENT-SIDE)
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final threatType = (data['threatType'] ?? '')
                      .toString()
                      .toLowerCase();
                  final condition = (data['conditionOfEvidence'] ?? '')
                      .toString()
                      .toLowerCase();
                  final station = (data['station'] ?? '')
                      .toString()
                      .toLowerCase();
                  final severity = (data['threatSeverity'] ?? '')
                      .toString()
                      .toLowerCase();

                  if (_query.isEmpty) return true;

                  return threatType.contains(_query) ||
                      condition.contains(_query) ||
                      station.contains(_query) ||
                      severity.contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No matching threat found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final data = doc.data() as Map<String, dynamic>;

                    final severity = data['threatSeverity'];

                    final Color iconColor =
                        {
                          'Low': Colors.green,
                          'Medium': Colors.orange,
                          'High': Colors.red,
                          'Critical': Colors.black,
                        }[severity] ??
                        Colors.red;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,

                      /// 👁 VIEW DETAILS
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ThreatViewPage(docId: doc.id, data: data),
                          ),
                        );
                      },

                      child: RecordCard(
                        icon: Icons.warning,
                        iconColor: iconColor,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['threatType'] ?? 'Unknown Threat',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Condition: ${data['conditionOfEvidence'] ?? '-'}',
                            ),
                            const SizedBox(height: 4),
                            Text('Station: ${data['station'] ?? '-'}'),
                            if (severity != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Severity: $severity',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: iconColor,
                                ),
                              ),
                            ],
                          ],
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
