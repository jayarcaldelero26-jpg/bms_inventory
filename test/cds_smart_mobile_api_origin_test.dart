import 'package:flutter_test/flutter_test.dart';
import 'package:cds_smart_mobile/cds_smart/mobile_api_origin.dart';
import 'package:cds_smart_mobile/cds_smart/auth_api.dart';
import 'package:cds_smart_mobile/cds_smart/mobile_tracking_api.dart';
import 'package:cds_smart_mobile/cds_smart/mobile_api.dart'
    show MobileApiClient, SecureTokenStore;

void main() {
  test('accepts HTTPS origins in release and debug builds', () {
    final url = Uri.parse('https://mobile.example.test');

    expect(validateMobileApiOrigin(url, releaseBuild: true), url);
    expect(validateMobileApiOrigin(url, releaseBuild: false), url);
  });

  test('accepts HTTP only for local hosts in debug builds', () {
    for (final host in ['localhost', '127.0.0.1', '[::1]', '10.0.2.2']) {
      expect(
        validateMobileApiOrigin(
          Uri.parse('http://$host:8000'),
          releaseBuild: false,
        ).scheme,
        'http',
      );
      expect(
        () => validateMobileApiOrigin(
          Uri.parse('http://$host:8000'),
          releaseBuild: true,
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects plaintext non-local origins in every build mode', () {
    final url = Uri.parse('http://mobile.example.test');

    expect(
      () => validateMobileApiOrigin(url, releaseBuild: false),
      throwsArgumentError,
    );
    expect(
      () => validateMobileApiOrigin(url, releaseBuild: true),
      throwsArgumentError,
    );
  });

  test(
    'API clients reject plaintext non-local origins before sending tokens',
    () {
      final url = Uri.parse('http://mobile.example.test');

      expect(() => MobileAuthApiClient(baseUrl: url), throwsArgumentError);
      expect(() => MobileTrackingApiClient(baseUrl: url), throwsArgumentError);
      expect(
        () => MobileApiClient(baseUrl: url, tokenStore: SecureTokenStore()),
        throwsArgumentError,
      );
    },
  );

  test(
    'rejects origins containing paths, credentials, queries, or fragments',
    () {
      for (final url in [
        Uri.parse('https://mobile.example.test/api'),
        Uri.parse('https://user:password@mobile.example.test'),
        Uri.parse('https://mobile.example.test?token=secret'),
        Uri.parse('https://mobile.example.test#fragment'),
      ]) {
        expect(
          () => validateMobileApiOrigin(url, releaseBuild: false),
          throwsArgumentError,
        );
      }
    },
  );
}
