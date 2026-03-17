import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'legacy/transect_service.dart';

class TransectGuard extends StatelessWidget {
  final Widget child;

  const TransectGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('transects');

    return ValueListenableBuilder(
      valueListenable: box.listenable(keys: ['active_transect_id']),
      builder: (context, _, __) {
        final transect = TransectService();

        if (!transect.hasActiveTransect) {
          return Scaffold(
            backgroundColor: const Color(0xFFF4FBF4),
            appBar: AppBar(
              title: const Text("No Active Transect"),
              backgroundColor: Colors.red.shade700,
              automaticallyImplyLeading: false, // ✅ no back crash
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 80,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "No active transect",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "You must start a transect before recording Species, Threats, or Habitat data.\n\n"
                      "Tap the + button on the map and start a transect.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 30),

                    // ✅ SAFE NAVIGATION
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.map),
                      label: const Text("Go to Map"),
                      onPressed: () {
                        Navigator.pushNamed(context, '/map');
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        } // ✅ ACTIVE TRANSECT → ALLOW PAGE
        return child;
      },
    );
  }
}
