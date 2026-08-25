# SmartGrade

SmartGrade is a responsive Flutter + Supabase teacher grading and class-record system. This repository now contains the Phase 1 foundation: Supabase email/password authentication, per-teacher classes, per-class rosters, quiz assessment items, spreadsheet-style score entry, debounced upserts, transparent grade calculations, PostgreSQL migrations, RLS policies, an Edge Function boundary for Google Classroom, tests, and CI.

## Current phase

Implemented:

- Flutter web, Windows-ready, and responsive application source
- Supabase authentication client
- Teacher-owned class creation and class cards
- Dedicated per-class gradebook route with browser-back support
- Roster, assessment, and score queries
- Keyboard score entry, validation, automatic totals, and autosave
- Normalized Phase 1 database schema
- RLS policies that isolate each teacher's classes
- Unit tests for grade calculations
- GitHub Actions checks

Next:

- Class/student import wizard for CSV and Excel
- Category configuration and Summary tab
- Attendance and reports
- Google OAuth, roster/coursework synchronization, and conflict resolution
- Offline change queue and audit triggers

## Run locally

1. Install Flutter stable and enable the platforms you need:

   ```bash
   flutter config --enable-web
   flutter config --enable-windows-desktop
   ```

   If this is your first checkout, generate Flutter's platform runner folders once:

   ```bash
   flutter create --platforms=web,windows,android .
   ```

2. Create a Supabase project.
3. Run `supabase/migrations/202608250001_initial_smartgrade.sql` in the Supabase SQL Editor.
4. In Authentication, create a teacher account. Insert its profile using the same user UUID:

   ```sql
   insert into public.profiles (id, full_name, role)
   values ('AUTH_USER_UUID', 'Teacher Name', 'teacher');
   ```

5. Install dependencies and run:

   ```bash
   flutter pub get
   flutter run -d chrome \
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
     --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
   ```

For Windows, replace `-d chrome` with `-d windows`.

## Security

- Use only the Supabase publishable key in Flutter.
- Never commit the secret/service-role key or Google OAuth credentials.
- RLS is enabled on all exposed tables.
- Authorization uses database ownership, not editable user metadata.
- The Classroom function validates the authenticated user and class ownership before any future synchronization work.

## Google Classroom

The included Edge Function deliberately returns `configuration_required`. Production synchronization requires a Google Cloud project, Classroom API enablement, OAuth consent setup, approved minimum scopes, secure server-side token storage, and sometimes Google Workspace administrator approval.

## Architecture

```text
Flutter UI → Supabase Auth → PostgREST + RLS → PostgreSQL
          → Edge Functions → Google OAuth/Classroom API
```

The app never receives a Supabase secret key or Google refresh token.
