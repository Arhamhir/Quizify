import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../models/app_models.dart';
import '../utils/ui_components.dart';
import '../utils/text_formatting.dart';

class QueryScreen extends StatefulWidget {
  const QueryScreen({super.key, required this.apiClient, this.initialDocumentId});

  final ApiClient apiClient;
  final String? initialDocumentId;

  @override
  State<QueryScreen> createState() => _QueryScreenState();
}

class _QueryScreenState extends State<QueryScreen> {
  final _documentId = TextEditingController();
  final _question = TextEditingController();
  List<SessionDocumentModel> _documents = [];
  bool _loadingDocuments = false;
  String _answer = '';
  List<FormattedSection> _answerSections = const [];
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
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    setState(() => _loading = true);
    try {
      final answer = await widget.apiClient.askQuery(
        documentId: _documentId.text.trim(),
        question: _question.text.trim(),
      );
      setState(() {
        _answer = cleanMarkdownFormatting(answer);
        _answerSections = formatMentorResponse(answer);
      });
    } catch (e) {
      setState(() => _answer = 'Failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompact = MediaQuery.of(context).size.width < 420;
    final sectionBg = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final sectionBorder = Theme.of(context).colorScheme.outlineVariant;
    final sectionTitle = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.cardBgDark : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.help_center_outlined, color: Color(0xFF14B8A6), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask Questions',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Get AI mentor guidance',
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
              child: Text('Select a document to continue.'),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _question,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Your question'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading || _documentId.text.trim().isEmpty ? null : _ask,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Ask Mentor'),
          ),
          const SizedBox(height: 12),
          if (_answer.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Mentor Response', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        IconButton(
                          tooltip: 'Copy full response',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _answer));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response copied')));
                          },
                          icon: const Icon(Icons.copy_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._answerSections.map(
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
