import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../utils/ui_components.dart';
import 'progress_screen.dart';
import 'query_screen.dart';
import 'quiz_screen.dart';
import 'review_screen.dart';
import 'upload_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.apiClient,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final ApiClient apiClient;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with TickerProviderStateMixin {
  final _authService = AuthService();
  ContinueSessionModel? _continueState;
  bool _loadingSession = true;
  late AnimationController _listAnimController;
  late List<Animation<double>> _itemAnimations;

  @override
  void initState() {
    super.initState();
    _loadSession();
    
    // Setup staggered list animation
    _listAnimController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _itemAnimations = List.generate(
      6,
      (index) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _listAnimController,
          curve: Interval(
            index * 0.12,
            index * 0.12 + 0.6,
            curve: AppCurves.snappy,
          ),
        ),
      ),
    );

    _listAnimController.forward();
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    setState(() => _loadingSession = true);
    try {
      debugPrint('[HomeShell] Testing backend connection...');
      await widget.apiClient.testConnection();
      debugPrint('[HomeShell] Backend connection OK, fetching session...');

      final continueState = await widget.apiClient.getContinueSession();
      if (!mounted) {
        return;
      }
      setState(() {
        _continueState = continueState;
      });
    } catch (e) {
      debugPrint('[HomeShell] Session load failed: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _continueState = ContinueSessionModel(
          lastDocumentId: null,
          lastQuizId: null,
          lastAction: 'dashboard',
          lastActionAt: null,
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSession = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: _buildAppBar(isDark),
      body: Container(
        color: isDark ? AppColors.scrimDark : AppColors.scrim,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ┌─ Hero Section ────────────────────────────────────────┐
            _buildHeroSection(),

            // ┌─ Continue Session Card ────────────────────────────────┐
            if (!_loadingSession) _buildContinueCard(_itemAnimations[0]),

            // ┌─ Learning Mode Cards ──────────────────────────────────┐
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: SectionHeader(
                title: 'Learn Today',
                showDivider: true,
              ),
            ),
            ..._buildLearningModeCards(),
          ],
        ),
      ),
    );
  }

  // ┌─────────────────────────────────────────────────────────────────┐
  // │ BUILD METHODS
  // ┌─────────────────────────────────────────────────────────────────┐

  PreferredSizeWidget _buildAppBar(bool isDark) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'User';
    final letter = email.isEmpty ? '?' : email[0].toUpperCase();

    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? AppColors.cardBgDark : Colors.white,
      toolbarHeight: 72,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quizify',
            style: AppTypography.displaySmall.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Your AI Study Companion',
            style: AppTypography.bodySmall.copyWith(
              color: isDark ? AppColors.secondary.withValues(alpha: 0.7) : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: widget.onToggleTheme,
          icon: Icon(
            widget.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: isDark ? AppColors.secondary : AppColors.primary,
          ),
          tooltip: widget.isDarkMode ? 'Light mode' : 'Dark mode',
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            onPressed: _showProfileSheet,
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
              child: Text(
                letter,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
            AppColors.secondary.withValues(alpha: 0.4),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Ready to\n',
                  style: AppTypography.displayLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: 'master your topics?',
                  style: AppTypography.displayLarge.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'AI-powered quizzes, instant explanations, and personalized insights to accelerate your learning.',
            style: AppTypography.body.copyWith(
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueCard(Animation<double> animation) {
    final state = _continueState;
    if (state == null || (state.lastDocumentId == null && state.lastQuizId == null)) {
      return const SizedBox.shrink();
    }

    final timeText = state.lastActionAt == null
        ? 'Earlier'
        : DateFormat.jm().format(state.lastActionAt!.toLocal());
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: animation.drive(
          Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: ElevatedFeatureCard(
            backgroundColor: AppColors.accent.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Continue Session',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Last: ${state.lastAction} • $timeText',
                  style: AppTypography.body.copyWith(
                    color: isDark ? Colors.white.withValues(alpha: 0.75) : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLearningModeCards() {
    final modeData = [
      (
        title: 'Upload Documents',
        subtitle: 'PDF, images, or notes to build your learning base.',
        icon: Icons.upload_file_rounded,
        accent: const Color(0xFF7C3AED),
        screen: UploadScreen(apiClient: widget.apiClient),
        index: 1,
      ),
      (
        title: 'Generate Quiz',
        subtitle: 'Adaptive MCQ, fill-blanks, and short answers.',
        icon: Icons.quiz_outlined,
        accent: const Color(0xFF06B6D4),
        screen: QuizScreen(
          apiClient: widget.apiClient,
          initialDocumentId: _continueState?.lastDocumentId,
        ),
        index: 2,
      ),
      (
        title: 'Ask Questions',
        subtitle: 'Get mentor-like guidance on any topic.',
        icon: Icons.help_center_outlined,
        accent: const Color(0xFF14B8A6),
        screen: QueryScreen(
          apiClient: widget.apiClient,
          initialDocumentId: _continueState?.lastDocumentId,
        ),
        index: 3,
      ),
      (
        title: 'Review & Analyze',
        subtitle: 'AI insights on weak topics and progress.',
        icon: Icons.analytics_outlined,
        accent: const Color(0xFFF59E0B),
        screen: ReviewScreen(
          apiClient: widget.apiClient,
          initialDocumentId: _continueState?.lastDocumentId,
        ),
        index: 4,
      ),
      (
        title: 'Your Progress',
        subtitle: 'Detailed analytics and activity history.',
        icon: Icons.trending_up_rounded,
        accent: const Color(0xFFEC4899),
        screen: ProgressScreen(apiClient: widget.apiClient),
        index: 5,
      ),
    ];

    return modeData.map((mode) {
      return FadeTransition(
        opacity: _itemAnimations[mode.index],
        child: SlideTransition(
          position: _itemAnimations[mode.index].drive(
            Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LearningModeCard(
              title: mode.title,
              subtitle: mode.subtitle,
              icon: mode.icon,
              accentColor: mode.accent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => mode.screen),
                ).then((_) {
                  _loadSession();
                });
              },
            ),
          ),
        ),
      );
    }).toList();
  }

  Future<void> _showProfileSheet() async {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Unknown email';
    final initial = email.isEmpty ? '?' : email[0].toUpperCase();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                    child: Text(
                      initial,
                      style: AppTypography.displaySmall.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                ),
                title: Text(
                  'Sign Out',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.error,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _authService.signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
