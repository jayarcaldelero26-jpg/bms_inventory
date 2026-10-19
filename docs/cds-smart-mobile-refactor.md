# CDS-SMART Mobile API integration

## Current contract

The active Flutter flow uses the Laravel /api/mobile API. It does not use the legacy /api/v1 API client. The mobile API is read-only for Submission Tracking.

No staging API hostname is configured in this repository. Examples below use a placeholder; replace it only with an approved isolated test deployment. Do not point E2E tests at a production database or real user account.

## Authentication and session

- POST /api/mobile/login accepts email and password for an existing active web account.
- Inactive accounts are denied. Approval and email-verification status are not eligibility checks for mobile login.
- The response contains a top-level token and a minimal user object with id, name, and email.
- Every token receives mobile:auth. The backend adds submission-tracking:read only when the existing organizational access policy allows it.
- Tokens expire after 30 days. The server stores a hash; the Flutter app stores the bearer token in OS secure storage.
- GET /api/mobile/me returns the minimal user object under user.
- POST /api/mobile/logout revokes the current token. The app clears local token storage even if logout cannot reach the server.
- Startup calls /me only when secure storage contains a nonempty token. A transient network/server failure preserves the token and offers Retry session restore; an authenticated 401 clears the expired or revoked token.

## Queue and detail routes

Queues:

- GET /api/mobile/submission-tracking/incoming
- GET /api/mobile/submission-tracking/outgoing
- GET /api/mobile/submission-tracking/history

Supported query parameters:

- search: string, maximum 120 characters
- module: string, maximum 120 characters
- protected_area_id: positive integer
- target_office: string, maximum 160 characters
- reporting_period: string, maximum 80 characters
- reporting_year: integer from 1900 through 2200
- status: string, maximum 80 characters
- page: positive integer, default 1
- per_page: integer from 1 through 100, default 25

Queue responses contain data, meta, and filters. The meta object contains queue, current_page, per_page, total, last_page, from, and to. List rows are limited to source, source_id, tracking_number, workflow_key, module, target_office, protected_area, protected_area_id, activity_name, document_type, reporting_year, date_conducted, date_accomplished, reporting_period, deadline_submission, submission_status, stage, routing_complete, and completed_at.

Authorized document detail:

- GET /api/mobile/submission-tracking/documents/{source}/{record}

The response contains data with the permitted list fields, routing_summary, and routing_timeline. Timeline entries expose only the approved event fields. The backend resolves source records through the existing SubmissionTrackingService and checks both organizational Tracking access and source-aware document access. Unauthorized or missing documents are not exposed.

The Flutter app sends only the supported queue filters, displays loading/empty/error states, and never substitutes demo records after an API failure. Search and filtering are server requests; the API controls record visibility, queue membership, and ordering.

## Security and transport

Set CDS_API_BASE_URL to an origin, not an API path. The Flutter client adds /api/mobile. Use HTTPS outside local debug testing.

Debug builds permit HTTP for localhost, 127.0.0.1, ::1, and Android Emulator alias 10.0.2.2. The Laravel local/testing exception is narrower: it also requires a loopback client address and permits only localhost, 127.0.0.1, ::1, or cds-system.test as the Host. For local phone testing, use a verified loopback/ADB reverse setup or HTTPS; the emulator alias accepted by Flutter is not by itself proof that the backend local exception will accept the request.

Laravel rejects insecure public requests with HTTP 426. This application check is defense in depth. The actual hosting proxy/web-server must enforce HTTPS before bearer tokens can cross the public network, and TRUSTED_PROXIES must match the real staging proxy addresses.

## Configuration and tests

Use an HTTPS origin for an isolated test deployment:

    flutter run --dart-define=CDS_API_BASE_URL=https://<isolated-test-host> --dart-define=CDS_DEMO_MODE=false

The placeholder is not a real or known staging URL. No staging host was found in the repository configuration.

Focused Flutter checks:

    dart format lib/cds_smart test/cds_smart_mobile_api_origin_test.dart test/cds_smart_mobile_auth_test.dart test/cds_smart_mobile_tracking_test.dart
    flutter analyze lib/cds_smart/auth_api.dart lib/cds_smart/auth_screens.dart lib/cds_smart/mobile_api_origin.dart lib/cds_smart/mobile_tracking_api.dart test/cds_smart_mobile_api_origin_test.dart test/cds_smart_mobile_auth_test.dart test/cds_smart_mobile_tracking_test.dart
    flutter test test/cds_smart_mobile_api_origin_test.dart test/cds_smart_mobile_auth_test.dart test/cds_smart_mobile_tracking_test.dart

Backend focused feature tests:

    php artisan test tests/Feature/MobileSubmissionTrackingApiTest.php tests/Feature/MobileApiHttpsEnforcementTest.php tests/Feature/Auth/SharedLoginAttemptLimiterTest.php

The backend PHPUnit configuration uses SQLite :memory: for feature tests. Do not run a standalone migration or point tests at a real CDS-SMART database.

## Scope and deployment prerequisites

The mobile API currently exposes authentication and read-only Submission Tracking only. It has no mobile notification routes, attachment delivery, overview endpoint, or routing mutation endpoints.

Before isolated E2E testing, deploy the reviewed backend revision to an isolated test environment, apply the mobile_api_tokens migration through its approved deployment process, configure TLS and exact trusted proxy addresses, and create fictional user/record fixtures. The Android release build must use an owner-approved signing configuration before distribution. The deployment URL, target database, edge configuration, and signing secret are intentionally not specified in this repository.
