import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/api_client.dart';
import 'core/app_env.dart';
import 'core/app_theme.dart';
import 'screens/auth_page.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env is expected to be bundled as a Flutter asset via pubspec.yaml.
  }

  final startupIssues = AppEnv.criticalIssues();
  if (startupIssues.isNotEmpty) {
    runApp(StartupErrorApp(issues: startupIssues));
    return;
  }

  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );

  final session = Supabase.instance.client.auth.currentSession;
  debugPrint('[App Init] Supabase initialized. Session exists: ${session != null}');
  if (session != null) {
    debugPrint('[App Init] User ID: ${session.user.id}, Token expires: ${session.expiresAt}');
  }

  runApp(QuizifyApp(apiClient: ApiClient(baseUrl: AppEnv.backendBaseUrl)));
}

class QuizifyApp extends StatefulWidget {
  const QuizifyApp({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<QuizifyApp> createState() => _QuizifyAppState();
}

class _QuizifyAppState extends State<QuizifyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quizify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session == null) {
            return const AuthPage();
          }
          return HomeShell(
            apiClient: widget.apiClient,
            isDarkMode: _themeMode == ThemeMode.dark,
            onToggleTheme: _toggleTheme,
          );
        },
      ),
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.issues});

  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quizify Setup Error',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Missing environment setup',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text('Update frontend-mob/.env with the required values:'),
                const SizedBox(height: 10),
                ...issues.map((issue) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('- $issue'),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
