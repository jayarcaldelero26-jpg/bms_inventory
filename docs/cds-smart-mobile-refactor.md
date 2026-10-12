# CDS-SMART Mobile API v1 integration

## Status and safety

The Flutter client implements the written CDS-SMART Mobile API v1 contract.
The API contract and routes/controller were inspected read-only in
`C:\Users\USER\development\cds-system-mobile-api`. Neither that checkout nor
the running CDS-SMART server was changed or contacted. Do not use real accounts:
the server's mobile token migration is still pending.

Real mode is selected by default and requires `CDS_API_BASE_URL`. When unset,
the app makes no network requests. The fictional demo is selected only with
`CDS_DEMO_MODE=true`; it is an independent local screen with no network or
secure token usage. API errors never lead to demo data.

## Implemented API features

- Login, secure bearer-token persistence, startup profile validation, profile,
  and token revocation/logout.
- Authorized overview counts and Incoming, Outgoing, and History pagination.
- All contract tracking filters: search, module, protected area ID, target
  office, reporting period/year, and status.
- Document details with custody state, routing history, and separate review
  state/history.
- User-scoped notifications, pagination, and read/unread updates.
- Protected attachment metadata lookup followed by authenticated preview or
  download URL retrieval; image preview is in-app and other file types can be
  shared through the platform share sheet.
- Explicit loading, empty, service/authorization error, and expired-session
  states. Authenticated API data and protected file bytes are not cached.
  In-memory account data and filter state are cleared at sign-out, account
  switch, or expired session.

No document, routing, or review mutation is exposed by the client. Actor
category, office, module authorization, and data visibility remain server
decisions. `needs_correction` is shown as review state; it does not imply a
custody transfer.

## Configuration and testing

Use only an isolated API deployment with the migration applied and a dedicated
fictional test account:

```powershell
flutter run --dart-define=CDS_API_BASE_URL=https://<isolated-test-host>
```

The configured value must be an HTTPS origin; `/api/v1` is added by the client.
For local debug only, HTTP is accepted for `localhost`, `127.0.0.1`, and
`10.0.2.2`. The secure token is not put in ordinary preferences, logs, URLs,
or analytics. No refresh operation exists; a protected `401` deletes the token
and requires sign-in. Logout clears local credentials even if revocation cannot
reach the server.

The API client tests use an injected mock HTTP transport and cover 401/revoked
tokens, local logout cleanup, pagination/filters/empty out-of-range results,
account switching, no authenticated response caching, and protected attachment
metadata/content requests. Run focused checks with:

```powershell
dart format lib/cds_smart test/cds_smart_mobile_api_test.dart
flutter analyze lib/cds_smart test/cds_smart_mobile_api_test.dart
flutter test test/cds_smart_mobile_api_test.dart
flutter build apk --debug --dart-define=CDS_API_BASE_URL=https://isolated.example.test
```

The HTTPS placeholder build does not make an API call. A real isolated
end-to-end test still requires the reviewed/applied `mobile_api_tokens`
migration in a non-production test deployment, a dedicated active/approved/
verified test account with tracking access and test records/notifications/
attachments, an HTTPS origin reachable from the test Android device, and
explicit authorization to connect that device to that isolated deployment.

## API contract review notes

The inspected Laravel `routes/api.php` and `MobileApiController` match the
documented v1 paths, bearer authentication, `201` login, JSON envelopes,
pagination, queues, filters, profile, notifications, and authorization status
behavior. Attachment metadata descriptors include `key`, `name`, and MIME
details; their separate metadata route uses the protected attachment registry
source (for example `bms-report`), not the tracking source (`bms`). The client
maps tracking sources to registered attachment sources and calls that metadata
route before requesting the returned URL.

No material client/contract mismatch was found in the inspected endpoints.
This source check does not prove that a deployed host has the migration or
serves this API version. Contract response examples remain fictional.

## Preserved app identity and legacy data

This change keeps the existing Android application ID, signing, Firebase
configuration, BMS data stores, and legacy BMS source intact. The mobile
tracking client does not read or write those legacy stores.
