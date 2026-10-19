# CDS-SMART Mobile

Flutter client for the read-only CDS-SMART mobile API. The active app uses the Laravel /api/mobile routes; it does not use the legacy /api/v1 client for this flow.

Configure an HTTPS API origin. The app appends /api/mobile itself:

    flutter run --dart-define=CDS_API_BASE_URL=https://<isolated-test-host>

The host above is a placeholder, not a configured staging address. No staging API hostname is stored in this repository.

The mobile login accepts existing active web accounts. Approval and email-verification status do not block mobile login. Inactive accounts are denied. Submission Tracking access is granted separately by the backend organizational policy.

The app supports login, profile restore, logout, Incoming, Outgoing, History, queue search and filters, pagination, and authorized document details with routing history. It does not expose routing mutations, notifications, or attachment delivery. API failures remain errors/retry states and never load demo records.

The fictional demo is independent and explicitly opt-in:

    flutter run --dart-define=CDS_DEMO_MODE=true

Without a configured API origin, real mode does not make network requests. In debug builds, the client permits HTTP only for local development hosts; release builds require HTTPS. The bearer token is stored with the platform secure-storage plugin.

See docs/cds-smart-mobile-refactor.md for the route contract, response fields, authorization behavior, test commands, and isolated staging prerequisites.
