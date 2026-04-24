import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../models/app_models.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.apiClient,
    this.initialDocumentId,
    this.initialFocusTopics = const [],
  });

  final ApiClient apiClient;
  final String? initialDocumentId;
  final List<String> initialFocusTopics;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _documentId = TextEditingController();
  final _questionCount = TextEditingController(text: '10');
  String _difficulty = 'adaptive';
  List<SessionDocumentModel> _documents = [];
  bool _loadingDocuments = false;

  QuizResponse? _quiz;
  QuizSubmitResponseModel? _result;
  final Map<String, TextEditingController> _textAnswerControllers = {};
  final Map<String, String> _selectedAnswers = {}; // For MCQ
  final Map<String, QuizQuestionFeedbackModel> _feedbackByQuestion = {};
  final Map<String, String> _reasonByQuestion = {};
  final Set<String> _reasonLoading = {};
  bool _loading = false;
  bool _loadingProgress = false;
  String? _notesLoadingFor;
  ProgressModel? _progress;

  @override
  void initState() {
    super.initState();
    if ((widget.initialDocumentId ?? '').isNotEmpty) {
      _documentId.text = widget.initialDocumentId!;
    }
    _loadDocuments();
    _loadProgress();
  }

  Future<void> _loadProgress({bool forceRefresh = false}) async {
    setState(() => _loadingProgress = true);
    try {
      final progress = await widget.apiClient.getProgress(forceRefresh: forceRefresh);
      if (!mounted) {
        return;
      }
      setState(() {
        _progress = progress;
      });
    } catch (e) {
      debugPrint('[QuizScreen] Failed to load progress: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingProgress = false);
      }
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _loadingDocuments = true);
    try {
      final docs = await widget.apiClient.listDocuments(limit: 100);
      if (!mounted) {
        return;
      }
      setState(() {
        _documents = docs;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingDocuments = false);
      }
    }
  }

  @override
  void dispose() {
    _documentId.dispose();
    _questionCount.dispose();
    for (final controller in _textAnswerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _validatedQuestionCount() {
    final raw = _questionCount.text.trim();
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 1 || parsed > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question count must be a number between 1 and 20.')),
      );
      return null;
    }
    return parsed;
  }

  Future<void> _generateQuiz() async {
    final questionCount = _validatedQuestionCount();
    if (questionCount == null) {
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final quiz = await widget.apiClient.generateQuiz(
        documentId: _documentId.text.trim(),
        questionCount: questionCount,
        difficulty: _difficulty,
        focusTopics: widget.initialFocusTopics,
      );
      // Clear previous answers
      for (final controller in _textAnswerControllers.values) {
        controller.dispose();
      }
      _textAnswerControllers.clear();
      _selectedAnswers.clear();
      _feedbackByQuestion.clear();
      _reasonByQuestion.clear();
      _reasonLoading.clear();
      
      // Initialize answer holders for each question type
      for (final q in quiz.questions) {
        if (q.questionType == 'short_answer' || q.questionType == 'fill_blank') {
          _textAnswerControllers[q.questionId] = TextEditingController();
        }
      }
      setState(() => _quiz = quiz);
    } catch (e) {
      setState(() {
        _quiz = null;
        _result = null;
      });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitQuiz() async {
    final quiz = _quiz;
    if (quiz == null) {
      return;
    }
    setState(() => _loading = true);
    try {
      final answers = <String, String>{};
      for (final q in quiz.questions) {
        if (q.questionType == 'short_answer' || q.questionType == 'fill_blank') {
          answers[q.questionId] = _textAnswerControllers[q.questionId]?.text.trim() ?? '';
        } else {
          answers[q.questionId] = _selectedAnswers[q.questionId] ?? '';
        }
      }
      final result = await widget.apiClient.submitQuiz(quizId: quiz.quizId, answers: answers);
      setState(() {
        _result = result;
        _feedbackByQuestion
          ..clear()
          ..addEntries(result.questionFeedback.map((f) => MapEntry(f.questionId, f)));
        _reasonByQuestion.clear();
      });
      await _loadProgress(forceRefresh: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _explainWrongAnswer(QuizQuestionModel question) async {
    final quiz = _quiz;
    final feedback = _feedbackByQuestion[question.questionId];
    if (quiz == null || feedback == null || feedback.isCorrect) {
      return;
    }

    setState(() => _reasonLoading.add(question.questionId));
    try {
      final response = await widget.apiClient.explainQuizAnswer(
        quizId: quiz.quizId,
        questionId: question.questionId,
        userAnswer: feedback.userAnswer,
      );
      if (!mounted) {
        return;
      }
      setState(() => _reasonByQuestion[question.questionId] = response.explanation);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not fetch AI reason: $e')));
    } finally {
      if (mounted) {
        setState(() => _reasonLoading.remove(question.questionId));
      }
    }
  }

  Widget _resultPanelForQuestion(QuizQuestionModel question) {
    final feedback = _feedbackByQuestion[question.questionId];
    if (feedback == null) {
      return const SizedBox.shrink();
    }

    final isCorrect = feedback.isCorrect;
    final panelColor = isCorrect ? const Color(0xFFEAF9EE) : const Color(0xFFFFEDEE);
    final borderColor = isCorrect ? const Color(0xFF2E8B57) : const Color(0xFFBF2F3F);
    final labelColor = isCorrect ? const Color(0xFF1F6A43) : const Color(0xFF9A1F2E);
    final reason = _reasonByQuestion[question.questionId];
    final isLoadingReason = _reasonLoading.contains(question.questionId);
    final safeUserAnswer = feedback.userAnswer.trim().isEmpty ? 'No answer provided' : feedback.userAnswer;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: borderColor, size: 18),
              const SizedBox(width: 6),
              Text(
                isCorrect ? 'Correct' : 'Incorrect',
                style: TextStyle(fontWeight: FontWeight.w700, color: labelColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Your answer: $safeUserAnswer'),
          const SizedBox(height: 4),
          Text('Correct answer: ${feedback.correctAnswer}'),
          if (!isCorrect) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: isLoadingReason || reason != null ? null : () => _explainWrongAnswer(question),
              icon: isLoadingReason
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology_alt_outlined),
              label: Text(isLoadingReason ? 'Generating reason...' : 'AI Reason'),
            ),
            if (reason != null && reason.trim().isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Text(reason.trim(), style: const TextStyle(height: 1.5)),
              ),
          ],
        ],
      ),
    );
  }

  // Build appropriate answer widget based on question type
  Widget _buildAnswerWidget(QuizQuestionModel question) {
    switch (question.questionType) {
      case 'mcq':
        // Multiple choice - dropdown
        return DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _selectedAnswers[question.questionId],
          decoration: const InputDecoration(labelText: 'Select Answer'),
          items: question.options
              .map(
                (opt) => DropdownMenuItem(
                  value: opt,
                  child: Text(
                    opt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedAnswers[question.questionId] = value);
            }
          },
        );
      
      case 'fill_blank':
        // Fill blanks should accept free text; options are quick suggestions only.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (question.options.isNotEmpty) ...[
              Text('Suggested choices', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: question.options
                    .map(
                      (opt) => ActionChip(
                        label: Text(opt),
                        onPressed: () {
                          final controller = _textAnswerControllers[question.questionId];
                          if (controller == null) {
                            return;
                          }
                          setState(() {
                            controller.text = opt;
                            controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: controller.text.length),
                            );
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _textAnswerControllers[question.questionId],
              decoration: const InputDecoration(
                labelText: 'Fill in your answer',
                hintText: 'Type the exact term or phrase',
              ),
            ),
          ],
        );
      
      case 'short_answer':
      default:
        // Short answer - text field
        return TextField(
          controller: _textAnswerControllers[question.questionId],
          decoration: const InputDecoration(
            labelText: 'Answer',
            hintText: 'Enter your answer here',
          ),
          maxLines: 2,
        );
    }
  }

  /// Get weak topics for the currently selected document
  DocumentWeakTopicGroupModel? _getCurrentDocumentWeakTopics() {
    final docId = _documentId.text.trim();
    if (docId.isEmpty || _progress == null) return null;
    try {
      return _progress!.weakTopicsByDocument.firstWhere((group) => group.documentId == docId);
    } catch (e) {
      return null;
    }
  }

  /// Build weak topics section for the selected document
  Widget _buildWeakTopicsSection() {
    if (_loadingProgress && _documentId.text.trim().isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }

    final weakTopics = _getCurrentDocumentWeakTopics();
    if (weakTopics == null || weakTopics.topics.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 20, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  'Weak Topics in This Document',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...weakTopics.topics.map(
              (topic) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic.topic,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            if (topic.suggestion.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  topic.suggestion,
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${topic.remainingWrong} pending',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _questionCount.text = '10';
                              _difficulty = 'adaptive';
                            });
                            _generateQuizFromWeakTopics(weakTopics);
                          },
                    icon: const Icon(Icons.quiz_outlined),
                    label: const Text('Generate Practice Quiz'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading || _notesLoadingFor == weakTopics.documentId
                        ? null
                        : () => _generateQuickNotes(weakTopics),
                    icon: _notesLoadingFor == weakTopics.documentId
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_stories_outlined),
                    label: Text(
                      _notesLoadingFor == weakTopics.documentId ? 'Generating...' : 'AI Quick Notes',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Generate quiz specifically from weak topics
  Future<void> _generateQuizFromWeakTopics(DocumentWeakTopicGroupModel weakTopics) async {
    final questionCount = _validatedQuestionCount();
    if (questionCount == null) {
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final focusTopics = weakTopics.topics.map((t) => t.topic).toList();
      final quiz = await widget.apiClient.generateQuiz(
        documentId: weakTopics.documentId,
        questionCount: questionCount,
        difficulty: _difficulty,
        focusTopics: focusTopics,
      );

      // Clear previous answers
      for (final controller in _textAnswerControllers.values) {
        controller.dispose();
      }
      _textAnswerControllers.clear();
      _selectedAnswers.clear();
      _feedbackByQuestion.clear();
      _reasonByQuestion.clear();
      _reasonLoading.clear();

      // Initialize answer holders for each question type
      for (final q in quiz.questions) {
        if (q.questionType == 'short_answer' || q.questionType == 'fill_blank') {
          _textAnswerControllers[q.questionId] = TextEditingController();
        }
      }
      setState(() => _quiz = quiz);
    } catch (e) {
      setState(() {
        _quiz = null;
        _result = null;
      });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate quiz from weak topics: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Generate quick notes for weak topics
  Future<void> _generateQuickNotes(DocumentWeakTopicGroupModel weakTopics) async {
    setState(() => _notesLoadingFor = weakTopics.documentId);
    try {
      final topics = weakTopics.topics.map((t) => t.topic).toList();
      final notes = await widget.apiClient.generateQuickNotes(
        documentId: weakTopics.documentId,
        topics: topics,
      );
      if (!mounted) {
        return;
      }
      _showFormattedNotesDialog(
        title: 'Quick Notes: ${weakTopics.documentTitle}',
        notes: notes,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate quick notes: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _notesLoadingFor = null);
      }
    }
  }

  /// Show formatted notes dialog with nice UI
  void _showFormattedNotesDialog({required String title, required String notes}) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: _buildFormattedNotes(notes),
            ),
          ),
          actions: [
            TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: notes));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Quick notes copied to clipboard')),
            );
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

  /// Parse and build formatted notes widget
  Widget _buildFormattedNotes(String notes) {
    final lines = notes.split('\n');
    final widgets = <Widget>[];

    String? currentSection;
    List<String> currentContent = [];

    for (final line in lines) {
      final trimmed = line.trim();

      // Detect section headers (lines ending with ':')
      if (trimmed.endsWith(':') && trimmed.isNotEmpty) {
        // Flush previous section
        if (currentSection != null && currentContent.isNotEmpty) {
          widgets.add(_buildSection(currentSection, currentContent));
          widgets.add(const SizedBox(height: 12));
        }
        currentSection = trimmed.replaceAll(RegExp(r':$'), '');
        currentContent = [];
      } else if (trimmed.isNotEmpty && currentSection != null) {
        currentContent.add(trimmed);
      }
    }

    // Flush last section
    if (currentSection != null && currentContent.isNotEmpty) {
      widgets.add(_buildSection(currentSection, currentContent));
    }

    return widgets.isEmpty
        ? Text(notes, style: const TextStyle(height: 1.6))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widgets,
          );
  }

  /// Build a formatted section with header and content
  Widget _buildSection(String header, List<String> content) {
    final palette = {
      'Topic Snapshot': Theme.of(context).colorScheme.primary,
      'Key Points': Theme.of(context).colorScheme.secondary,
      'Memory Hooks': Theme.of(context).colorScheme.tertiary,
      '5-Minute Drill': Theme.of(context).colorScheme.error,
    };

    final borderColor = palette[header] ?? Theme.of(context).colorScheme.outline;
    final bgColor = borderColor.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: borderColor,
            ),
          ),
          const SizedBox(height: 8),
          ...content.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final line = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: index < content.length - 1 ? 6 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 8),
                      child: Text('•', style: TextStyle(color: borderColor, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: Text(
                        line,
                        style: TextStyle(
                          height: 1.4,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.cardBgDark : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.quiz_outlined, color: Color(0xFF06B6D4), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generate Quiz',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Adaptive & personalized questions',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
          ],
          // Weak topics section for selected document
          _buildWeakTopicsSection(),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _documentId.text.isEmpty ? null : _documentId.text,
            decoration: const InputDecoration(labelText: 'Pick uploaded document'),
            items: _documents
                .map(
                  (doc) => DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(
                      '${doc.title} (${doc.sourceType})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            selectedItemBuilder: (context) {
              return _documents
                  .map(
                    (doc) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${doc.title} (${doc.sourceType})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList();
            },
            onChanged: _loadingDocuments
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _documentId.text = value);
                      _loadProgress();
                    }
                  },
          ),
          if (_documentId.text.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Select a document to generate a quiz.'),
            ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              if (compact) {
                return Column(
                  children: [
                    TextField(
                      controller: _questionCount,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      decoration: const InputDecoration(labelText: 'Question count (1-20)'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _difficulty,
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                        DropdownMenuItem(value: 'adaptive', child: Text('Adaptive')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _difficulty = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Difficulty'),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionCount,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      decoration: const InputDecoration(labelText: 'Question count (1-20)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _difficulty,
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                        DropdownMenuItem(value: 'adaptive', child: Text('Adaptive')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _difficulty = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Difficulty'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading || _documentId.text.trim().isEmpty ? null : _generateQuiz,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Generate'),
          ),
          const SizedBox(height: 16),
          if (_quiz != null)
            ..._quiz!.questions.map((q) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.prompt, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 8),
                      if (q.options.isNotEmpty && q.questionType == 'mcq')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('Options available', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ),
                      _buildAnswerWidget(q),
                      if (_result != null) _resultPanelForQuestion(q),
                    ],
                  ),
                ),
              );
            }),
          if (_quiz != null)
            FilledButton(
              onPressed: _loading || _result != null ? null : _submitQuiz,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Attempt'),
            ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Score: ${_result!.scorePercent.toStringAsFixed(1)}%'),
                    const SizedBox(height: 8),
                    Text(_result!.nextStep),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Weak Topics', style: TextStyle(fontWeight: FontWeight.w700)),
            ..._result!.weakTopics.map(
              (topic) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(topic.topic),
                subtitle: Text(topic.suggestion),
                trailing: Text('Wrong ${topic.wrongCount}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
