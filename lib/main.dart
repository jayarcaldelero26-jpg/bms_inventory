import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

// UI
import 'splash/splash_screen.dart';
import 'pages/data_entry/data_entry_page.dart';
import 'pages/data_entry/species_input_page.dart';
import 'pages/data_entry/habitat_input_page.dart';
import 'pages/data_entry/threat_monitoring_page.dart';
import 'pages/data_entry/human_activity_input_page.dart';

// Transect
import 'transect/transect_guard.dart';
import 'transect/ui/transect_summary_page.dart';
import 'transect/ui/transect_map_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Offline
import 'offline/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 SAFE FIREBASE INIT (NO DUPLICATE, NO CRASH)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  // 🧠 OFFLINE CORE (DO NOT TOUCH)
  await Hive.initFlutter();
  await Hive.openBox('species');
  await Hive.openBox('species_master');
  await Hive.openBox('species_common');
  await Hive.openBox('species_points');
  await Hive.openBox('transects');
  await Hive.openBox('transect_points');
  await Hive.openBox('offline_logs');
  await Hive.openBox('threats');
  await Hive.openBox('ui_state');

  // 🗺️ FMTC (OFFLINE MAPS)
  await FMTCObjectBoxBackend().initialise();
  await FMTCStore('bms_offline_map').manage.create();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();

    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      if (_syncing) return;

      if (results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi)) {
        _syncing = true;
        try {
          await SyncService.sync();
        } catch (_) {}
        _syncing = false;
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/map': (_) => TransectMapPage(),
        '/entry': (_) => const HomePage(),
        '/species': (_) => const TransectGuard(child: SpeciesInputPage()),
        '/habitat': (_) => const HabitatInputPage(),
        '/threat': (_) => const TransectGuard(child: ThreatInputPage()),
        '/human': (_) => const HumanActivityInputPage(),
        '/transect-summary': (_) => TransectSummaryPage(),
      },
    );
  }
}
