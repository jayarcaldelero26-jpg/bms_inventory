import 'dart:convert';

import 'package:cds_smart_mobile/cds_smart/mobile_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryTokenStore implements TokenStore {
  String? token;

  @override
  Future<void> delete() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}

http.Response jsonResponse(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: const {'content-type': 'application/json'},
);

MobileApiClient createClient({
  required MemoryTokenStore store,
  required Future<http.Response> Function(http.Request request) handler,
}) => MobileApiClient(
  baseUrl: Uri.parse('https://cds.example.test'),
  tokenStore: store,
  transport: MockClient(handler),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    '401 clears the secure token and ends a revoked restored session',
    () async {
      final store = MemoryTokenStore()..token = 'revoked-token';
      final client = createClient(
        store: store,
        handler: (_) async => jsonResponse({
          'error': {'code': 'unauthorized', 'message': 'Unauthorized'},
        }, status: 401),
      );

      await expectLater(
        client.restoreSession(),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(store.token, isNull);
      expect(client.accountId, isNull);
    },
  );

  test(
    'sign out clears local credentials even when token was revoked',
    () async {
      final store = MemoryTokenStore()..token = 'revoked-token';
      var requestCount = 0;
      final client = createClient(
        store: store,
        handler: (request) async {
          requestCount++;
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/v1/auth/token');
          expect(request.headers['authorization'], 'Bearer revoked-token');
          return jsonResponse({
            'error': {'code': 'unauthorized', 'message': 'Unauthorized'},
          }, status: 401);
        },
      );

      await expectLater(
        client.logout(),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(requestCount, 1);
      expect(store.token, isNull);
    },
  );

  test(
    'submission pagination forwards filters and preserves empty out-of-range result',
    () async {
      final store = MemoryTokenStore()..token = 'account-token';
      final client = createClient(
        store: store,
        handler: (request) async {
          expect(request.url.path, '/api/v1/submissions/history');
          expect(request.url.queryParameters, {
            'page': '8',
            'per_page': '20',
            'reporting_year': '2026',
            'target_office': 'CENRO Baganga',
          });
          expect(request.headers['accept'], 'application/json');
          expect(request.headers['authorization'], 'Bearer account-token');
          return jsonResponse({
            'data': <Object>[],
            'pagination': {
              'current_page': 8,
              'per_page': 20,
              'total': 0,
              'last_page': 1,
              'from': null,
              'to': null,
              'has_more': false,
            },
          });
        },
      );

      final result = await client.submissions(
        queue: 'history',
        page: 8,
        perPage: 20,
        filters: {'reporting_year': '2026', 'target_office': 'CENRO Baganga'},
      );
      expect(result.items, isEmpty);
      expect(result.currentPage, 8);
      expect(result.lastPage, 1);
      expect(result.total, 0);
      expect(result.pagination['from'], isNull);
      expect(result.pagination['to'], isNull);
    },
  );

  test(
    'dashboard, document, and user notification routes follow v1 shapes',
    () async {
      final store = MemoryTokenStore()..token = 'account-token';
      final client = createClient(
        store: store,
        handler: (request) async {
          expect(request.headers['accept'], 'application/json');
          if (request.url.path == '/api/v1/dashboard') {
            expect(request.url.queryParameters['status'], 'Pending CENRO');
            return jsonResponse({
              'data': {
                'counts': {'incoming': 2, 'outgoing': 1, 'history': 0},
              },
            });
          }
          if (request.url.path == '/api/v1/documents/bms/501') {
            return jsonResponse({
              'data': {
                'source': 'bms',
                'source_record_id': 501,
                'routing_events': <Object>[],
                'review_events': <Object>[],
                'read_only': true,
              },
            });
          }
          if (request.url.path == '/api/v1/notifications' &&
              request.method == 'GET') {
            expect(request.url.queryParameters, {
              'page': '2',
              'per_page': '25',
              'read': 'false',
              'category': 'submission_updates',
            });
            return jsonResponse({
              'data': <Object>[],
              'pagination': {
                'current_page': 2,
                'per_page': 25,
                'total': 0,
                'last_page': 1,
                'from': null,
                'to': null,
                'has_more': false,
              },
            });
          }
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/v1/notifications/notification-1');
          expect(request.headers['content-type'], 'application/json');
          expect(jsonDecode(request.body), {'read': true});
          return jsonResponse({
            'data': {'id': 'notification-1', 'read_at': '2026-10-12T09:00:00Z'},
          });
        },
      );

      expect(await client.dashboard(filters: {'status': 'Pending CENRO'}), {
        'incoming': 2,
        'outgoing': 1,
        'history': 0,
      });
      final document = await client.document('bms', 501);
      expect(document['source_record_id'], 501);
      expect(document['read_only'], isTrue);
      final notifications = await client.notifications(
        page: 2,
        read: false,
        category: 'submission_updates',
      );
      expect(notifications.items, isEmpty);
      final updated = await client.setNotificationRead('notification-1', true);
      expect(updated['read_at'], '2026-10-12T09:00:00Z');
    },
  );

  test(
    'switching accounts replaces the prior token and account identity',
    () async {
      final store = MemoryTokenStore()..token = 'old-account-token';
      final observedAuthorization = <String?>[];
      final client = createClient(
        store: store,
        handler: (request) async {
          observedAuthorization.add(request.headers['authorization']);
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/auth/login');
          expect(request.headers['content-type'], 'application/json');
          expect(jsonDecode(request.body), {
            'email': 'second@example.test',
            'password': 'secret',
            'device_name': 'CDS-SMART Mobile',
          });
          return jsonResponse({
            'data': {
              'access_token': 'new-account-token',
              'token_type': 'Bearer',
              'expires_at': '2026-11-11T08:00:00+08:00',
              'user': {'id': 2, 'name': 'Second user'},
            },
          }, status: 201);
        },
      );

      final profile = await client.login(
        email: 'second@example.test',
        password: 'secret',
      );
      expect(observedAuthorization.single, isNull);
      expect(store.token, 'new-account-token');
      expect(client.accountId, 2);
      expect(profile['name'], 'Second user');
    },
  );

  test(
    'login failure remains a credential error and does not retain old token',
    () async {
      final store = MemoryTokenStore()..token = 'previous-account-token';
      final client = createClient(
        store: store,
        handler: (_) async => jsonResponse({
          'error': {'code': 'invalid_credentials', 'message': 'Invalid'},
        }, status: 401),
      );

      await expectLater(
        client.login(email: 'wrong@example.test', password: 'wrong'),
        throwsA(
          isA<MobileApiException>()
              .having(
                (error) => error.message,
                'message',
                'Email or password is incorrect.',
              )
              .having((error) => error.statusCode, 'statusCode', 401),
        ),
      );
      expect(store.token, isNull);
      expect(client.accountId, isNull);
    },
  );

  test(
    'validation fields and Retry-After are surfaced for correction and backoff',
    () async {
      final store = MemoryTokenStore()..token = 'account-token';
      final client = createClient(
        store: store,
        handler: (_) async => jsonResponse({
          'error': {
            'code': 'validation_failed',
            'message': 'Invalid filters.',
            'errors': {
              'reporting_year': ['The reporting year must be valid.'],
            },
          },
        }, status: 422),
      );
      await expectLater(
        client.dashboard(),
        throwsA(
          isA<MobileApiException>().having(
            (error) => error.message,
            'message',
            contains('reporting_year: The reporting year must be valid.'),
          ),
        ),
      );

      final throttled = createClient(
        store: store,
        handler: (_) async => http.Response(
          jsonEncode({
            'error': {'code': 'too_many_requests', 'message': 'Slow down.'},
          }),
          429,
          headers: const {
            'content-type': 'application/json',
            'retry-after': '60',
          },
        ),
      );
      await expectLater(
        throttled.login(email: 'person@example.test', password: 'secret'),
        throwsA(
          isA<MobileApiException>()
              .having(
                (error) => error.retryAfter,
                'retryAfter',
                const Duration(seconds: 60),
              )
              .having(
                (error) => error.message,
                'message',
                contains('60 seconds'),
              ),
        ),
      );
    },
  );

  test(
    'authenticated responses are not cached and files use protected metadata URLs',
    () async {
      final store = MemoryTokenStore()..token = 'account-token';
      var profileCalls = 0;
      final client = createClient(
        store: store,
        handler: (request) async {
          if (request.url.path == '/api/v1/profile') {
            profileCalls++;
            return jsonResponse({
              'data': {'id': 7},
            });
          }
          if (request.url.path == '/api/v1/attachments/bms-report/501/mov') {
            return jsonResponse({
              'data': {
                'key': 'mov',
                'name': 'report.pdf',
                'mime_type': 'application/pdf',
                'preview_url':
                    'https://cds.example.test/api/v1/attachments/bms-report/501/content?preview=1',
                'download_url':
                    'https://cds.example.test/api/v1/attachments/bms-report/501/content?download=1',
              },
            });
          }
          expect(
            request.url.path,
            '/api/v1/attachments/bms-report/501/content',
          );
          expect(request.url.queryParameters['download'], '1');
          expect(request.headers['authorization'], 'Bearer account-token');
          return http.Response('protected bytes', 200);
        },
      );
      await client.profile();
      await client.profile();
      expect(profileCalls, 2);

      final metadata = await client.attachmentMetadata(
        source: 'bms-report',
        recordId: 501,
        attachmentKey: 'mov',
      );
      final response = await client.attachmentContent(
        metadata['download_url'] as String,
      );
      expect(response.body, 'protected bytes');
      await expectLater(
        client.attachmentContent(
          'https://other.example.test/api/v1/attachments/bms/501/content?preview=1',
        ),
        throwsA(isA<MobileApiException>()),
      );
    },
  );
}
