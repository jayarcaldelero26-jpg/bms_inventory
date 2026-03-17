import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'transect/ui/transect_map_page.dart';
import 'pages/data_entry/data_entry_page.dart';
import 'pages/data_entry/summary_page.dart';
import 'transect/ui/transect_control_page.dart';
import 'offline/offline_logs_page.dart';

import 'utils/transect_excel_exporter.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = const [
      TransectMapPage(), // 0 - Map
      HomePage(), // 1 - Data Entry
      OfflineLogsPage(), // 2 - Offline Logs ✅
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],

      // ================= FAB (Speed Dial) =================
      floatingActionButton: SpeedDial(
        heroTag: null, // ✅ MAO NI ANG FIX
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        spacing: 10,
        children: [
          // ▶️ TRANSECT CONTROL
          SpeedDialChild(
            child: const Icon(Icons.route),
            backgroundColor: Colors.green.shade700,
            label: 'Transect',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransectControlPage()),
              );
            },
          ),

          // 📊 SUMMARY
          SpeedDialChild(
            child: const Icon(Icons.dashboard),
            label: 'Summary',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SummaryPage()),
              );
            },
          ),

          // 📤 EXPORT EXCEL (ONLINE TRANSECT ONLY)
          SpeedDialChild(
            child: const Icon(Icons.file_download),
            label: 'Export Excel',
            onTap: () async {
              try {
                final transectBox = Hive.box('transects');

                final transectId =
                    transectBox.get('selected_transect_id') ??
                    transectBox.get('active_transect_id');

                if (transectId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No transect selected')),
                  );
                  return;
                }

                final snap = await FirebaseFirestore.instance
                    .collection('transects')
                    .doc(transectId)
                    .get();

                if (!snap.exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transect not synced online yet.'),
                    ),
                  );
                  return;
                }

                await TransectExcelExporter.exportAndShare(transectId);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Excel exported successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
              }
            },
          ),
        ],
      ),

      // ================= BOTTOM NAV =================
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green.shade800,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.edit_note),
            label: 'Entry',
          ),

          // 🔴 OFFLINE LOGS WITH BADGE
          BottomNavigationBarItem(
            icon: ValueListenableBuilder(
              valueListenable: Hive.box('offline_logs').listenable(),
              builder: (_, Box box, __) {
                final pending = box.values
                    .where(
                      (e) => e['status'] == 'pending' || e['status'] == 'error',
                    )
                    .length;

                return Stack(
                  children: [
                    const Icon(Icons.cloud_off),
                    if (pending > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            pending.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            label: 'Offline',
          ),
        ],
      ),
    );
  }
}
