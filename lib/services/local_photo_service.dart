import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 📸 LOCAL PHOTO SERVICE (OFFLINE-FIRST)
///
/// - Captures photo using camera
/// - Saves to app-owned storage
/// - Organized by type (species / threat / habitat / human)
/// - Safe for offline use and recovery
/// - NO upload / NO cloud dependency
class LocalPhotoService {
  static Future<String?> captureAndSave({
    required String prefix, // species | threat | habitat | human
  }) async {
    try {
      // 📷 Capture photo
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1024,
      );

      if (image == null) return null;

      final tempFile = File(image.path);

      // 📂 App-owned directory
      final baseDir = await getApplicationDocumentsDirectory();
      final photoDir = Directory('${baseDir.path}/photos/$prefix');

      // ensure folder exists
      if (!photoDir.existsSync()) {
        photoDir.createSync(recursive: true);
      }

      // 🏷️ Unique filename
      final fileName =
          '${prefix}_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';

      // 💾 Save permanent local copy
      final savedFile = await tempFile.copy('${photoDir.path}/$fileName');

      return savedFile.path; // ✅ LOCAL FILE PATH
    } catch (e) {
      // fail silently — NEVER crash field app
      return null;
    }
  }
}
