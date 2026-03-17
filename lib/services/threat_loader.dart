import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

Future<void> loadThreatsOnce() async {
  final threatsBox = Hive.box('threats');
  final offlineBox = Hive.box('offline_logs');

  // 🧠 STEP 1: restore from OFFLINE LOGS
  for (final v in offlineBox.values.whereType<Map>()) {
    if (v['type'] != 'threat') continue;

    final data = Map<String, dynamic>.from(v['data'] ?? {});
    final id = data['id'] ?? v['localId'];

    if (id == null) continue;

    if (!threatsBox.containsKey(id)) {
      threatsBox.put(id, {...data, 'id': id});
    }
  }

  // 🌐 STEP 2: kung ONLINE, load from FIRESTORE
  final conn = await Connectivity().checkConnectivity();
  final isOnline =
      conn.contains(ConnectivityResult.mobile) ||
      conn.contains(ConnectivityResult.wifi);

  if (!isOnline) return;

  final snap = await FirebaseFirestore.instance
      .collection('threat_records')
      .get();

  for (final d in snap.docs) {
    final data = d.data();

    if (data['latitude'] == null || data['longitude'] == null) continue;

    final id = d.id;

    if (!threatsBox.containsKey(id)) {
      threatsBox.put(id, {...data, 'id': id});
    }
  }
}
