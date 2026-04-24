import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_env.dart';

class SignUpResult {
  const SignUpResult({
    required this.needsConfirmation,
    required this.likelyExistingUser,
  });

  final bool needsConfirmation;
  final bool likelyExistingUser;
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (password != confirmPassword) {
      throw Exception('Passwords do not match');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );
    if (response.session != null) {
      return const SignUpResult(
        needsConfirmation: false,
        likelyExistingUser: false,
      );
    }

    final identities = response.user?.identities ?? const [];
    final hasNonEmailIdentity = identities.any((id) => id.provider != 'email');
    return SignUpResult(
      needsConfirmation: true,
      likelyExistingUser: hasNonEmailIdentity,
    );
  }

  Future<void> resendSignUpConfirmation({required String email}) async {
    await _supabase.auth.resend(type: OtpType.signup, email: email);
  }

  bool hasActiveSession() {
    return _supabase.auth.currentSession != null;
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      // On web, use Supabase's OAuth redirect — no google_sign_in package needed.
      // The user must configure Google as an OAuth provider in the Supabase dashboard
      // and add the app origin to Supabase Auth > Redirect URLs.
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.toString(),
      );
      return;
    }

    // Native mobile: use the google_sign_in ID-token flow.
    final configIssue = AppEnv.googleNativeConfigurationIssue(
      defaultTargetPlatform,
    );
    if (configIssue != null) {
      throw Exception(configIssue);
    }

    try {
      final signIn = GoogleSignIn(
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? AppEnv.googleIosClientId
            : null,
        serverClientId: AppEnv.googleWebClientId,
        scopes: const ['email', 'profile'],
        forceCodeForRefreshToken: true,
      );

      final googleUser = await signIn.signIn();
      if (googleUser == null) {
        // User cancelled sign in
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception(
          'Google sign in failed: missing ID token. Verify Google OAuth setup and check:  \n'
          '- Google Cloud Console: Ensure OAuth 2.0 credentials are set up\n'
          '- iOS: GoogleService-Info.plist configured\n'
          '- Android: SHA-1 fingerprint registered and google-services.json updated\n'
          '- GOOGLE_WEB_CLIENT_ID env var set correctly',
        );
      }

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      if (e.toString().contains('User cancelled')) {
        rethrow;
      }
      throw Exception('Google sign in error: $e');
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
