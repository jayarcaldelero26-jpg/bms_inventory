import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../utils/map_normalizer.dart';

String cleanScientificName(String name) {
  if (name.isEmpty) return '';
  return name.split(RegExp(r'\s[A-Z].*')).first;
}
Future<Map<String, dynamic>?> showSpeciesSearchModal(
  BuildContext context,
  String category,
) {
  final box = Hive.box('species_master');

  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      // ✅ INITIAL LOAD (NORMALIZED)
      List<Map<String, dynamic>> filtered = box.values
        .whereType<Map>()
        .map((e) => normalizeMap(e))
        .where((s) => s['group'] == category)
        .toList();


      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔍 SEARCH BAR
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search scientific name',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (query) {
                      setModalState(() {
                        filtered = box.values
                          .whereType<Map>()
                          .map((e) => normalizeMap(e))
                          .where((s) => s['group'] == category)
                          .where((s) {
                            final name =
                                (s['scientificName'] ?? '').toString().toLowerCase();
                            return name.contains(query.toLowerCase());
                          })
                          .toList();

                      });
                    },
                  ),
                ),

                // 📃 RESULT LIST
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      final s = filtered[index];

                      return ListTile(
                        title: Text(
                          (s['scientificName'] ?? '').split(',').first,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context, s);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
