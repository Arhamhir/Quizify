import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../models/app_models.dart';
import '../utils/text_formatting.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.apiClient, this.initialDocumentId});

  final ApiClient apiClient;
  final String? initialDocumentId;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _documentId = TextEditingController();
  List<SessionDocumentModel> _documents = [];
  bool _loadingDocuments = false;
  String _review = '';
  List<FormattedSection> _reviewSections = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if ((widget.initialDocumentId ?? '').isNotEmpty) {
      _documentId.text = widget.initialDocumentId!;
    }
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _loadingDocuments = true);
    try {
      final docs = await widget.apiClient.listDocuments(limit: 100);
      if (!mounted) {
        return;
      }
      setState(() => _documents = docs);
    } finally {
      if (mounted) {
        setState(() => _loadingDocuments = false);
      }
    }
  }

  @override
  void dispose() {
    _documentId.dispose();
    super.dispose();
  }

  Future<void> _generateReview() async {
    setState(() => _loading = true);
    try {
      final review = await widget.apiClient.generateReview(documentId: _documentId.text.trim());
      setState(() {
        _review = formatReview(review);
        _reviewSections = formatReviewSections(review);
      });
    } catch (e) {
      setState(() => _review = 'Failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 420;
    final sectionBg = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final sectionBorder = Theme.of(context).colorScheme.outlineVariant;
    final sectionTitle = Theme.of(context).colorScheme.tertiary;
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
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.analytics_outlined, color: Color(0xFFF59E0B), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review & Analyze',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'AI insights on weak topics',
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
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        children: [
          if (_loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
          ],
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
                    }
                  },
          ),
          if (_documentId.text.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Select a document to analyze.'),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading || _documentId.text.trim().isEmpty ? null : _generateReview,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Analyze'),
          ),
          const SizedBox(height: 12),
          if (_review.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Analysis Results', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        IconButton(
                          tooltip: 'Copy full review',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _review));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review copied')));
                          },
                          icon: const Icon(Icons.copy_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._reviewSections.map(
                      (section) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: sectionBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: sectionBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      section.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: sectionTitle,
                                      ),
                                    ),
                                ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Copy section',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: '${section.title}\n${section.body}'));
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Section copied')));
                                    },
                                    icon: const Icon(Icons.copy_outlined, size: 18),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                section.body,
                                style: TextStyle(
                                  height: 1.65,
                                  fontSize: isCompact ? 13 : 14,
                                  color: isDark ? Colors.white.withValues(alpha: 0.85) : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
