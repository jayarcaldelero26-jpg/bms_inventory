import 'dart:convert';

import 'package:cds_smart_mobile/cds_smart/app.dart';
import 'package:cds_smart_mobile/cds_smart/mobile_api.dart';
import 'package:cds_smart_mobile/cds_smart/screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _MemoryTokenStore implements TokenStore {
  String? token;

  @override
  Future<void> delete() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('active client restores and logs out through the mobile auth contract', () async {
    final store = _MemoryTokenStore()..token = 'saved-token';
    final seen = <http.Request>[];
    final api = MobileApiClient(
      baseUrl: Uri.parse('https://cds.example.test'),
      tokenStore: store,
      transport: MockClient((request) async {
        seen.add(request);
        if (request.url.path == '/api/mobile/me') {
          return _json({'user': {'id': 8, 'name': 'Fictional Staff'}});
        }
        if (request.url.path == '/api/mobile/logout') {
          return _json({'message': 'Signed out.'});
        }
        throw StateError('Unexpected request to ${request.url.path}');
      }),
    );

    await api.restoreSession();
    expect(api.accountId, 8);
    await api.logout();

    expect(seen.map((request) => request.url.path), [
      '/api/mobile/me',
      '/api/mobile/logout',
    ]);
    expect(
      seen.every(
        (request) => request.headers['authorization'] == 'Bearer saved-token',
      ),
      isTrue,
    );
    expect(seen.last.method, 'POST');
    expect(store.token, isNull);
  });

  testWidgets('app entry uses the configured tracking sign-in screen', (
    tester,
  ) async {
    await tester.pumpWidget(const CdsSmartApp());
    await tester.pumpAndSettle();

    expect(find.text('Service not configured'), findsOneWidget);
    expect(find.text('Authorized mobile access'), findsNothing);
  });

  testWidgets(
    'authenticated queue UI uses canonical list and authorized detail endpoints',
    (tester) async {
      final store = _MemoryTokenStore();
      final seen = <http.Request>[];
      final api = MobileApiClient(
        baseUrl: Uri.parse('https://cds.example.test'),
        tokenStore: store,
        transport: MockClient((request) async {
          seen.add(request);
          if (request.url.path == '/api/mobile/login') {
            return _json({
              'token': 'fictional-token',
              'user': {
                'id': 8,
                'name': 'Fictional Staff',
                'email': 'staff@example.test',
              },
            }, status: 201);
          }
          if (request.url.path == '/api/mobile/me') {
            return _json({
              'user': {
                'id': 8,
                'name': 'Fictional Staff',
                'email': 'staff@example.test',
              },
            });
          }
          if (request.url.path.startsWith('/api/mobile/submission-tracking/')) {
            final queue = request.url.path.split('/').last;
            return _json({
              'data': [
                {
                  'id': 'bms:23',
                  'source': 'bms',
                  'source_record_id': 23,
                  'module': 'BMS',
                  'activity_name': 'Fictional activity',
                  'tracking_number': 'BMS-TEST-23',
                  'submission_status': 'For review',
                  'current_location': 'CENRO Baganga',
                  'queue': queue,
                },
              ],
              'meta': {
                'current_page': 1,
                'per_page': 25,
                'total': 1,
                'last_page': 1,
                'has_more': false,
              },
            });
          }
          if (request.url.path ==
              '/api/mobile/submission-tracking/documents/bms/23') {
            return _json({
              'data': {
                'source': 'bms',
                'source_record_id': 23,
                'activity_name': 'Fictional activity',
                'tracking_number': 'BMS-TEST-23',
                'current_custody': {'status': 'For review'},
                'routing_events': [],
                'review': {},
                'review_events': [],
                'attachments': [],
                'read_only': true,
              },
            });
          }
          throw StateError('Unexpected request to ${request.url.path}');
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CdsSmartHome(apiClient: api, tokenStore: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(0),
        'staff@example.test',
      );
      await tester.enterText(find.byType(TextField).at(1), 'fictional-secret');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Your work queues'), findsOneWidget);
      expect(find.text('Modules'), findsNothing);
      await tester.tap(find.text('Tracking'));
      await tester.pumpAndSettle();
      expect(find.text('Incoming'), findsWidgets);
      expect(find.text('Outgoing'), findsWidgets);
      expect(find.text('History'), findsWidgets);
      expect(find.text('Fictional activity'), findsOneWidget);

      await tester.tap(find.text('Outgoing').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('History').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fictional activity').last);
      await tester.pumpAndSettle();

      expect(find.text('BMS-TEST-23'), findsOneWidget);
      expect(
        seen
            .where(
              (request) => request.url.path.startsWith(
                '/api/mobile/submission-tracking/',
              ),
            )
            .map((request) => request.url.path.split('/').last),
        containsAll(['incoming', 'outgoing', 'history']),
      );
      expect(
        seen.any(
          (request) =>
              request.url.path ==
              '/api/mobile/submission-tracking/documents/bms/23',
        ),
        isTrue,
      );
      expect(
        seen
            .where(
              (request) => request.url.path.startsWith(
                '/api/mobile/submission-tracking/',
              ),
            )
            .every(
              (request) =>
                  request.headers['authorization'] == 'Bearer fictional-token',
            ),
        isTrue,
      );
    },
  );
}
