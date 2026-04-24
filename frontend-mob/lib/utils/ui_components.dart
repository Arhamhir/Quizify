import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// ============================================================================
/// REUSABLE UI COMPONENTS FOR THE NEW DESIGN SYSTEM
/// ============================================================================
/// Use these throughout the app for visual consistency and motion.

/// A custom progress indicator card with gradient fill and animated updates
class GradientProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String label;
  final Color color;
  final double size;

  const GradientProgressIndicator({
    Key? key,
    required this.progress,
    required this.label,
    this.color = AppColors.secondary,
    this.size = 80,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background ring
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.15),
                    width: 4,
                  ),
                ),
              ),
              // Progress ring (using CustomPainter would be more advanced)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 800),
                curve: AppCurves.snappy,
                builder: (context, value, child) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color,
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${(value * 100).toStringAsFixed(0)}%',
                        style: AppTypography.displaySmall.copyWith(
                          color: color,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Elevated card with subtle border and shadow
class ElevatedFeatureCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const ElevatedFeatureCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: backgroundColor ?? (isDark ? AppColors.cardBgDark : AppColors.cardBg),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.border,
              width: 1,
            ),
            boxShadow: isDark ? AppShadows.softDark : AppShadows.soft,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Mode selection card for home screen (Quiz, Query, etc.)
class LearningModeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;

  const LearningModeCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accentColor = AppColors.secondary,
  }) : super(key: key);

  @override
  State<LearningModeCard> createState() => _LearningModeCardState();
}

class _LearningModeCardState extends State<LearningModeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.snappy),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ElevatedFeatureCard(
          padding: EdgeInsets.zero,
          backgroundColor: isDark ? AppColors.cardBgDark : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top colored header
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: widget.accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.accentColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: AppTypography.headlineSmall.copyWith(
                              color: isDark ? Colors.white.withValues(alpha: 0.95) : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.subtitle,
                      style: AppTypography.body.copyWith(
                        color: isDark ? Colors.white.withValues(alpha: 0.75) : AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Answer feedback panel (correct/wrong) with custom styling
class AnswerFeedbackPanel extends StatelessWidget {
  final bool isCorrect;
  final String userAnswer;
  final String correctAnswer;
  final String? explanation;
  final VoidCallback? onAskReason;
  final bool isLoadingReason;

  const AnswerFeedbackPanel({
    Key? key,
    required this.isCorrect,
    required this.userAnswer,
    required this.correctAnswer,
    this.explanation,
    this.onAskReason,
    this.isLoadingReason = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? AppColors.correctAnswer : AppColors.wrongAnswer;
    final bgColor = isCorrect
        ? AppColors.correctAnswer.withValues(alpha: 0.12)
        : AppColors.wrongAnswer.withValues(alpha: 0.12);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                isCorrect ? 'Correct!' : 'Incorrect',
                style: AppTypography.labelLarge.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your answer: ${userAnswer.isEmpty ? '(no answer)' : userAnswer}',
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Correct answer: $correctAnswer',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isCorrect && onAskReason != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isLoadingReason ? null : onAskReason,
              icon: isLoadingReason
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  : const Icon(Icons.psychology_alt_outlined, size: 18),
              label: Text(
                isLoadingReason ? 'Generating...' : 'Explain Answer',
              ),
            ),
          ],
          if (explanation != null && explanation!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                explanation!,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Custom section header with optional action button
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showDivider;

  const SectionHeader({
    Key? key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.showDivider = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white.withValues(alpha: 0.95) : AppColors.textPrimary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppTypography.headlineLarge.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 12),
          Container(
            height: 3,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}
