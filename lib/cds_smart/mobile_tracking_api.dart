import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:http/http.dart' as http;

import 'mobile_api_origin.dart';
import 'mobile_api.dart' show SecureTokenStore, TokenStore;

class MobileTrackingException implements Exception {
  const MobileTrackingException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class MobileTrackingPage {
  const MobileTrackingPage({required this.items, required this.meta});

  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> meta;

  int get currentPage => (meta['current_page'] as num?)?.toInt() ?? 1;
  int get lastPage => (meta['last_page'] as num?)?.toInt() ?? 1;
  int get total => (meta['total'] as num?)?.toInt() ?? 0;

  factory MobileTrackingPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final meta = json['meta'];
    if (data is! List ||
        data.any((row) => row is! Map<String, dynamic>) ||
        meta is! Map<String, dynamic>) {
      throw const MobileTrackingException(
        'The tracking service returned an invalid response.',
      );
    }
    return MobileTrackingPage(
      items: data.cast<Map<String, dynamic>>(),
      meta: meta,
    );
  }
}

class MobileTrackingApiClient {
  MobileTrackingApiClient({
    required Uri baseUrl,
    TokenStore? tokenStore,
    http.Client? transport,
  }) : _baseUrl = validateMobileApiOrigin(baseUrl, releaseBuild: kReleaseMode),
       _tokenStore = tokenStore ?? SecureTokenStore(),
       _transport = transport ?? http.Client();

  final Uri _baseUrl;
  final TokenStore _tokenStore;
  final http.Client _transport;

  Future<MobileTrackingPage> queue({
    required String queue,
    int page = 1,
    int perPage = 25,
    Map<String, String> filters = const {},
  }) async {
    if (!const {'incoming', 'outgoing', 'history'}.contains(queue)) {
      throw ArgumentError.value(queue, 'queue');
    }
    final query = <String, String>{
      ...filters,
      'page': '$page',
      'per_page': '$perPage',
    };
    final response = await _send(
      _baseUrl.replace(
        path: '/api/mobile/submission-tracking/$queue',
        queryParameters: query,
      ),
    );
    return MobileTrackingPage.fromJson(_decode(response));
  }

  Future<Map<String, dynamic>> document(String source, int sourceId) async {
    if (!RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(source) || sourceId < 1) {
      throw ArgumentError('Invalid document identity.');
    }
    final response = await _send(
      _baseUrl.replace(
        path: '/api/mobile/submission-tracking/documents/$source/$sourceId',
      ),
    );
    final data = _decode(response)['data'];
    if (data is! Map<String, dynamic>) {
      throw const MobileTrackingException(
        'The tracking service returned invalid document details.',
      );
    }
    return data;
  }

  Future<http.Response> _send(Uri uri) async {
    final token = await _tokenStore.read();
    if (token == null || token.isEmpty) {
      throw const MobileTrackingException('Please sign in to continue.');
    }
    final request = http.Request('GET', uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
    final response = await http.Response.fromStream(
      await _transport.send(request),
    );
    if (response.statusCode == 401) {
      await _tokenStore.delete();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = switch (response.statusCode) {
        401 => 'Your session has expired. Please sign in again.',
        403 => 'Tracking is not available for this account.',
        404 => 'This record is unavailable to this account.',
        _ =>
          'Submission tracking is temporarily unavailable. Please try again.',
      };
      throw MobileTrackingException(message, statusCode: response.statusCode);
    }
    return response;
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) return json;
    } on FormatException {
      // Use one stable error for non-JSON responses.
    }
    throw const MobileTrackingException(
      'The tracking service returned an invalid response.',
    );
  }
}
