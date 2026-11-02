# Bahir Dar University - Multi-Zone Campus Maintenance & Repair Dispatch System

## Overview
This repository contains the complete source code for the Multi-Zone Campus Infrastructure Maintenance and Repair Dispatch System designed for Bahir Dar University.

### Structure:
- `/backend`: Supabase PostgreSQL schema, Row Level Security (RLS) policies, and trigger migrations.
- `/mobile_app`: Flutter cross-platform mobile client application for students, faculty, and field technicians.
- `/web_admin`: Next.js 14 App Router administrative portal for dispatchers and maintenance supervisors.

## Getting Started

### 1. Supabase
1. Create a Supabase project and run `backend/supabase_schema.sql` once in the SQL Editor.
2. Add campus buildings to `public.zones`; the mobile reporter only submits against registered zones.
3. If the schema is already installed, run `backend/migrations/20261031_add_optional_ticket_coordinates.sql` to add optional map coordinates safely.
4. Create Auth users for residents, dispatchers, and technicians, then add a matching `public.profiles` row for each user. Set each technician's `department`, `email`, and optional `phone_number`; dispatcher pages use these fields for trade and contact actions.
5. The schema creates the private `hazard-photos` bucket and upload/read policies.

#### University Email Verification (OTP)
The mobile app only accepts `@bdu.edu.et` emails and verifies them with a 6-digit OTP code. Configure Supabase Auth email templates to include `{{ .Token }}` and follow **[backend/BDU_OUTLOOK_MICROSOFT365_SETUP.md](backend/BDU_OUTLOOK_MICROSOFT365_SETUP.md)** for BDU's Microsoft 365 mail system.

### 2. Flutter Mobile App
From `mobile_app`, copy `supabase.local.example.json` to `supabase.local.json`, fill in your project URL and public key, then run:

```sh
flutter pub get
flutter run --dart-define-from-file=supabase.local.json
```

Use the Supabase project URL and a public publishable (or legacy anon) key in those Dart defines. Never embed a `service_role` or secret key in the mobile app. Students can register, verify university email by code, recover passwords by code, and sign in; the app reads and tracks only the signed-in user's requests. Without both Dart defines, the app runs in demo mode.
Coordinates are optional and entered only when known; campus, zone, building, and room remain the primary location. The admin portal opens a supplied coordinate in Google Maps without requiring a Maps API key. Technician email links open the user's configured mail app; automated email delivery is not included.

### 3. Next.js Dispatcher Portal
From `web_admin`, copy `.env.example` to `.env.local`, set the Supabase project URL and public publishable (or legacy anon) key, then run. Configure the Supabase Auth Site URL and redirect allowlist for the admin origin to enable password reset links.

```sh
npm install
npm run dev
```

The portal starts at `http://localhost:3000`. Without `.env.local`, it shows sample queue data; dispatch edits in demo mode last only for the current browser session. With Supabase configured, sign in with a dispatcher/admin account to load and assign real requests.

## Project Scope

Included: fault reporting, photo upload, multi-zone location, priority triage, technician assignment, status tracking, and role-based access. Inventory deductions and financial/PDF reporting are intentionally excluded. The admin portal is dispatcher-focused; user acceptance feedback, formal black-box/response-time testing, and production APK signing remain deployment/evaluation tasks.
