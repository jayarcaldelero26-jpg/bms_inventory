import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:cds_smart_mobile/main_scaffold.dart';
import 'package:cds_smart_mobile/services/species_loader.dart';
import 'package:cds_smart_mobile/services/species_common_service.dart';
import 'package:cds_smart_mobile/services/threat_loader.dart';
import 'package:cds_smart_mobile/services/sync_pull_service.dart';
import 'package:cds_smart_mobile/transect/legacy/transect_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double progress = 0.0;
  String statusText = 'Initializing…';
  bool isOffline = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final start = DateTime.now();
    Object? bootError;

    try {
      // =====================================================
      // 🌐 CONNECTIVITY CHECK
      // =====================================================
      final conn = await Connectivity().checkConnectivity();
      isOffline =
          !(conn.contains(ConnectivityResult.mobile) ||
              conn.contains(ConnectivityResult.wifi));

      final transect = TransectService();

      // =====================================================
      // 🔁 RESTORE ACTIVE TRANSECT FIRST (CRITICAL)
      // =====================================================
      setState(() {
        statusText = 'Restoring active transect…';
        progress = 0.20;
      });
      await transect.restoreActiveTransect();

      // =====================================================
      // 🗺️ LOAD ALL LOCAL TRANSECTS FOR MAP
      // =====================================================
      setState(() {
        statusText = 'Loading local transects…';
        progress = 0.28;
      });
      await transect.restoreAllLocalTransectsForMap();

      // =====================================================
      // 🧹 CLEAN OLD TRANSECTS (SAFE NOW)
      // =====================================================
      setState(() {
        statusText = 'Cleaning old transects…';
        progress = 0.32;
      });
      await transect.autoCleanupOldLocalTransects(maxAgeDays: 14);

      // =====================================================
      // 🌱 SPECIES MASTER
      // =====================================================
      setState(() {
        statusText = 'Loading species data…';
        progress = 0.40;
      });
      await loadSpeciesOnce();

      setState(() {
        statusText = 'Loading common names…';
        progress = 0.48;
      });
      await loadCommonNamesOnce();

      // =====================================================
      // ⚠️ THREATS MASTER
      // =====================================================
      setState(() {
        statusText = 'Loading threat records…';
        progress = 0.56;
      });
      await loadThreatsOnce();

      // =====================================================
      // ☁️ CLOUD SYNC (ONLY IF ONLINE)
      // =====================================================
      if (!isOffline) {
        setState(() {
          statusText = 'Syncing cloud data…';
          progress = 0.70;
        });
        await SyncPullService.pullAll();
      }

      // =====================================================
      // 🗂️ ENSURE HIVE BOXES OPEN
      // =====================================================
      setState(() {
        statusText = 'Preparing maps…';
        progress = 0.85;
      });

      if (!Hive.isBoxOpen('transect_points')) {
        await Hive.openBox('transect_points');
      }
      if (!Hive.isBoxOpen('transects')) {
        await Hive.openBox('transects');
      }

      // =====================================================
      // 🔎 DEBUG (SAFE TO REMOVE LATER)
      // =====================================================
      final tpBox = Hive.box('transect_points');
      debugPrint('📦 TRANSECT POINTS COUNT: ${tpBox.length}');
      for (final v in tpBox.values) {
        debugPrint('🧭 TP: $v');
      }
    } catch (e, stack) {
      bootError = e;
      debugPrint('Splash boot recovered from error: $e');
      debugPrint(stack.toString());
    } finally {
      if (!mounted) return;

      setState(() {
        statusText = bootError == null
            ? 'Almost ready…'
            : 'Continuing with local data…';
        progress = 1.0;
      });

      final elapsed = DateTime.now().difference(start);
      final remaining = const Duration(seconds: 5) - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(_fadeRoute(const MainScaffold()));
    }
  }

  PageRouteBuilder _fadeRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🖼️ BACKGROUND
          Image.asset('assets/images/bms_logo.png', fit: BoxFit.cover),

          // 🌑 DARK OVERLAY
          Container(color: Colors.black.withOpacity(0.45)),

          // 🚶 LOADING UI
          Positioned(
            top: MediaQuery.of(context).size.height * 0.62,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          const SizedBox(height: 28),
                          Positioned(
                            left: (constraints.maxWidth * progress).clamp(
                              0,
                              constraints.maxWidth - 24,
                            ),
                            child: AnimatedPadding(
                              duration: const Duration(milliseconds: 180),
                              padding: EdgeInsets.only(
                                top: progress % 0.2 < 0.1 ? 0 : 3,
                              ),
                              child: const Icon(
                                Icons.directions_walk,
                                color: Colors.greenAccent,
                                size: 26,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 6),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(
                        Colors.greenAccent,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  statusText,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),

                if (isOffline) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Offline mode enabled',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
