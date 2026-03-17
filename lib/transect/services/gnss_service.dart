import 'package:flutter/services.dart';

class GnssService {
  static const _channel = EventChannel('bms/gnss');

  Stream<Map<String, dynamic>> stream() {
    return _channel.receiveBroadcastStream().map(
      (e) => Map<String, dynamic>.from(e),
    );
  }
}
