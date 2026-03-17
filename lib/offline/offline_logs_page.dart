import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../offline/sync_service.dart';

class OfflineLogsPage extends StatelessWidget {
  const OfflineLogsPage({super.key});

  // ================= STATUS ICON =================
  Widget _leading(Map log) {
    if (log['syncing'] == true) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    switch (log['status']) {
      case 'pending':
        return const Icon(Icons.schedule, color: Colors.orange);
      case 'error':
        return const Icon(Icons.error, color: Colors.red);
      case 'synced':
        return const Icon(Icons.check_circle, color: Colors.green);
      default:
        return const Icon(Icons.help, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('offline_logs');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Queue'),
        backgroundColor: Colors.green.shade700,

        // ================= ACTIONS =================
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Manual Sync',
            onPressed: () async {
              await SyncService.sync();
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Sync finished')));
            },
          ),
        ],
      ),

      // ================= BODY =================
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box box, _) {
          final logs = box.values
              .where(
                (e) =>
                    e is Map &&
                    (e['status'] == 'pending' || e['status'] == 'error'),
              )
              .cast<Map>()
              .toList();

          if (logs.isEmpty) {
            return const Center(
              child: Text(
                'All records are synced 🎉',
                style: TextStyle(color: Colors.black54),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Pending records will sync automatically when online.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),

              ...logs.map((log) {
                final data = log['data'] as Map?;
                final localPhotos =
                    (data?['localPhotoPaths'] as List?)?.length ?? 0;
                final cloudPhotos = (data?['photoUrls'] as List?)?.length ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: _leading(log),
                    title: Text(
                      log['type'].toString().toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status: ${log['status']}'),
                        Text(
                          'Local ID: ${log['localId']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '📸 Local photos: $localPhotos',
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          '☁️ Cloud photos: $cloudPhotos',
                          style: const TextStyle(fontSize: 11),
                        ),
                        if (log['error'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '❌ Error: ${log['error']}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
