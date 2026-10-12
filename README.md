# CDS-SMART Mobile

Flutter mobile shell for CDS-SMART Submission Tracking. The current reference
backend has no mobile-authenticated API, so this build does not sign in or load
records. It displays verified Incoming, Outgoing, and History definitions
without placeholder documents.

See [the migration and setup guide](docs/cds-smart-mobile-refactor.md) for the
verified web source, required API contract, preserved BMS data, and setup.

Once Flutter is installed, run the API-independent shell with:

```powershell
flutter run
```
