import 'package:connectivity_plus/connectivity_plus.dart';
import '../offline/sync_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ConnectivityService {
  static bool _wasOffline = true;
  static bool _syncing = false;

  static void listen() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      final isOnline = !results.contains(ConnectivityResult.none);

      // only trigger on OFFLINE → ONLINE
      if (isOnline && _wasOffline && !_syncing) {
        final box = Hive.box('offline_logs');

        final hasPending = box.values.any(
          (e) => e is Map && e['status'] == 'pending',
        );

        if (!hasPending) {
          _wasOffline = false;
          return;
        }

        _syncing = true;

        try {
          await SyncService.sync(fromAuto: true);
        } finally {
          _syncing = false;
          _wasOffline = false;
        }
      }

      if (!isOnline) {
        _wasOffline = true;
      }
    });
  }
}
