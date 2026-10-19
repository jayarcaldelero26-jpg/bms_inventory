import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:http/http.dart' as http;

import 'mobile_api_origin.dart';
import 'mobile_api.dart' show SecureTokenStore, TokenStore;

class MobileAuthException implements Exception {
  const MobileAuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class MobileAuthApiClient {
  MobileAuthApiClient({
    required Uri baseUrl,
    TokenStore? tokenStore,
    http.Client? transport,
  }) : _baseUrl = validateMobileApiOrigin(baseUrl, releaseBuild: kReleaseMode),
       _tokenStore = tokenStore ?? SecureTokenStore(),
       _transport = transport ?? http.Client();

  final Uri _baseUrl;
  final TokenStore _tokenStore;
  final http.Client _transport;

  Uri get _authEndpoint => _baseUrl.replace(path: '/api/mobile');

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    await _tokenStore.delete();
    final response = await _send(
      'POST',
      'login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    final root = _decode(response);
    final token = root['token'];
    final user = root['user'];
    if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
      throw const MobileAuthException(
        'The sign-in service returned an invalid response.',
      );
    }
    await _tokenStore.write(token);
    return user;
  }

  Future<Map<String, dynamic>> profile() async {
    final response = await _send('GET', 'me');
    final user = _decode(response)['user'];
    if (user is! Map<String, dynamic>) {
      throw const MobileAuthException(
        'The profile service returned an invalid response.',
      );
    }
    return user;
  }

  Future<void> logout() async {
    Object? requestError;
    try {
      await _send('POST', 'logout');
    } on Object catch (error) {
      requestError = error;
    } finally {
      await _tokenStore.delete();
    }
    if (requestError != null) throw requestError;
  }

  Future<void> clearSession() => _tokenStore.delete();

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (authenticated) {
      final token = await _tokenStore.read();
      if (token == null || token.isEmpty) {
        throw const MobileAuthException('Please sign in to continue.');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    final request = http.Request(
      method,
      _authEndpoint.replace(path: '${_authEndpoint.path}/$path'),
    )..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _transport.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 401 && authenticated) {
      await _tokenStore.delete();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _exceptionFromResponse(response);
    }
    return response;
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Return a consistent response error below.
    }
    throw const MobileAuthException(
      'The sign-in service returned an invalid response.',
    );
  }

  MobileAuthException _exceptionFromResponse(http.Response response) {
    var message = switch (response.statusCode) {
      401 || 422 => 'Email or password is incorrect.',
      403 => 'This account is inactive and cannot sign in.',
      _ => 'The sign-in service is unavailable. Please try again later.',
    };
    try {
      final root = jsonDecode(response.body);
      if (root is Map<String, dynamic>) {
        final errors = root['errors'];
        if (response.statusCode == 422 && errors is Map) {
          final emailErrors = errors['email'];
          if (emailErrors is List && emailErrors.isNotEmpty) {
            message = '${emailErrors.first}';
            if (message.toLowerCase().contains('provided credentials')) {
              message = 'Email or password is incorrect.';
            }
          }
        }
      }
    } on FormatException {
      // Keep the status-based message for a non-JSON error response.
    }
    return MobileAuthException(message, statusCode: response.statusCode);
  }
}
