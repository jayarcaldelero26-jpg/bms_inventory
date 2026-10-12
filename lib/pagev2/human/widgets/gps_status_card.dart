import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cds_smart_mobile/widgets/glass_card_lite.dart';

class GpsStatusCard extends StatefulWidget {
  final void Function(double lat, double lng)? onLocationReady;

  const GpsStatusCard({
    super.key,
    this.onLocationReady,
  });

  @override
  State<GpsStatusCard> createState() => _GpsStatusCardState();
}

class _GpsStatusCardState extends State<GpsStatusCard> {
  double? latitude;
  double? longitude;

  bool gettingGps = true;
  bool hasGpsFix = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        latitude = pos.latitude;
        longitude = pos.longitude;
        gettingGps = false;
        hasGpsFix = true;
      });

      widget.onLocationReady?.call(latitude!, longitude!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        gettingGps = false;
        hasGpsFix = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCardLite(
      child: Row(
        children: [
          Icon(
            hasGpsFix ? Icons.gps_fixed : Icons.gps_off,
            color: hasGpsFix ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              gettingGps
                  ? 'Acquiring GPS...'
                  : hasGpsFix
                      ? 'GPS: ${latitude!.toStringAsFixed(5)}, '
                        '${longitude!.toStringAsFixed(5)}'
                      : 'GPS not available',
            ),
          ),
        ],
      ),
    );
  }
}
