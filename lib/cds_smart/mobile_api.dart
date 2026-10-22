import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'mobile_api_origin.dart';

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'cds_smart_mobile_access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _tokenKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _tokenKey);
}

class MobileApiException implements Exception {
  const MobileApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.fieldErrors = const {},
    this.retryAfter,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, List<String>> fieldErrors;
  final Duration? retryAfter;

  @override
  String toString() => message;
}

class SessionExpiredException extends MobileApiException {
  const SessionExpiredException()
    : super('Your session has expired. Please sign in again.', statusCode: 401);
}

class MobileApiClient {
  MobileApiClient({
    required Uri baseUrl,
    required TokenStore tokenStore,
    http.Client? transport,
  }) : _baseUrl = validateMobileApiOrigin(baseUrl, releaseBuild: kReleaseMode),
       _tokenStore = tokenStore,
       _transport = transport ?? http.Client();

  final Uri _baseUrl;
  final TokenStore _tokenStore;
  final http.Client _transport;
  int? _accountId;

  int? get accountId => _accountId;

  static const _attachmentSources = <String, String>{
    'conservation': 'conservation-report',
    'engp': 'engp-report',
    'bms': 'bms-report',
    'bams': 'bams-report',
    'imea': 'imea-report',
    'imea-maintenance': 'imea-maintenance',
    'aws': 'aws',
    'ipaf-management': 'ipaf-management',
    'revenue': 'ipaf-revenue',
    'management-plans': 'management-plan',
  };

  String? attachmentSourceForDocument(String trackingSource) =>
      _attachmentSources[trackingSource];

  Uri _endpoint(String path, [Map<String, String>? query]) => _baseUrl.replace(
    path: '/api/mobile/$path',
    queryParameters: query == null || query.isEmpty ? null : query,
  );

  Future<void> restoreSession() async {
    final token = await _tokenStore.read();
    if (token == null || token.isEmpty) {
      _accountId = null;
      return;
    }
    try {
      final currentUser = await profile();
      _accountId = (currentUser['id'] as num?)?.toInt();
    } on SessionExpiredException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    await clearSession();
    final response = await _send(
      'POST',
      'login',
      body: {'email': email, 'password': password},
      authenticated: false,
      acceptedStatusCodes: const {200, 201},
    );
    final data = _decodeRoot(response);
    final token = data['token'];
    final user = data['user'];
    if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
      throw const MobileApiException(
        'The server returned an invalid login response.',
      );
    }
    await _tokenStore.write(token);
    _accountId = (user['id'] as num?)?.toInt();
    return user;
  }

  Future<Map<String, dynamic>> profile() async {
    final root = _decodeRoot(await _send('GET', 'me'));
    final user = root['user'];
    if (user is! Map<String, dynamic>) {
      throw const MobileApiException('The server returned an invalid response.');
    }
    return user;
  }

  Future<Map<String, dynamic>> dashboard({
    Map<String, String> filters = const {},
  }) async {
    final counts = (await _getData('dashboard', query: filters))['counts'];
    if (counts is! Map<String, dynamic>) {
      throw const MobileApiException(
        'The server returned invalid dashboard counts.',
      );
    }
    return counts;
  }

  Future<PaginatedData<Map<String, dynamic>>> submissions({
    required String queue,
    int page = 1,
    int perPage = 25,
    Map<String, String> filters = const {},
  }) async {
    final data = await _getRoot(
      'GET',
      'submission-tracking/$queue',
      query: {...filters, 'page': '$page', 'per_page': '$perPage'},
    );
    return PaginatedData<Map<String, dynamic>>.fromJson(data);
  }

  Future<Map<String, dynamic>> document(String source, int recordId) =>
      _getData('submission-tracking/documents/$source/$recordId');

  Future<PaginatedData<Map<String, dynamic>>> notifications({
    int page = 1,
    int perPage = 25,
    bool? read,
    String? category,
  }) async {
    final query = <String, String>{'page': '$page', 'per_page': '$perPage'};
    if (read != null) query['read'] = '$read';
    if (category != null && category.isNotEmpty) query['category'] = category;
    return PaginatedData<Map<String, dynamic>>.fromJson(
      await _getRoot('GET', 'notifications', query: query),
    );
  }

  Future<Map<String, dynamic>> setNotificationRead(
    String notificationId,
    bool read,
  ) => _getData(
    'notifications/$notificationId',
    method: 'PATCH',
    body: {'read': read},
  );

  Future<Map<String, dynamic>> attachmentMetadata({
    required String source,
    required int recordId,
    required String attachmentKey,
  }) => _getData('attachments/$source/$recordId/$attachmentKey');

  Future<http.Response> attachmentContent(String contentUrl) async {
    final uri = Uri.parse(contentUrl);
    if (uri.origin != _baseUrl.origin ||
        !uri.path.startsWith('/api/v1/attachments/')) {
      throw const MobileApiException(
        'The server returned an unsafe attachment URL.',
      );
    }
    return _sendRaw('GET', uri, authenticated: true);
  }

  Future<void> logout() async {
    Exception? requestError;
    try {
      await _send('POST', 'logout');
    } on Exception catch (error) {
      requestError = error;
    } finally {
      await clearSession();
    }
    if (requestError != null) throw requestError;
  }

  Future<void> clearSession() async {
    _accountId = null;
    await _tokenStore.delete();
  }

  Future<Map<String, dynamic>> _getData(
    String path, {
    Map<String, String>? query,
    String method = 'GET',
    Object? body,
  }) async => _decodeData(await _send(method, path, query: query, body: body));

  Future<Map<String, dynamic>> _getRoot(
    String method,
    String path, {
    Map<String, String>? query,
  }) async => _decodeRoot(await _send(method, path, query: query));

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
    Set<int> acceptedStatusCodes = const {200},
  }) => _sendRaw(
    method,
    _endpoint(path, query),
    body: body,
    authenticated: authenticated,
    acceptedStatusCodes: acceptedStatusCodes,
  );

  Future<http.Response> _sendRaw(
    String method,
    Uri uri, {
    Object? body,
    bool authenticated = true,
    Set<int> acceptedStatusCodes = const {200},
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (authenticated) {
      final token = await _tokenStore.read();
      if (token == null || token.isEmpty) throw const SessionExpiredException();
      headers['Authorization'] = 'Bearer $token';
    }
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _transport.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401 && authenticated) {
      await clearSession();
      throw const SessionExpiredException();
    }
    if (!acceptedStatusCodes.contains(response.statusCode)) {
      throw _exceptionFromResponse(response);
    }
    return response;
  }

  MobileApiException _exceptionFromResponse(http.Response response) {
    try {
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final error = root['error'] as Map<String, dynamic>? ?? const {};
      final errors = <String, List<String>>{};
      final rawErrors = error['errors'];
      if (rawErrors is Map) {
        for (final entry in rawErrors.entries) {
          if (entry.value is List) {
            errors['${entry.key}'] = (entry.value as List)
                .map((value) => '$value')
                .toList(growable: false);
          }
        }
      }
      final status = response.statusCode;
      final validationDetails = errors.entries
          .expand(
            (entry) => entry.value.map((message) => '${entry.key}: $message'),
          )
          .join('\n');
      final retryAfter = _retryDelay(response.headers['retry-after']);
      final message = switch (status) {
        401 => 'Email or password is incorrect.',
        403 =>
          'This account needs approval, activation, verification, or authorization.',
        404 => 'This resource is unavailable to this account.',
        422 => [
          (error['message'] as String?) ?? 'Please check the entered values.',
          if (validationDetails.isNotEmpty) validationDetails,
        ].join('\n'),
        429 =>
          retryAfter == null
              ? 'Too many attempts. Wait before trying again.'
              : 'Too many attempts. Wait at least ${retryAfter.inSeconds} seconds before trying again.',
        _ => 'The service is temporarily unavailable. Please try again later.',
      };
      return MobileApiException(
        message,
        statusCode: status,
        code: error['code'] as String?,
        fieldErrors: errors,
        retryAfter: retryAfter,
      );
    } on FormatException {
      return MobileApiException(
        'The service is temporarily unavailable. Please try again later.',
        statusCode: response.statusCode,
      );
    } on TypeError {
      return MobileApiException(
        'The service is temporarily unavailable. Please try again later.',
        statusCode: response.statusCode,
      );
    }
  }

  Duration? _retryDelay(String? value) {
    if (value == null || value.isEmpty) return null;
    final seconds = int.tryParse(value);
    if (seconds != null) {
      return seconds < 0 ? null : Duration(seconds: seconds);
    }
    try {
      final retryAt = DateFormat(
        'EEE, dd MMM yyyy HH:mm:ss \'GMT\'',
        'en_US',
      ).parseUtc(value);
      final delay = retryAt.difference(DateTime.now().toUtc());
      return delay.isNegative ? Duration.zero : delay;
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> _decodeData(http.Response response) {
    final root = _decodeRoot(response);
    final data = root['data'];
    if (data is Map<String, dynamic>) return data;
    throw const MobileApiException('The server returned an invalid response.');
  }

  Map<String, dynamic> _decodeRoot(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const MobileApiException(
        'The server returned an invalid response.',
      );
    } on TypeError {
      throw const MobileApiException(
        'The server returned an invalid response.',
      );
    }
  }
}

class PaginatedData<T> {
  const PaginatedData({required this.items, required this.pagination});

  final List<T> items;
  final Map<String, dynamic> pagination;

  int get currentPage => (pagination['current_page'] as num?)?.toInt() ?? 1;
  int get lastPage => (pagination['last_page'] as num?)?.toInt() ?? 1;
  int get total => (pagination['total'] as num?)?.toInt() ?? 0;

  factory PaginatedData.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final pagination = json['meta'];
    if (data is! List ||
        data.any((item) => item is! Map<String, dynamic>) ||
        pagination is! Map<String, dynamic>) {
      throw const MobileApiException(
        'The server returned an invalid pagination response.',
      );
    }
    return PaginatedData<T>(items: data.cast<T>(), pagination: pagination);
  }
}
