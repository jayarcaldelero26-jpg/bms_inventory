import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String _cloudName = 'dbcxpmql0';
  static const String _uploadPreset = 'bms_photo';

  static Future<String?> uploadImage({
    required File imageFile,
    required String folder,
    required String publicId,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    // 🔒 SAFETY: file must exist
    if (!imageFile.existsSync()) {
      return null;
    }

    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = folder
        // 🔑 IMPORTANT: unique + deterministic publicId
        // prevents overwrite on retry
        ..fields['public_id'] = publicId
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            imageFile.path,
            filename: imageFile.uri.pathSegments.last,
          ),
        );

      final streamed = await request.send().timeout(timeout);
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        return null;
      }

      final decoded = json.decode(body);

      // 🔐 STRICT VALIDATION
      if (decoded is! Map) return null;
      if (!decoded.containsKey('secure_url')) return null;

      final url = decoded['secure_url'];

      if (url is String && url.startsWith('https://')) {
        return url; // ✅ CONFIRMED UPLOAD
      }

      return null;
    } catch (_) {
      // ❌ silent fail → SyncService will retry later
      return null;
    }
  }
}
