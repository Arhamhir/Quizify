import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required.');
      return;
    }

    if (_isSignUp && confirmPassword.isEmpty) {
      setState(() => _error = 'Please confirm your password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });
    try {
      if (_isSignUp) {
        if (password != confirmPassword) {
          setState(() => _error = 'Passwords do not match.');
          return;
        }
        final result = await _authService.signUpWithEmail(
          email: email,
          password: password,
          confirmPassword: confirmPassword,
        );
        if (!mounted) {
          return;
        }
        if (result.likelyExistingUser) {
          setState(() {
            _error =
                'This email is already registered or waiting for confirmation. Try Sign In or resend confirmation.';
          });
        } else if (result.needsConfirmation) {
          setState(() {
            _successMessage =
                'Account created. Check inbox/spam for confirmation email, then sign in.';
          });
        } else {
          setState(() {
            _successMessage = 'Account created and signed in.';
          });
        }
      } else {
        await _authService.signInWithEmail(email: email, password: password);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _friendlyAuthError(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _friendlyAuthError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('over_email_send_rate_limit') ||
        lower.contains('email rate limit') ||
        lower.contains('429')) {
      return 'Email rate limit exceeded. You sent too many emails in a short time. Wait 1 hour and try again with a different email address.';
    }
    if (lower.contains('timeout') || lower.contains('connection')) {
      return 'Connection timeout. Verify backend is running on 10.0.2.2:8000 and your firewall allows it.';
    }
    if (lower.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (lower.contains('email not confirmed') ||
        lower.contains('email_not_confirmed')) {
      return 'Email not confirmed yet. Use Resend confirmation and check inbox/spam.';
    }
    if (lower.contains('signups not allowed')) {
      return 'Email signups are disabled in Supabase Auth settings.';
    }
    if (lower.contains('password')) {
      return 'Password must satisfy Supabase policy (usually at least 6 characters).';
    }
    if (lower.contains('user already exists')) {
      return 'This email is already registered. Try signing in instead.';
    }
    if (lower.contains('passwords do not match')) {
      return 'Passwords do not match. Please try again.';
    }
    return error;
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });
    try {
      debugPrint('[Auth] Starting Google sign in...');
      await _authService.signInWithGoogle();
      debugPrint('[Auth] Google sign in succeeded');
    } catch (e) {
      debugPrint('[Auth] Google sign in failed: $e');
      if (!mounted) {
        return;
      }
      setState(() => _error = _friendlyAuthError(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D3B66),
                  Color(0xFF2A9D8F),
                  Color(0xFFF4A259),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quizify',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSignUp
                              ? 'Create your account'
                              : 'Sign in to continue learning',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                        ),
                        if (_isSignUp) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirm Password',
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _submit,
                            child: Text(
                              _isSignUp ? 'Create Account' : 'Sign In',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _googleSignIn,
                            icon: const Icon(Icons.public_rounded),
                            label: const Text('Continue with Google'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isSignUp
                                  ? 'Already have an account?'
                                  : 'New user?',
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(() {
                                      _isSignUp = !_isSignUp;
                                    }),
                              child: Text(_isSignUp ? 'Sign In' : 'Sign Up'),
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        if (_successMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _successMessage!,
                            style: const TextStyle(color: Colors.green),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
