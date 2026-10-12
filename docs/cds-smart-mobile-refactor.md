# CDS-SMART Mobile refactor

## Status

**PARTIAL — backend source verified; mobile API and runtime remain blocked.**
The normal mobile screen is an API-independent shell for the verified
Submission Tracking concepts. An explicitly enabled demo screen exercises
fictional local records and in-memory notification state. Neither mode
authenticates, requests, caches, or displays CDS records. The earlier technical-report client and its assumed
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
| Incoming | Active, incomplete records requiring an action; the service projects the canonical queues and current action category. The page describes this as requiring action from the user’s office. | Definition shown; fictional queue preview; authorized data integration pending. |
| Outgoing | Incomplete records acted on/forwarded by the office and not also currently in its Incoming queue. | Definition shown; fictional queue preview; authorized data integration pending. |
| History | Completed routing records within the user’s authorized scope, ordered by completion/update time. | Definition shown; fictional queue preview; authorized data integration pending. |
| Custody and timeline | `document_routing_events` records workflow/event, stages, from/to offices, timestamp, actor, remarks, and metadata; routing snapshots also exist. | Typed routing-event model and fictional detail preview; API pending. |
| MOV review | `PambMovReviewEvent` is separate from routing events. A verdict such as `needs_correction` does not itself establish a new custody office; a return/transfer is represented as routing. | Separate typed review-event model and fictional review history preview; API pending. |
| Organizational authorization | Tracking checks the tracking permission and source ability, then global status, actor category, organizational unit, office and protected-area scope. Global users have a distinct queue projection. | Must be enforced and re-evaluated by the backend on every mobile request. Client-side role filtering is not an authorization boundary. |
| Notifications | User-owned database notifications include read timestamps. Web routes list/recent, mark read/unread, mark all read, and clear; recent bell entries are limited to unread due-soon/overdue/workflow types. | Fictional, in-memory read/unread preview; API pending. |
| Search, details, attachments | Web tracking is an authenticated Inertia page. Attachment routes require the web session and tracking permission; the protected preview resolves server-side paths. | Fictional search/filter/page/detail preview. Real attachment preview awaits a protected API response. |

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
- Added an opt-in fictional demo using `CDS_DEMO_MODE=true`: overview counts,
  four-section mobile navigation, queue search/source filtering/pagination,
  detail/custody/routing/review views, an attachment placeholder, profile,
  and in-memory notification read/unread controls. The demo is compile-time
  selected; API failures can never silently switch to these fixtures.
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

Android-only toolchain installed from the official Flutter, Eclipse Temurin,
and Android command-line tool distributions:

- Flutter 3.47.7 stable with Dart 3.13.5 at
  `C:\Users\USER\dev\flutter`.
- Eclipse Temurin JDK 17.0.20.1 at `C:\Users\USER\dev\jdk17`.
- Android command-line tools revision 22.0 at
  `C:\Users\USER\AppData\Local\Android\Sdk\cmdline-tools\latest`.
- Flutter is configured to use
  `C:\Users\USER\AppData\Local\Android\Sdk`.
- Android Studio was not needed for the CLI setup and was not installed.
- Android platform/build tools, NDK, emulator, and API 36 system image are
  still pending because the configured SDK reports its licenses unaccepted.
  No emulator or Android device is currently available to Flutter.

Official setup references: [Flutter SDK archive](https://docs.flutter.dev/install/archive),
[Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup),
[Android command-line tools](https://developer.android.com/tools), and
[Android Emulator setup](https://developer.android.com/studio/run/emulator).

After Android SDK licenses are accepted in an interactive PowerShell, install
the project-compatible platform and emulator packages:

```powershell
$sdk = 'C:\Users\USER\AppData\Local\Android\Sdk'
& "$sdk\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="$sdk" --licenses
```

Accept each displayed agreement in that interactive terminal. Then install the
packages:

```powershell
$sdk = 'C:\Users\USER\AppData\Local\Android\Sdk'
& "$sdk\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="$sdk" --install `
  'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' `
  'ndk;28.2.13676358' 'emulator' `
  'system-images;android-36;google_apis;x86_64'
```

Then open a new terminal so the user-level `PATH`, `JAVA_HOME`, `ANDROID_HOME`,
and `ANDROID_SDK_ROOT` settings are loaded. Run:

```powershell
flutter doctor -v
flutter pub get
dart format lib/cds_smart/demo_data.dart lib/cds_smart/demo_screens.dart test/cds_smart_models_test.dart test/cds_smart_demo_widget_test.dart
flutter analyze lib/cds_smart test/cds_smart_models_test.dart test/cds_smart_demo_widget_test.dart
flutter test test/cds_smart_models_test.dart test/cds_smart_demo_widget_test.dart
flutter build apk --debug --dart-define=CDS_DEMO_MODE=true
```

The demo has no server connection. When APIs are implemented and authorized in
a separate development copy, configure the origin explicitly. For a host
Laravel development server, Android Emulator uses `http://10.0.2.2:<port>`; a
physical device needs the development computer’s reachable LAN IP. No
firewall/network configuration, live-data connection, or server request was
made.

Exact opt-in demo command:

```powershell
flutter run --dart-define=CDS_DEMO_MODE=true
```

The debug APK destination, once the Android SDK packages are installed and the
build succeeds, is `build\app\outputs\flutter-apk\app-debug.apk`. That APK has
not been produced yet.

The `DEMO` banner and sample references identify fictional content. The
normal `flutter run` starts the integration-pending shell. The demo has no
login, persistent session, token, account cache, attachment bytes, or network
fallback. Its sample profile is not an authenticated user.

The active workspace remains `C:\laragon\www\bms-inventory`; no folder rename
was attempted.

## Verification and remaining scope

- `flutter pub get` completed successfully. `dart format` completed with no
  remaining changes across the edited CDS demo and tests.
- Focused `flutter analyze lib/cds_smart test/cds_smart_models_test.dart
  test/cds_smart_demo_widget_test.dart` passed with no issues.
- The full `flutter analyze --no-pub` completed with 104 info-level findings in
  legacy BMS files. None were in `lib/cds_smart`; the focused CDS analysis is
  clean. The prior toolchain blocker prevented a pre-change full-analysis
  baseline, so the earlier finding count is unknown.
- Six focused model and widget tests pass. The widget tests exercise tracking
  navigation, pagination, search, current custody, separate routing/review
  history, and in-memory notification read state.
- `flutter doctor -v` finds Flutter and Windows, but not an Android SDK
  installation with platform packages. SDK Manager reports 8 of 8 licenses
  unaccepted and has not created its `licenses` files. Therefore Android
  platform/build tools, NDK, emulator, and system image were not installed.
- No Android debug APK was compiled and no emulator/device behavior was
  verified. Source/widget test success is not Android compilation or device
  proof. Visual Studio is absent, as expected for this Android-only task.
- Existing Android namespace/application ID, signing, Firebase identity/config,
  and BMS storage were not changed. The existing
  `android/app/google-services.json` is present and untouched.
- No Laravel command, migration, live service, production account, or backend
  integration was used. Real sign-in/session handling, authorized dashboard
  counts, server-backed queues, details, attachments, notifications,
  profile/logout, and loading/error/offline/expired API states remain pending
  a reviewed mobile API contract.
- The previous Laravel test results cover only the temporary API changes listed
  above, not the verified mobile integration. No backend command, migration,
  production connection, push, or deployment was performed during this
  continuation.
- Real sign-in/session handling, authorized dashboard counts, queue data,
  search/filter/page results, details, attachment previews, notifications,
  profile/logout, loading/error/offline/expired states, and mobile API tests
  remain unfinished pending a reviewed server API contract. The next concrete
  step for this mobile task is to persist acceptance of the Android SDK licenses,
  install the listed packages, build the APK, and run the opt-in demo on a fresh
  emulator. Backend API implementation and live integration require separate
  authorization and are outside this verification task.
- Continue only on `feature/cds-smart-mobile-refactor`; before staging,
  committing, or pushing, verify this Git root and
  `jayarcaldelero26-jpg/bms_inventory` origin, inspect the exact staged diff
  for secrets/unrelated files, and never push to `main`.
