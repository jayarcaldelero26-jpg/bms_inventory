import 'dart:convert';

import 'package:cds_smart_mobile/cds_smart/auth_api.dart';
import 'package:cds_smart_mobile/cds_smart/auth_screens.dart';
import 'package:cds_smart_mobile/cds_smart/mobile_api.dart' show TokenStore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakePersistentTokenStore implements TokenStore {
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

MobileAuthApiClient createClient({
  required FakePersistentTokenStore store,
  required Future<http.Response> Function(http.Request request) handler,
}) => MobileAuthApiClient(
  baseUrl: Uri.parse('https://cds.example.test'),
  tokenStore: store,
  transport: MockClient(handler),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'login posts existing-account credentials and stores the token',
    () async {
      final store = FakePersistentTokenStore()..token = 'old-token';
      final client = createClient(
        store: store,
        handler: (request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/mobile/login');
          expect(request.headers['authorization'], isNull);
          expect(jsonDecode(request.body), {
            'email': 'staff@example.test',
            'password': 'fictional-password',
          });
          return jsonResponse({
            'token': 'new-token',
            'user': {
              'id': 42,
              'name': 'Fictional Staff',
              'email': 'staff@example.test',
            },
          });
        },
      );

      final user = await client.login(
        email: 'staff@example.test',
        password: 'fictional-password',
      );

      expect(user['id'], 42);
      expect(store.token, 'new-token');
    },
  );

  test('me fetches the minimal profile with the saved bearer token', () async {
    final store = FakePersistentTokenStore()..token = 'saved-token';
    final client = createClient(
      store: store,
      handler: (request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/mobile/me');
        expect(request.headers['authorization'], 'Bearer saved-token');
        return jsonResponse({
          'user': {
            'id': 42,
            'name': 'Fictional Staff',
            'email': 'staff@example.test',
          },
        });
      },
    );

    expect(await client.profile(), {
      'id': 42,
      'name': 'Fictional Staff',
      'email': 'staff@example.test',
    });
  });

  test('logout posts with the saved token and removes it', () async {
    final store = FakePersistentTokenStore()..token = 'saved-token';
    final client = createClient(
      store: store,
      handler: (request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/mobile/logout');
        expect(request.headers['authorization'], 'Bearer saved-token');
        return jsonResponse({'message': 'Signed out.'});
      },
    );

    await client.logout();

    expect(store.token, isNull);
  });

  test('failed login removes an old token and reports the API error', () async {
    final store = FakePersistentTokenStore()..token = 'old-token';
    final client = createClient(
      store: store,
      handler: (_) async => jsonResponse({
        'message': 'The provided credentials are invalid.',
        'errors': {
          'email': ['The provided credentials are invalid.'],
        },
      }, status: 422),
    );

    await expectLater(
      client.login(email: 'staff@example.test', password: 'wrong'),
      throwsA(
        isA<MobileAuthException>().having(
          (error) => error.message,
          'message',
          'Email or password is incorrect.',
        ),
      ),
    );
    expect(store.token, isNull);
  });

  testWidgets('API login failure never falls back to demo records', (
    tester,
  ) async {
    final store = FakePersistentTokenStore();
    final client = createClient(
      store: store,
      handler: (_) async => jsonResponse({
        'message': 'The provided credentials are invalid.',
        'errors': {
          'email': ['The provided credentials are invalid.'],
        },
      }, status: 422),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CdsSmartHome(apiClient: client, tokenStore: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'staff@example.test');
    await tester.enterText(find.byType(TextField).at(1), 'fictional-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.textContaining('Sample conservation submission'), findsNothing);
    expect(find.textContaining('DEMO MODE'), findsNothing);
  });

  testWidgets('authenticated view shows profile and tracking controls', (
    tester,
  ) async {
    final store = FakePersistentTokenStore();
    final client = createClient(
      store: store,
      handler: (request) async {
        if (request.url.path == '/api/mobile/login') {
          return jsonResponse({
            'token': 'profile-token',
            'user': {
              'id': 42,
              'name': 'Fictional Staff',
              'email': 'staff@example.test',
            },
          });
        }
        throw StateError('Unexpected request to ${request.url.path}');
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CdsSmartHome(apiClient: client, tokenStore: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'staff@example.test');
    await tester.enterText(find.byType(TextField).at(1), 'fictional-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Fictional Staff'), findsOneWidget);
    expect(find.text('staff@example.test'), findsOneWidget);
    expect(find.text('Submission tracking'), findsOneWidget);
    expect(find.text('Incoming'), findsOneWidget);
    expect(find.text('Outgoing'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(
      find.textContaining('Document tracking is not yet available'),
      findsNothing,
    );
    expect(
      find.textContaining('Tracking data is not available in this app yet'),
      findsNothing,
    );
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Notifications'), findsNothing);
    expect(find.textContaining('Protected area'), findsNothing);
  });

  testWidgets('recreated app restores with saved bearer token via /me', (
    tester,
  ) async {
    final store = FakePersistentTokenStore();
    final loginClient = createClient(
      store: store,
      handler: (request) async => jsonResponse({
        'token': 'persisted-token',
        'user': {
          'id': 42,
          'name': 'Fictional Staff',
          'email': 'staff@example.test',
        },
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CdsSmartHome(apiClient: loginClient, tokenStore: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'staff@example.test');
    await tester.enterText(find.byType(TextField).at(1), 'fictional-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(store.token, 'persisted-token');
    await tester.pumpWidget(const SizedBox.shrink());

    var meCalls = 0;
    final restoredClient = createClient(
      store: store,
      handler: (request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/mobile/me');
        expect(request.headers['authorization'], 'Bearer persisted-token');
        meCalls++;
        return jsonResponse({
          'user': {
            'id': 42,
            'name': 'Fictional Staff',
            'email': 'staff@example.test',
          },
        });
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CdsSmartHome(apiClient: restoredClient, tokenStore: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(meCalls, 1);
    expect(store.token, 'persisted-token');
    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('Fictional Staff'), findsOneWidget);
  });

  testWidgets('temporary /me failure preserves token and can be retried', (
    tester,
  ) async {
    final store = FakePersistentTokenStore()..token = 'persisted-token';
    var meCalls = 0;
    final client = createClient(
      store: store,
      handler: (request) async {
        expect(request.url.path, '/api/mobile/me');
        expect(request.headers['authorization'], 'Bearer persisted-token');
        meCalls++;
        if (meCalls == 1) {
          throw http.ClientException('Temporary network failure.');
        }
        if (meCalls == 2) {
          return jsonResponse({'message': 'Temporary failure.'}, status: 503);
        }
        return jsonResponse({
          'user': {
            'id': 42,
            'name': 'Fictional Staff',
            'email': 'staff@example.test',
          },
        });
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CdsSmartHome(apiClient: client, tokenStore: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(
      find.text('Could not reach the sign-in service. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry session restore'), findsOneWidget);
    expect(store.token, 'persisted-token');

    await tester.tap(find.text('Retry session restore'));
    await tester.pumpAndSettle();

    expect(meCalls, 2);
    expect(store.token, 'persisted-token');
    expect(find.text('Retry session restore'), findsOneWidget);

    await tester.tap(find.text('Retry session restore'));
    await tester.pumpAndSettle();

    expect(meCalls, 3);
    expect(find.text('Your profile'), findsOneWidget);
  });

  testWidgets('401 during restore clears token and returns to sign in', (
    tester,
  ) async {
    final store = FakePersistentTokenStore()..token = 'revoked-token';
    final client = createClient(
      store: store,
      handler: (_) async =>
          jsonResponse({'message': 'Unauthenticated.'}, status: 401),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CdsSmartHome(apiClient: client, tokenStore: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(store.token, isNull);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.text('Retry session restore'), findsNothing);
  });

  testWidgets('explicit sign out calls logout and clears local token', (
    tester,
  ) async {
    final store = FakePersistentTokenStore()..token = 'active-token';
    var logoutCalls = 0;
    final client = createClient(
      store: store,
      handler: (request) async {
        if (request.url.path == '/api/mobile/me') {
          return jsonResponse({
            'user': {
              'id': 42,
              'name': 'Fictional Staff',
              'email': 'staff@example.test',
            },
          });
        }
        expect(request.method, 'POST');
        expect(request.url.path, '/api/mobile/logout');
        expect(request.headers['authorization'], 'Bearer active-token');
        logoutCalls++;
        return jsonResponse({'message': 'Signed out.'});
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CdsSmartHome(apiClient: client, tokenStore: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your profile'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(logoutCalls, 1);
    expect(store.token, isNull);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
