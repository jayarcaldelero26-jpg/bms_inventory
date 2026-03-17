import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SpeciesDetailsCard extends StatelessWidget {
  final VoidCallback onClose;
  const SpeciesDetailsCard({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final speciesBox = Hive.box('species');
    final pointsBox = Hive.box('species_points');

    final selectedId = speciesBox.get('selected_species_id');
    if (selectedId == null) return const SizedBox();

    final s = speciesBox.get(selectedId);
    if (s is! Map) return const SizedBox();

    final List photos =
        (s['photoUrls'] as List?) ?? (s['localPhotoPaths'] as List?) ?? [];

    return Card(
      elevation: 14,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HEADER =================
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['commonName'] ?? 'Unknown Species',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (s['scientificName'] != null)
                        Text(
                          s['scientificName'],
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),

                // 🗑 DELETE
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete species',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete Species'),
                        content: const Text(
                          'This will permanently delete this species record.\n\n'
                          'This action cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true) return;

                    // ================= FIRESTORE =================
                    try {
                      await FirebaseFirestore.instance
                          .collection('species_records')
                          .doc(selectedId)
                          .delete();
                    } catch (_) {
                      // ignore if already deleted / offline
                    }

                    // ================= HIVE: SPECIES =================
                    await speciesBox.delete(selectedId);

                    // ================= HIVE: MAP POINTS =================
                    final toDelete = pointsBox.keys.where((k) {
                      final v = pointsBox.get(k);
                      return v is Map &&
                          (v['speciesId'] == selectedId ||
                              v['id'] == selectedId);
                    }).toList();

                    for (final k in toDelete) {
                      await pointsBox.delete(k);
                    }

                    // ================= UI STATE =================
                    speciesBox.delete('selected_species_id');

                    // close card
                    onClose();
                  },
                ),

                // ❌ CLOSE
                IconButton(icon: const Icon(Icons.close), onPressed: onClose),
              ],
            ),

            if (photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final p = photos[i].toString();
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: p.startsWith('http')
                          ? Image.network(
                              p,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(p),
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 12),

            Row(
              children: [
                _chip(Icons.eco, s['category'] ?? '—'),
                const SizedBox(width: 8),

                if (s['habitatType'] != null &&
                    s['habitatType'].toString().trim().isNotEmpty)
                  _chip(Icons.terrain, s['habitatType']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Chip(avatar: Icon(icon, size: 16), label: Text(label));
  }
}
