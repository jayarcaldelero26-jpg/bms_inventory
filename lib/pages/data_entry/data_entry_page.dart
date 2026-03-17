import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../offline/sync_service.dart';

//////////////////////////////////////////////////////////////
///                DATA ENTRY PAGE                         ///
//////////////////////////////////////////////////////////////

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isOnline = false;
  bool isSyncing = false;
  DateTime? lastSyncTime;

  late Box offlineBox;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  @override
  void initState() {
    super.initState();
    offlineBox = Hive.box('offline_logs');

    Connectivity().checkConnectivity().then(_updateConnection);
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _updateConnection,
    );
  }

  void _updateConnection(List<ConnectivityResult> results) {
    if (!mounted) return;

    final online = !results.contains(ConnectivityResult.none);

    setState(() => isOnline = online);

    if (online && pendingCount > 0 && !isSyncing) {
      _manualSync();
    }
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    super.dispose();
  }

  int get pendingCount {
    return offlineBox.values
        .where(
          (e) =>
              e is Map && (e['status'] == 'pending' || e['status'] == 'error'),
        )
        .length;
  }

  Future<void> _manualSync() async {
    if (!isOnline || pendingCount == 0 || isSyncing) return;

    setState(() => isSyncing = true);

    try {
      await SyncService.sync();
      lastSyncTime = DateTime.now();
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      if (mounted) setState(() => isSyncing = false);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6EC),

      // ================= HEADER =================
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 38, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade900.withOpacity(0.55),
                    Colors.green.shade700.withOpacity(0.25),
                    Colors.white.withOpacity(0.15),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Image.asset('assets/denr_logo.png', height: 55),
                  const SizedBox(width: 22),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Biodiversity Monitoring System',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mount Hamiguitan Range Wildlife Sanctuary',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // ================= BODY =================
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                if (!isOnline) return;
                await _manualSync();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
                children: [
                  WideCard(
                    image: 'assets/species.png',
                    title: 'Species\nObservation',
                    onTap: () => Navigator.pushNamed(context, '/species'),
                  ),
                  const SizedBox(height: 14),
                  WideCard(
                    image: 'assets/habitat.png',
                    title: 'Habitat\nAssessment',
                    onTap: () => Navigator.pushNamed(context, '/habitat'),
                  ),
                  const SizedBox(height: 14),
                  WideCard(
                    image: 'assets/threat.png',
                    title: 'Threat\nMonitoring',
                    onTap: () => Navigator.pushNamed(context, '/threat'),
                  ),
                  const SizedBox(height: 14),
                  WideCard(
                    image: 'assets/human.png',
                    title: 'Human\nActivity',
                    onTap: () => Navigator.pushNamed(context, '/human'),
                  ),
                ],
              ),
            ),

            // 🔥 SYNC STATUS
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: ValueListenableBuilder(
                valueListenable: offlineBox.listenable(),
                builder: (_, __, ___) {
                  return SyncStatusPill(
                    isOnline: isOnline,
                    pendingCount: pendingCount,
                    isSyncing: isSyncing,
                    lastSyncTime: lastSyncTime,
                    onSync: _manualSync,
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // ================= SPEED DIAL =================
    );
  }
}

//////////////////////////////////////////////////////////////
///              SYNC STATUS PILL                          ///
//////////////////////////////////////////////////////////////

class SyncStatusPill extends StatelessWidget {
  final bool isOnline;
  final int pendingCount;
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final VoidCallback onSync;

  const SyncStatusPill({
    super.key,
    required this.isOnline,
    required this.pendingCount,
    required this.isSyncing,
    required this.onSync,
    this.lastSyncTime,
  });

  String _relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} hr ago';
    return '${d.inDays} day ago';
  }

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    if (!isOnline) {
      color = Colors.grey.shade700;
      text = 'Offline';
    } else if (pendingCount == 0) {
      color = Colors.green.shade700;
      text = lastSyncTime == null
          ? 'All synced'
          : 'All synced • ${_relative(lastSyncTime!)}';
    } else {
      color = Colors.orange.shade700;
      text = '$pendingCount pending';
    }

    return GestureDetector(
      onTap: isOnline && pendingCount > 0 && !isSyncing ? onSync : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
///                WIDE CARD                              ///
//////////////////////////////////////////////////////////////

class WideCard extends StatelessWidget {
  final String image;
  final String title;
  final VoidCallback onTap;

  const WideCard({
    super.key,
    required this.image,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.7,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(image, fit: BoxFit.cover),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.55),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
