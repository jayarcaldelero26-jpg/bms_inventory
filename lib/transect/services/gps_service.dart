import 'package:geolocator/geolocator.dart';

class GpsService {
  Stream<Position> stream({bool highAccuracy = true}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: highAccuracy
            ? LocationAccuracy.bestForNavigation
            : LocationAccuracy.best,
        distanceFilter: 1,
      ),
    );
  }
}
