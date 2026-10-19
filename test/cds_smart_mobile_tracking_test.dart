import 'dart:convert';
import 'dart:async';

import 'package:cds_smart_mobile/cds_smart/auth_api.dart';
import 'package:cds_smart_mobile/cds_smart/auth_screens.dart';
import 'package:cds_smart_mobile/cds_smart/mobile_api.dart' show TokenStore;
import 'package:cds_smart_mobile/cds_smart/mobile_tracking_api.dart';
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

http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _queueResponse({
  List<Map<String, dynamic>> rows = const [],
  int page = 1,
  int lastPage = 1,
  int total = 0,
}) => {
  'data': rows,
  'meta': {
    'queue': 'incoming',
    'current_page': page,
    'per_page': 25,
    'total': total,
    'last_page': lastPage,
    'from': rows.isEmpty ? null : ((page - 1) * 25) + 1,
    'to': rows.isEmpty ? null : ((page - 1) * 25) + rows.length,
  },
  'filters': <String, dynamic>{},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'queues send auth, search/filter, and pagination to the real contract',
    () async {
      final store = _MemoryTokenStore()..token = 'fictional-token';
      final client = MobileTrackingApiClient(
        baseUrl: Uri.parse('https://cds.example.test'),
        tokenStore: store,
        transport: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/mobile/submission-tracking/history');
          expect(request.url.queryParameters, {
            'search': 'mangrove',
            'reporting_year': '2026',
            'page': '2',
            'per_page': '25',
          });
          expect(request.headers['authorization'], 'Bearer fictional-token');
          return _json(_queueResponse(page: 2, lastPage: 3, total: 55));
        }),
      );

      final result = await client.queue(
        queue: 'history',
        page: 2,
        filters: {'search': 'mangrove', 'reporting_year': '2026'},
      );
      expect(result.items, isEmpty);
      expect(result.currentPage, 2);
      expect(result.lastPage, 3);
      expect(result.total, 55);
    },
  );

  test(
    'details use source and source_id and decode the authorized projection',
    () async {
      final store = _MemoryTokenStore()..token = 'fictional-token';
      final client = MobileTrackingApiClient(
        baseUrl: Uri.parse('https://cds.example.test'),
        tokenStore: store,
        transport: MockClient((request) async {
          expect(
            request.url.path,
            '/api/mobile/submission-tracking/documents/bms/7',
          );
          expect(request.headers['authorization'], 'Bearer fictional-token');
          return _json({
            'data': {
              'source': 'bms',
              'source_id': 7,
              'tracking_number': 'FIC-007',
              'routing_summary': {'current_status': 'Pending'},
              'routing_timeline': <Object>[],
            },
          });
        }),
      );

      final detail = await client.document('bms', 7);
      expect(detail['source_id'], 7);
      expect(detail['routing_summary']['current_status'], 'Pending');
    },
  );

  test(
    'Incoming, Outgoing, and History use their documented queue routes',
    () async {
      final store = _MemoryTokenStore()..token = 'fictional-token';
      final seen = <String>[];
      final client = MobileTrackingApiClient(
        baseUrl: Uri.parse('https://cds.example.test'),
        tokenStore: store,
        transport: MockClient((request) async {
          seen.add(request.url.path);
          return _json(_queueResponse());
        }),
      );

      for (final queue in const ['incoming', 'outgoing', 'history']) {
        await client.queue(queue: queue);
      }
      expect(seen, [
        '/api/mobile/submission-tracking/incoming',
        '/api/mobile/submission-tracking/outgoing',
        '/api/mobile/submission-tracking/history',
      ]);
    },
  );

  testWidgets(
    'successful API queues replace placeholder copy with real results',
    (tester) async {
      final store = _MemoryTokenStore();
      final transport = MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return _json({
            'token': 'fictional-token',
            'user': {
              'id': 8,
              'name': 'Fictional Staff',
              'email': 'staff@example.test',
            },
          });
        }
        if (request.url.path.endsWith('/me')) {
          return _json({
            'user': {
              'id': 8,
              'name': 'Fictional Staff',
              'email': 'staff@example.test',
            },
          });
        }
        return _json(
          _queueResponse(
            rows: [
              {
                'source': 'bms',
                'source_id': 7,
                'activity_name': 'Fictional Authorized Tracking Record',
                'document_type': 'BMS Report',
                'target_office': 'CENRO Mati',
                'submission_status': 'Forwarded',
              },
            ],
            total: 1,
          ),
        );
      });
      final auth = MobileAuthApiClient(
        baseUrl: Uri.parse('https://cds.example.test'),
        tokenStore: store,
        transport: transport,
      );
      final tracking = MobileTrackingApiClient(
        baseUrl: Uri.parse('https://cds.example.test'),
        tokenStore: store,
        transport: transport,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CdsSmartHome(
            apiClient: auth,
            trackingClient: tracking,
            tokenStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(0),
        'staff@example.test',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'fictional-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Fictional Authorized Tracking Record'), findsOneWidget);
      expect(find.text('1 records · Page 1 of 1'), findsOneWidget);
      expect(
        find.textContaining('Document tracking is not yet available'),
        findsNothing,
      );
      expect(
        find.textContaining('Tracking data is not available in this app yet'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'tracking loading state remains visible while the queue request is pending',
    (tester) async {
      final store = _MemoryTokenStore();
      final queueResponse = Completer<http.Response>();
      final transport = MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return _json({
            'token': 'fictional-token',
            'user': {
              'id': 8,
              'name': 'Fictional Staff',
              'email': 'staff@example.test',
            },
          });
        }
        if (request.url.path.endsWith('/me')) {
          return _json({
            'user': {
              'id': 8,
              'name': 'Fictional Staff',
              'email': 'staff@example.test',
            },
          });
        }
        return queueResponse.future;
      });
      final auth = MobileAuthApiClient(
        baseUrl: Uri.parse('https://cds.example.test'),
        tokenStore: store,
        transport: transport,
      );
      final tracking = MobileTrackingApiClient(
        baseUrl: Uri.parse('https://cds.example.test'),
        tokenStore: store,
        transport: transport,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CdsSmartHome(
            apiClient: auth,
            trackingClient: tracking,
            tokenStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(0),
        'staff@example.test',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'fictional-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Your profile'), findsOneWidget);
      expect(find.text('Submission tracking'), findsOneWidget);
      expect(find.text('Loading tracking...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(
        find.textContaining('Document tracking is not yet available'),
        findsNothing,
      );

      queueResponse.complete(_json(_queueResponse()));
      await tester.pumpAndSettle();
      expect(find.text('No submissions found.'), findsOneWidget);
    },
  );

  testWidgets(
    'tracking API errors show no demo records and retry stays on API',
    (tester) async {
      final store = _MemoryTokenStore();
      final requests = <String>[];
      final transport = MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path.endsWith('/login')) {
          return _json({
            'token': 'fictional-token',
            'user': {
              'id': 8,
              'name': 'Fictional Staff',
              'email': 'staff@example.test',
            },
          });
        }
        if (request.url.path.endsWith('/me')) {
          return _json({
            'user': {
              'id': 8,
              'name': 'Fictional Staff',
              'email': 'staff@example.test',
            },
          });
        }
        return _json({'message': 'Tracking forbidden.'}, 403);
      });
      final auth = MobileAuthApiClient(
        baseUrl: Uri.parse('https://cds.example.test'),
        tokenStore: store,
        transport: transport,
      );
      final tracking = MobileTrackingApiClient(
        baseUrl: Uri.parse('https://cds.example.test'),
        tokenStore: store,
        transport: transport,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CdsSmartHome(
            apiClient: auth,
            trackingClient: tracking,
            tokenStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(0),
        'staff@example.test',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'fictional-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(
        find.text('Tracking is not available for this account.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(
        find.textContaining('Document tracking is not yet available'),
        findsNothing,
      );
      expect(
        find.textContaining('Tracking data is not available in this app yet'),
        findsNothing,
      );
      expect(
        find.textContaining('Sample conservation submission'),
        findsNothing,
      );
      expect(find.textContaining('Fictional report'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        requests.where((path) => path.contains('/submission-tracking/')).length,
        2,
      );
    },
  );

  testWidgets('sign out removes token and returns to existing-account login', (
    tester,
  ) async {
    final store = _MemoryTokenStore();
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return _json({
          'token': 'fictional-token',
          'user': {
            'id': 8,
            'name': 'Fictional Staff',
            'email': 'staff@example.test',
          },
        });
      }
      if (request.url.path.endsWith('/me')) {
        return _json({
          'user': {
            'id': 8,
            'name': 'Fictional Staff',
            'email': 'staff@example.test',
          },
        });
      }
      if (request.url.path.endsWith('/logout')) {
        return _json({'message': 'Signed out.'});
      }
      return _json(_queueResponse());
    });
    final auth = MobileAuthApiClient(
      baseUrl: Uri.parse('https://cds.example.test'),
      tokenStore: store,
      transport: transport,
    );
    final tracking = MobileTrackingApiClient(
      baseUrl: Uri.parse('https://cds.example.test'),
      tokenStore: store,
      transport: transport,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CdsSmartHome(
          apiClient: auth,
          trackingClient: tracking,
          tokenStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'staff@example.test');
    await tester.enterText(find.byType(TextField).at(1), 'fictional-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(store.token, isNull);
    expect(
      find.text('Use your existing CDS-SMART web account.'),
      findsOneWidget,
    );
  });
}
