import 'package:flutter/material.dart';

class MapLegend extends StatelessWidget {
  final bool hasThreats;
  final bool hasSpecies;
  final bool hasTransects;

  /// e.g. ['Low', 'Medium', 'High', 'Critical']
  final List<String> threatSeverities;

  /// severity → color
  final Color Function(String severity) severityColor;

  const MapLegend({
    super.key,
    required this.hasThreats,
    required this.hasSpecies,
    required this.hasTransects,
    required this.threatSeverities,
    required this.severityColor,
  });

  Widget _row({
    required Color color,
    required String label,
    bool isLine = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isLine
              ? Container(
                  width: 26,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleSeverities = threatSeverities.toSet().toList()
      ..sort((a, b) {
        const order = ['Low', 'Medium', 'High', 'Critical'];
        return order.indexOf(a).compareTo(order.indexOf(b));
      });

    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('LEGEND', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            // ================= TRANSECTS =================
            if (hasTransects) ...[
              _row(
                color: const Color(0xFF1565C0),
                label: 'Selected Transect',
                isLine: true,
              ),
              _row(
                color: Colors.greenAccent,
                label: 'Finished Transects',
                isLine: true,
              ),
            ],

            if (hasTransects && (hasSpecies || hasThreats))
              const Divider(height: 12),

            // ================= SPECIES =================
            if (hasSpecies)
              _row(color: Colors.orange, label: 'Species Observation'),

            if (hasSpecies && hasThreats) const Divider(height: 12),

            // ================= THREAT SEVERITY =================
            // ================= THREATS =================
            if (hasThreats) ...[
              const Text(
                'THREATS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),

              for (final s in visibleSeverities)
                _row(color: severityColor(s), label: s),
            ],
          ],
        ),
      ),
    );
  }
}
