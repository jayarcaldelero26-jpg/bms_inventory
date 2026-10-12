# CDS-SMART Mobile refactor

## Status

**PARTIAL — backend source verified; mobile API and runtime remain blocked.**
The active mobile screen is an honest, API-independent shell for the verified
Submission Tracking concepts. It does not authenticate, request, cache, or
display CDS records. The earlier technical-report client and its assumed
`/api/mobile` endpoints were removed from the active source because they were
built against the wrong web snapshot. Do not connect that temporary API work
to this client.

## Verified source and repository identity

The local web checkout is `C:\laragon\www\cds-system`, branch
`feature/cds-smart-mobile-refactor`, HEAD
`557732ec5e88bc55583a0077b0b561159dcf0f80`, remote
`https://github.com/jayarcaldelero26-jpg/cds-system.git`. The worktree contains
12 prior task-created web changes, all pending review. They are preserved and
were not modified as part of this continuation.

After the authorized fetch, the fetched `origin/main` source at
`7279fcf0964cd90e45581c668969be74962230a6`
(`checkpoint: Office TAT, historical reports and PAMO workflows`, 2026-10-11)
contains the requested CDS-SMART workflow implementation. This is source
inspected directly with read-only Git commands; no branch was checked out.
The older local `origin/master` / local HEAD does not contain these workflows.

The fetched source includes:

- `SubmissionTrackingController`, `ConservationReportSubmissionController`,
  `SubmissionTrackingService`, and the Inertia page
  `resources/js/Pages/SubmissionTracking/Index.jsx`.
- `OrganizationalAccessService`, `DocumentRoutingAccessService`, office and
  protected-area assignment models, and routing policies.
- `DocumentRoutingEvent`, `SubmissionRoutingSnapshot`, and distinct
  `PambMovReviewEvent` records, with corresponding migrations.
- `NotificationController` and `EdatsInAppNotificationService`.
- `routes/web.php` routes for tracking, attachments, notifications, and
  workflow administration.

**Serving checkout is not established.** Earlier read-only Apache inspection
showed `cds-system.test` serving the older local checkout’s `public` directory;
no `cds-smart` virtual host or host entry was found. The fetched `origin/main`
is a verified source reference, not proof that a named CDS-SMART hostname
serves that commit. No authenticated application request was made.

## Source-grounded feature mapping

| Web behavior | Verified source semantics | Mobile status |
| --- | --- | --- |
| Incoming | Active, incomplete records requiring an action; the service projects the canonical queues and current action category. The page describes this as requiring action from the user’s office. | Definition shown; authorized data integration pending. |
| Outgoing | Incomplete records acted on/forwarded by the office and not also currently in its Incoming queue. | Definition shown; authorized data integration pending. |
| History | Completed routing records within the user’s authorized scope, ordered by completion/update time. | Definition shown; authorized data integration pending. |
| Custody and timeline | `document_routing_events` records workflow/event, stages, from/to offices, timestamp, actor, remarks, and metadata; routing snapshots also exist. | Typed routing-event model added; API and detail UI pending. |
| MOV review | `PambMovReviewEvent` is separate from routing events. A verdict such as `needs_correction` does not itself establish a new custody office; a return/transfer is represented as routing. | Separate typed review-event model and distinction note added; review history UI/API pending. |
| Organizational authorization | Tracking checks the tracking permission and source ability, then global status, actor category, organizational unit, office and protected-area scope. Global users have a distinct queue projection. | Must be enforced and re-evaluated by the backend on every mobile request. Client-side role filtering is not an authorization boundary. |
| Notifications | User-owned database notifications include read timestamps. Web routes list/recent, mark read/unread, mark all read, and clear; recent bell entries are limited to unread due-soon/overdue/workflow types. | Not integrated; read/unread API pending. |
| Search, details, attachments | Web tracking is an authenticated Inertia page. Attachment routes require the web session and tracking permission; the protected preview resolves server-side paths. | Mobile search/details/previews pending protected API responses. |

### API compatibility

In fetched `origin/main`, `routes/api.php` is absent. The tracking and
notification routes are in `routes/web.php` under web/session authentication
and return Inertia responses or session-authenticated JSON. The route named
`api.global-search` is also in the authenticated web routes; its name does not
make the session-authenticated web application a mobile API. The `recent`
notification JSON endpoint likewise does not provide mobile bearer-token
authentication. No compatible mobile login, session, tracking, detail,
attachment, or notification API was verified.

Required backend work is **pending and must be implemented only in a separately
authorized development copy**. A minimal API should provide:

1. A documented mobile sign-in/session lifecycle and secure token revocation.
   Re-check active account, permissions, actor category, organizational unit,
   office, protected-area jurisdiction, and source access on every request.
2. A paginated, filterable Submission Tracking read endpoint for the three
   verified queues. Derive all totals and rows from the same server-authorized
   scope; do not accept client-supplied office, role, or area scope as trusted.
3. A scoped detail endpoint returning current custody, routing events/snapshots,
   separate MOV review history, and server-generated protected attachment
   references. Serve previews through an authenticated, authorization-checked
   endpoint; never accept filesystem paths from the client.
4. User-scoped notification listing with read/unread state and authorized
   read-state mutations, using the existing user notification records.
5. API feature tests for unauthenticated access, account/role/category/office/
   jurisdiction boundaries, pagination/filter consistency, record details,
   attachment access, notifications, logout, and account switching.

Keep CDS-SMART as the source of truth. Do not add a Firestore mirror, direct
MySQL access, workflow mutations in this initial mobile scope, or offline
workflow writes. Server-provided data must not be reused after logout or
account switching.

## Mobile changes in this checkout

- Updated the Dart package name to `cds_smart_mobile`, affected package
  imports, visible branding, and Android/iOS display labels.
- Replaced the BMS app entry point with a green CDS-SMART mobile shell. The
  shell explains that backend integration is pending and shows the verified
  Incoming, Outgoing, and History definitions without invented records.
- Added source-shaped routing and MOV-review event models and tests that keep
  custody office/event fields separate from review verdict/remarks.
- Removed the prior technical-report client, fake `/api/mobile` request paths,
  and report-only screen/models. They targeted the older local `cds-system`
  snapshot and are not compatible with verified `origin/main`.
- Android `namespace`/`applicationId`, iOS bundle identifier, signing,
  Firebase identity/configuration, and existing app registrations were not
  changed. Review these separately before release; changing them can affect
  installed copies and service registrations.

### Existing web changes pending review

The following 12 task-created files remain in the `cds-system` checkout,
unstaged/uncommitted and **not approved as the mobile backend**:

1. `app/Http/Controllers/Api/MobileAuthController.php` — temporary
   Sanctum login/profile/logout.
2. `app/Http/Controllers/Api/MobileTechnicalReportController.php` — temporary
   technical-report endpoints, counts, detail, and attachment.
3. `app/Http/Middleware/EnsureMobileTechnicalReportsAccess.php` — temporary
   technical-report token/account/section/permission gate.
4. `app/Http/Middleware/PreventMobileApiCaching.php` — cache-control headers.
5. `routes/api.php` — temporary `/api/mobile` routes.
6. `bootstrap/app.php` — registers the API route file.
7. `app/Models/User.php` — Sanctum token trait and formatting change.
8. `app/Models/TechnicalReport.php` — due-date cast and formatting change.
9. `composer.json` — Sanctum dependency.
10. `composer.lock` — corresponding Sanctum lock update.
11. `database/migrations/2026_10_12_125702_create_personal_access_tokens_table.php`
    — token table migration; not run.
12. `tests/Feature/MobileTechnicalReportsApiTest.php` — tests for that
    temporary technical-report API.

Preserve these changes pending owner review. They have not been reverted,
committed, or pushed. Their focused API tests previously passed against the
temporary implementation and isolated test database; this does not validate
compatibility with the fetched CDS-SMART source or authorize use of the API.

## Legacy BMS preservation

The BMS starting commit `82e0e7b87ba7385c5a4a99a14ebe800bc2d8ef2e` remains in
Git history. Existing SQLite schema, Hive box definitions, photos, offline
map data, Firebase resources/configuration, and Cloudinary integration source
were not deleted, migrated, or overwritten. The CDS-SMART entry point does not
initialize those legacy stores or integrations. No device database, Hive box,
photo, map, or cloud data was accessed or cleaned.

## Setup and connection configuration

Flutter/Dart, JDK, Android SDK, and a device/emulator were unavailable during
the prior toolchain check. Install Flutter stable, JDK 17, and Android Studio
with its Android SDK; then run:

```powershell
flutter doctor -v
flutter doctor --android-licenses
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

The current shell does not call a server. When a mobile API is implemented and
authorized in a separate development copy, configure its origin explicitly.
For a host Laravel development server, Android Emulator uses
`http://10.0.2.2:<port>`; a physical device needs the development computer’s
reachable LAN IP. `localhost` on a phone is the phone itself. Do not assume
Windows hostnames resolve from Android. No firewall/network configuration,
live-data connection, or server request was made.

The active workspace remains `C:\laragon\www\bms-inventory`; no folder rename
was attempted. After closing the workspace, run this from the parent directory
only if the destination is still absent:

```powershell
Set-Location 'C:\laragon\www'
Rename-Item -LiteralPath '.\bms-inventory' -NewName 'cds-smart-mobile'
```

## Verification and remaining scope

- Read-only Git inspection verified the fetched `origin/main` workflow,
  routing, organizational access, notification, and web route source.
- Routing-queue/event model tests were added but not executed because Flutter
  and Dart were unavailable. Formatting, analysis, Android build, device
  behavior, authorization-boundary tests against mobile APIs, and actual
  document/notification rendering remain unverified.
- The previous Laravel test results cover only the temporary API changes listed
  above, not the verified mobile integration. No backend command, migration,
  production connection, push, or deployment was performed during this
  continuation.
- Sign-in/session handling, authorized dashboard counts, search and filters,
  queue data, detail and attachment previews, notifications, profile/logout,
  loading/error/expired states, and mobile API tests remain unfinished pending
  a separate development copy and a reviewed server API contract.
- Continue only on `feature/cds-smart-mobile-refactor`; before staging,
  committing, or pushing, verify this Git root and
  `jayarcaldelero26-jpg/bms_inventory` origin, inspect the exact staged diff
  for secrets/unrelated files, and never push to `main`.
