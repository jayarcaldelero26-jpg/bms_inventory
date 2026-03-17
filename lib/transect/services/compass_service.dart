import 'package:flutter_compass/flutter_compass.dart';

class CompassService {
  Stream<double> stream() {
    return FlutterCompass.events!
        .where((e) => e.heading != null)
        .map((e) => e.heading!.clamp(0, 360));
  }
}
