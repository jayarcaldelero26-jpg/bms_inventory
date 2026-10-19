/// Validates the origin before any mobile API client can attach a bearer token.
Uri validateMobileApiOrigin(Uri url, {required bool releaseBuild}) {
  final isLocalHost = const {
    'localhost',
    '127.0.0.1',
    '::1',
    // Android emulator's host-loopback alias for a local development API.
    '10.0.2.2',
  }.contains(url.host.toLowerCase());
  final isHttps = url.scheme == 'https';
  final isLocalDebugHttp = !releaseBuild && url.scheme == 'http' && isLocalHost;

  if (!url.hasAuthority ||
      url.userInfo.isNotEmpty ||
      !(isHttps || isLocalDebugHttp) ||
      url.path.isNotEmpty && url.path != '/' ||
      url.query.isNotEmpty ||
      url.fragment.isNotEmpty) {
    throw ArgumentError.value(
      url,
      'baseUrl',
      'Use an HTTPS origin; local HTTP is allowed only in debug builds.',
    );
  }

  return url.replace(path: '');
}
