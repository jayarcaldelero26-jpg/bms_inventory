import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class FormHelpers {
  static Future<Map<String, double>?> getLocationOnce() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return null;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );

    return {
      'lat': pos.latitude,
      'lng': pos.longitude,
    };
  }

  static Future<File?> capturePhoto(String prefix) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (img == null) return null;

    final dir = Directory('/storage/emulated/0/BMS_Photos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return File(img.path).copy(
      '${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }
}
