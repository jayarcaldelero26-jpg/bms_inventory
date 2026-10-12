# CDS-SMART Mobile

Flutter client for the read-only CDS-SMART Mobile API v1 contract. Real mode
requires a configured API origin and an approved, active, email-verified
account. API records are never replaced with fictional data after a network or
authorization error.

Configure and run against an **isolated test deployment** only:

```powershell
flutter run --dart-define=CDS_API_BASE_URL=https://<isolated-test-host>
```

The API base value is an HTTPS origin; the client adds `/api/v1`. Local
debug-only HTTP is accepted for `localhost`, `127.0.0.1`, or Android Emulator's
`10.0.2.2`. Without a URL, the app makes no requests and shows a configuration
message.

The fictional demo is independent and explicitly opt-in:

```powershell
flutter run --dart-define=CDS_DEMO_MODE=true
```

Demo mode performs no API requests, does not sign in, and does not write demo
state to device storage. If both defines are set, the demo remains isolated
from the API.

The client stores only the opaque bearer token in OS secure storage, clears it
on logout or protected-endpoint `401`, and does not cache authenticated
responses or protected file bytes. See
[the integration guide](docs/cds-smart-mobile-refactor.md) for implemented
features, contract notes, and isolated end-to-end prerequisites.
