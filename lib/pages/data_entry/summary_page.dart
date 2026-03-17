import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../list/species_list_page.dart';
import '../list/habitat_list_page.dart';
import '../list/threat_list_page.dart';
import '../list/human_activity_list_page.dart';
import '../../transect/ui/transect_list_page.dart';
import '../../transect/legacy/transect_service.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  final TransectService _transect = TransectService();

  Future<void> _manualRefresh() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final bool hasTransect = _transect.hasActiveTransect;

    return Scaffold(
      backgroundColor: const Color(0xFFE3F2E6),
      appBar: AppBar(
        title: Text(hasTransect ? 'Transect Summary' : 'Biodiversity Summary'),
        backgroundColor: const Color(0xFF2E7D32),
      ),

      /// 🔽 Pull-to-refresh
      body: RefreshIndicator(
        onRefresh: _manualRefresh,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    // 🔽 EXISTING SUMMARY CARDS (NO CHANGE)
                    _glassSummaryCard(
                      context: context,
                      icon: Icons.pets,
                      iconColor: Colors.green.shade700,
                      label: 'Species Records',
                      collection: 'species_records',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SpeciesListPage(),
                        ),
                      ),
                    ),
                    _glassSummaryCard(
                      context: context,
                      icon: Icons.warning,
                      iconColor: Colors.red.shade700,
                      label: 'Threats',
                      collection: 'threat_records',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ThreatListPage(),
                        ),
                      ),
                    ),
                    _glassSummaryCard(
                      context: context,
                      icon: Icons.groups,
                      iconColor: Colors.orange.shade800,
                      label: 'Human Activity',
                      collection: 'human_activity_records',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HumanActivityListPage(),
                        ),
                      ),
                    ),
                    _glassSummaryCard(
                      context: context,
                      icon: Icons.terrain,
                      iconColor: Colors.brown.shade700,
                      label: 'Habitat Records',
                      collection: 'habitat_records',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HabitatListPage(),
                        ),
                      ),
                    ),
                    _glassSummaryCard(
                      context: context,
                      icon: Icons.route,
                      iconColor: Colors.green.shade700,
                      label: 'Transects',
                      collection: 'transects',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TransectListPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ================= GLASS SUMMARY CARD =================
  Widget _glassSummaryCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String collection,
    required VoidCallback onTap,
  }) {
    final String? transectId = _transect.activeTransectId;
    final bool hasTransect = transectId != null;

    final Query query = hasTransect
        ? FirebaseFirestore.instance
              .collection(collection)
              .where('transectId', isEqualTo: transectId)
        : FirebaseFirestore.instance.collection(collection);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F3).withOpacity(0.35),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withOpacity(0.35),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(height: 16),

                /// 🔥 AUTO-REFRESH COUNT (FILTERED BY TRANSECT IF ACTIVE)
                StreamBuilder<QuerySnapshot>(
                  stream: query.snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;

                    return Text(
                      count.toString(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 6),

                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
