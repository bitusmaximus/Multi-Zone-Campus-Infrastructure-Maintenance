# BDU Campus Maintenance

Flutter app for reporting and tracking Bahir Dar University campus maintenance requests.

## Run with Supabase

From this directory, copy `supabase.local.example.json` to the ignored `supabase.local.json`, then enter the project URL and a public Supabase publishable key (or legacy anon key):

```sh
flutter pub get
flutter run --dart-define-from-file=supabase.local.json
```

Never use a Supabase `service_role` or secret key in a mobile app. The app requires both values; if neither is supplied, it starts in demo mode. Supplying only one is treated as a configuration error.

For student registration and password recovery codes, configure Supabase Auth email templates to include `{{ .Token }}` and configure SMTP delivery. See [the SMTP setup guide](../backend/SUPABASE_SMTP_SETUP.md).

## App identity

The Flutter package identifier is `bdu_campus_maintenance`; the user-facing app name is **BDU Campus Maintenance**.
