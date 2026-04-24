import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../models/app_models.dart';
import '../utils/text_formatting.dart';
import '../utils/ui_components.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressModel? _progress;
  RecentSessionModel? _recent;
  String? _error;
  bool _loading = true;
  bool _refreshing = false;
  bool _deletingQuiz = false;
  bool _showAllDocuments = false;
  bool _showAllQuizzes = false;
  bool _showAllReviews = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _hasData => _progress != null && _recent != null;

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = !_hasData;
      _refreshing = _hasData;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.apiClient.getProgress(forceRefresh: forceRefresh),
        widget.apiClient.getRecentSession(forceRefresh: forceRefresh),
      ]);
      final progress = results[0] as ProgressModel;
      final recent = results[1] as RecentSessionModel;
      if (!mounted) {
        return;
      }
      setState(() {
        _progress = progress;
        _recent = recent;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _progress;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.cardBgDark : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.trending_up_rounded, color: Color(0xFFEC4899), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Progress',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Detailed analytics & insights',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_refreshing) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 10),
                    ],
                    _scoreHeader(progress),
                    const SizedBox(height: 10),
                    _statTile('Quizzes Generated', '${progress?.totalQuizzes ?? 0}'),
                    _statTile('Queries Asked', '${progress?.totalQueries ?? 0}'),
                    _statTile('Average Score', '${progress?.latestScore.toStringAsFixed(1)}%'),
                    if (progress?.updatedAt != null)
                      _statTile(
                        'Last Update',
                        DateFormat.yMMMd().add_jm().format(DateTime.parse(progress!.updatedAt!).toLocal()),
                      ),
                    const SizedBox(height: 14),
                    _recentDocumentsCard(),
                    const SizedBox(height: 10),
                    _recentQuizzesCard(),
                    const SizedBox(height: 10),
                    _recentReviewsCard(),
                  ],
                ),
    );
  }

  Widget _scoreHeader(ProgressModel? progress) {
    final score = progress?.latestScore ?? 0.0;
    final insight = buildProgressInsight(
      quizzes: progress?.totalQuizzes ?? 0,
      attempts: progress?.totalQuizzes ?? 0,
      queries: progress?.totalQueries ?? 0,
      latestScore: score,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overall Standing: ${score.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(insight, style: const TextStyle(height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _recentDocumentsCard() {
    final docs = _recent?.recentDocuments ?? const [];
    final docProgress = {
      for (final item in _recent?.documentQuizProgress ?? const <DocumentQuizProgressModel>[])
        item.documentId: item,
    };
    final visibleDocs = _showAllDocuments ? docs : docs.take(3).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Documents', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (docs.isEmpty) const Text('No recent documents.'),
            ...visibleDocs.map(
              (doc) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(doc.title),
                subtitle: Text('${doc.sourceType.toUpperCase()} - ${DateFormat.yMMMd().add_jm().format(doc.createdAt)}'),
                trailing: docProgress.containsKey(doc.id)
                    ? IconButton(
                        tooltip: 'View analytics',
                        onPressed: () => _showQuizAnalyticsSheet(docProgress[doc.id]!),
                        icon: const Icon(Icons.analytics_outlined),
                      )
                    : null,
              ),
            ),
            if (docs.length > 3)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _showAllDocuments = !_showAllDocuments),
                  child: Text(_showAllDocuments ? 'View less' : 'View more'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _recentQuizzesCard() {
    final quizzes = _recent?.recentQuizzes ?? const [];
    final visibleQuizzes = _showAllQuizzes ? quizzes : quizzes.take(3).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Quizzes', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (quizzes.isEmpty) const Text('No recent quizzes yet.'),
            ...visibleQuizzes.map(
              (quiz) {
                return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            quiz.title?.trim().isNotEmpty == true ? quiz.title! : 'Quiz',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete quiz',
                          onPressed: _deletingQuiz ? null : () => _deleteQuiz(quiz.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    Text(
                      '${quiz.difficulty} - ${DateFormat.yMMMd().add_jm().format(quiz.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _summaryChip(
                          icon: Icons.check_circle_outline,
                          label: 'Right ${quiz.correctAnswers}',
                          color: const Color(0xFF2E7D32),
                        ),
                        _summaryChip(
                          icon: Icons.highlight_off,
                          label: 'Wrong ${quiz.wrongAnswers}',
                          color: const Color(0xFFC62828),
                        ),
                        _summaryChip(
                          icon: Icons.assessment_outlined,
                          label: quiz.latestScore == null
                              ? 'No attempt yet'
                              : 'Score ${quiz.latestScore!.toStringAsFixed(1)}%',
                          color: const Color(0xFF1565C0),
                        ),
                      ],
                    ),
                  ],
                ),
              );
              },
            ),
            if (quizzes.length > 3)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _showAllQuizzes = !_showAllQuizzes),
                  child: Text(_showAllQuizzes ? 'View less' : 'View more'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _showQuizAnalyticsSheet(DocumentQuizProgressModel item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.documentTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                'Quizzes ${item.totalQuizzes}  |  Right ${item.totalCorrect}  |  Wrong ${item.totalWrong}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _scoreBars(item.points),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreBars(List<DocumentQuizProgressPointModel> points) {
    if (points.isEmpty) {
      return const Text('No attempts yet.');
    }

    final recent = points.length > 10 ? points.sublist(points.length - 10) : points;
    return SizedBox(
      height: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = recent.length <= 5 ? 44.0 : 36.0;
                final chartWidth = (recent.length * barWidth).clamp(constraints.maxWidth, 480.0);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: recent.asMap().entries.map((entry) {
                        final index = entry.key;
                        final point = entry.value;
                        final scoreHeight = (point.scorePercent.clamp(0, 100) / 100) * 84 + 10;
                        final previous = index > 0 ? recent[index - 1].scorePercent : point.scorePercent;
                        final improved = point.scorePercent >= previous;
                        final color = improved ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

                        return SizedBox(
                          width: barWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('${point.scorePercent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10)),
                                const SizedBox(height: 4),
                                Container(
                                  height: scoreHeight,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text('Left to right: oldest to latest attempt', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _recentReviewsCard() {
    final reviews = _recent?.recentReviews ?? const [];
    final visibleReviews = _showAllReviews ? reviews : reviews.take(3).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Saved AI Reviews', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (reviews.isEmpty) const Text('No saved reviews yet.'),
            ...visibleReviews.map(
              (review) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(review.documentTitle?.trim().isNotEmpty == true ? review.documentTitle! : 'Review'),
                subtitle: Text(DateFormat.yMMMd().add_jm().format(review.createdAt.toLocal())),
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    IconButton(
                      tooltip: 'View review',
                      onPressed: () => _showReviewDialog(review),
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                    IconButton(
                      tooltip: 'Copy review',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: review.review));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review copied')));
                      },
                      icon: const Icon(Icons.copy_outlined),
                    ),
                  ],
                ),
              ),
            ),
            if (reviews.length > 3)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _showAllReviews = !_showAllReviews),
                  child: Text(_showAllReviews ? 'View less' : 'View more'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteQuiz(String quizId) async {
    setState(() => _deletingQuiz = true);
    try {
      await widget.apiClient.deleteQuiz(quizId: quizId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quiz deleted')));
      await _load(forceRefresh: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _deletingQuiz = false);
      }
    }
  }

  Widget _statTile(String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _showReviewDialog(SessionReviewModel review) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(review.documentTitle?.trim().isNotEmpty == true ? review.documentTitle! : 'Saved AI Review'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Text(review.review, style: const TextStyle(height: 1.5)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: review.review));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review copied')));
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

}
