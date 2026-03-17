import 'package:latlong2/latlong.dart';
import '../kalman_filter_2d.dart';

class KalmanTracker {
  final KalmanFilter2D _kf = KalmanFilter2D(
    processNoise: 0.8,
    measurementNoise: 4,
  );

  void reset(double lat, double lng) => _kf.reset(lat, lng);

  LatLng update({
    required double lat,
    required double lng,
    required double accuracy,
    required double speed,
    required double dt,
  }) {
    _kf.predict(dt.clamp(0.15, 0.6));
    _kf.update(lat, lng, accuracy);

    final alpha = speed > 1.2 ? 0.7 : 0.85;

    return LatLng(
      (_kf.x[0] * alpha) + (lat * (1 - alpha)),
      (_kf.x[1] * alpha) + (lng * (1 - alpha)),
    );
  }
}
