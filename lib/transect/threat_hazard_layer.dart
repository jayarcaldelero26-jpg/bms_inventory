import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThreatHazardLayer {
  static const double hazardRadiusMeters = 60;
  static const double dotSize = 12;

  // ================= COLOR BY SEVERITY (SOURCE OF TRUTH) =================
  static Color severityColor(String severity) {
    switch (severity) {
      case 'Low':
        return Colors.green; // ✅ LOW
      case 'Medium':
        return Colors.orange; // ✅ MEDIUM
      case 'High':
        return Colors.redAccent; // ✅ HIGH
      case 'Critical':
        return Colors.red.shade900; // ✅ CRITICAL
      default:
        return Colors.grey;
    }
  }

  static double _radiusBySeverity(String severity) {
    switch (severity) {
      case 'Low':
        return 40;
      case 'Medium':
        return 60;
      case 'High':
        return 90;
      case 'Critical':
        return 120;
      default:
        return 60;
    }
  }

  // ================= HAZARD CIRCLE =================
  static CircleLayer circleLayer(List<Map<String, dynamic>> threats) {
    return CircleLayer(
      circles: threats
          .where((t) => t['latitude'] != null && t['longitude'] != null)
          .map((t) {
            final color = severityColor(t['threatSeverity'] ?? '');

            return CircleMarker(
              point: LatLng(t['latitude'], t['longitude']),
              radius: _radiusBySeverity(t['threatSeverity'] ?? ''),
              useRadiusInMeter: true,
              color: color.withOpacity(0.25),
              borderStrokeWidth: 1.2,
              borderColor: color.withOpacity(0.6),
            );
          })
          .toList(),
    );
  }

  // ================= CENTER DOT =================
  static MarkerLayer markerLayer(
    List<Map<String, dynamic>> threats,
    void Function(String threatId) onTap,
  ) {
    return MarkerLayer(
      markers: threats
          .map((t) {
            final id = t['id'] ?? t['localId'] ?? t['threatId'];
            final lat = t['latitude'];
            final lng = t['longitude'];

            if (id == null || lat == null || lng == null) return null;

            return Marker(
              point: LatLng(lat, lng),
              width: 44, // 👈 mas dako
              height: 44,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque, // ⭐ IMPORTANT
                onTap: () {
                  Hive.box('threats').put('selected_threat_id', id);
                  onTap(id);
                },
                child: const Icon(
                  Icons.warning,
                  color: Colors.transparent, // invisible tap target
                ),
              ),
            );
          })
          .whereType<Marker>()
          .toList(),
    );
  }

  static MarkerLayer dotLayer(List<Map<String, dynamic>> threats) {
    return MarkerLayer(
      markers: threats
          .where((t) => t['latitude'] != null && t['longitude'] != null)
          .map((t) {
            final color = severityColor(t['threatSeverity'] ?? '');

            return Marker(
              point: LatLng(t['latitude'], t['longitude']),
              width: dotSize,
              height: dotSize,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            );
          })
          .toList(),
    );
  }

  static MarkerLayer tapAreaLayer(
    List<Map<String, dynamic>> threats,
    void Function(String threatId) onTap,
  ) {
    const double tapSize = 80; // 👈 PIXELS (pwede 60–100)

    return MarkerLayer(
      markers: threats
          .where((t) => t['latitude'] != null && t['longitude'] != null)
          .map((t) {
            final id = t['id'] ?? t['threatId'];
            if (id == null) return null;

            return Marker(
              point: LatLng(t['latitude'], t['longitude']),
              width: tapSize,
              height: tapSize,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(id),
                child: const SizedBox.expand(), // 👈 full clickable area
              ),
            );
          })
          .whereType<Marker>()
          .toList(),
    );
  }
}
