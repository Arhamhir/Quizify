import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String get supabaseUrl => (dotenv.env['SUPABASE_URL'] ?? '').trim();
  static String get supabaseAnonKey => (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();
  static String get backendBaseUrl {
    final configured = dotenv.env['BACKEND_BASE_URL']?.trim() ?? '';
    if (configured.isNotEmpty) {
      return configured;
    }
    return kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
  }

  static String get googleWebClientId => (dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '').trim();

  static String get googleIosClientId => (dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '').trim();

  static String get authRedirectScheme {
    final configured = (dotenv.env['AUTH_REDIRECT_SCHEME'] ?? '').trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    return 'quizify';
  }

  static String get passwordResetRedirectUrl {
    final configured = (dotenv.env['PASSWORD_RESET_REDIRECT_URL'] ?? '').trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    if (kIsWeb) {
      return Uri.base.toString();
    }
    return '$authRedirectScheme://reset-password';
  }

  static List<String> criticalIssues() {
    final issues = <String>[];
    if (supabaseUrl.isEmpty) {
      issues.add('SUPABASE_URL is missing in .env');
    }
    if (supabaseAnonKey.isEmpty) {
      issues.add('SUPABASE_ANON_KEY is missing in .env');
    }
    if (backendBaseUrl.isEmpty) {
      issues.add('BACKEND_BASE_URL is missing in .env');
    }
    return issues;
  }

  static String? googleNativeConfigurationIssue(TargetPlatform platform) {
    if (googleWebClientId.isEmpty) {
      return 'Google sign-in is not configured. Add GOOGLE_WEB_CLIENT_ID to .env.';
    }
    if (platform == TargetPlatform.iOS && googleIosClientId.isEmpty) {
      return 'Google sign-in for iOS is not configured. Add GOOGLE_IOS_CLIENT_ID to .env.';
    }
    return null;
  }
}
