# Quizify Mobile

Flutter mobile app for Quizify with:
- Email sign-up/sign-in via Supabase Auth
- Google sign-in via Supabase + google_sign_in
- Authenticated API calls to FastAPI backend

## Environment

Create `frontend-mob/.env` with:

```env
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<supabase-anon-key>
BACKEND_BASE_URL=http://10.0.2.2:8000
GOOGLE_WEB_CLIENT_ID=<google-web-oauth-client-id>
GOOGLE_IOS_CLIENT_ID=<google-ios-oauth-client-id>
AUTH_REDIRECT_SCHEME=quizify
# Optional override for reset links
# PASSWORD_RESET_REDIRECT_URL=quizify://reset-password
```

Notes:
- Android emulator should use `http://10.0.2.2:8000` for local backend.
- iOS simulator should use `http://localhost:8000`.
- Physical devices must use your machine LAN IP and matching backend CORS settings.

Password reset callback setup:
- Add `quizify://reset-password` to Supabase Auth Redirect URLs.
- Keep `AUTH_REDIRECT_SCHEME` in `.env` aligned with native app URL scheme.
- Open reset links on the same device where the app is installed.

## Google Sign-In Setup

1. In Supabase, enable Google provider in Auth settings.
2. Use OAuth credentials from the same Google Cloud project connected to Supabase.
3. Add Android package and SHA-1/SHA-256 fingerprints in Google Cloud.
4. Add iOS bundle id in Google Cloud.
5. Place native config files:
	- `frontend-mob/android/app/google-services.json`
	- `frontend-mob/ios/Runner/GoogleService-Info.plist`
6. Ensure `.env` has valid `GOOGLE_WEB_CLIENT_ID` and `GOOGLE_IOS_CLIENT_ID`.

## Run

```bash
flutter pub get
flutter run
```

## Auth Flow Checks

1. Create account with email/password.
2. Confirm email (if Supabase email confirmation is enabled).
3. Sign in with email/password.
4. Sign in with Google.
5. Verify authenticated screens load and backend requests include bearer token.
