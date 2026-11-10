# QR Studio — Android App

QR Studio is a Persian-first Flutter Android app for managing product records and generating stable product QR links.

## Download the Android APK
Open [GitHub Actions](https://github.com/alimokhtari3900-source/qr-studio/actions/workflows/android-apk.yml), open the latest successful **Build Android APK** run, and download the `QR-Studio-Android-APK` artifact. It contains `QR-Studio.apk`.

## Install on Android
1. Download and extract the artifact ZIP.
2. Tap `QR-Studio.apk` on your phone.
3. Allow installation from this source when Android prompts you.
4. Open QR Studio.

## Connect the backend
Add these repository Variables under Settings → Secrets and variables → Actions → Variables:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` (Supabase publishable/anon key; never the service_role key)
- `PUBLIC_SITE_URL`

Run `supabase/migrations/202611100001_initial_schema.sql` in the Supabase SQL Editor. Create a manager user in Supabase Authentication, then add that user's UUID to `public.admin_users`.

Without those settings the APK still installs, but shows the setup guidance instead of enabling sign-in and product storage. This repository does not include a live Supabase project.

## Safety
The app never embeds a service-role key. Do not add it to GitHub Variables, app source, or client builds.
