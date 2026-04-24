class FormattedSection {
  final String title;
  final String body;

  const FormattedSection({required this.title, required this.body});
}

// Utility functions for formatting AI-generated text responses.
String cleanMarkdownFormatting(String text) {
  if (text.isEmpty) return text;
  
  // Remove bold markdown
  text = text.replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1');
  text = text.replaceAll(RegExp(r'__(.*?)__'), r'$1');
  
  // Remove italic markdown
  text = text.replaceAll(RegExp(r'(?<!\*)\*(?!\*)(.*?)(?<!\*)\*(?!\*)'), r'$1');
  text = text.replaceAll(RegExp(r'(?<!_)_(?!_)(.*?)(?<!_)_(?!_)'), r'$1');
  
  // Remove headers
  text = text.replaceAll(RegExp(r'^#+\s+', multiLine: true), '');
  
  // Normalize list markers
  text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '- ');
  
  // Remove code blocks and special chars
  text = text.replaceAll('```', '');
  text = text.replaceAll('`', '');
  text = text.replaceAll(RegExp(r'\$'), '');
  text = text.replaceAll('%', '');
  text = text.replaceAll('|', ' ');
  text = text.replaceAll(RegExp(r'^[>~]+\s*', multiLine: true), '');

  // Clean per-line markers
  final lines = text.split('\n');
  final cleanedLines = lines.map((line) {
    var out = line.trimRight();
    out = out.replaceAll(RegExp(r'^[#*_`\-\+\s]+'), '');
    out = out.replaceAll(RegExp(r'\s{2,}'), ' ');
    return out;
  }).toList();
  text = cleanedLines.join('\n');
  
  // Clean up whitespace
  text = text.replaceAll(RegExp(r'\n\n+'), '\n\n');
  text = text.trim();
  
  return text;
}

String formatReview(String text) {
  text = cleanMarkdownFormatting(text);
  final sections = parseSections(text);
  if (sections.isEmpty) {
    return text;
  }
  final buffer = StringBuffer();
  for (final section in sections) {
    buffer.writeln(section.title);
    buffer.writeln(section.body);
    buffer.writeln();
  }
  return buffer.toString().trim();
}

List<FormattedSection> parseSections(String text) {
  final cleaned = cleanMarkdownFormatting(text);
  final lines = cleaned.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
  if (lines.isEmpty) {
    return const [];
  }

  final sections = <FormattedSection>[];
  String currentTitle = 'Overview';
  final currentBody = <String>[];

  bool isHeading(String line) {
    final normalized = line.replaceAll(RegExp(r'^\d+\.\s*'), '').trim();
    if (normalized.endsWith(':') && normalized.length <= 70) {
      return true;
    }
    final titleLike = RegExp(r'^[A-Z][A-Za-z0-9\s\-/]{2,48}$');
    return titleLike.hasMatch(normalized);
  }

  void flush() {
    final bodyText = currentBody.join('\n').trim();
    if (bodyText.isEmpty) {
      return;
    }
    sections.add(FormattedSection(title: currentTitle, body: bodyText));
    currentBody.clear();
  }

  for (final line in lines) {
    if (isHeading(line)) {
      flush();
      currentTitle = line
          .replaceAll(RegExp(r'^\d+\.\s*'), '')
          .replaceAll(':', '')
          .trim();
    } else {
      currentBody.add(line);
    }
  }
  flush();

  if (sections.isEmpty) {
    return [FormattedSection(title: 'Response', body: cleaned)];
  }
  return sections;
}

List<FormattedSection> formatMentorResponse(String text) {
  final sections = parseSections(text);
  if (sections.isNotEmpty) {
    return sections;
  }
  final cleaned = cleanMarkdownFormatting(text);
  return [FormattedSection(title: 'Mentor Response', body: cleaned)];
}

List<FormattedSection> formatReviewSections(String text) {
  final sections = parseSections(text);
  if (sections.isNotEmpty) {
    return sections;
  }
  final cleaned = cleanMarkdownFormatting(text);
  return [FormattedSection(title: 'Educational Review', body: cleaned)];
}

String formatActionLabel(String raw) {
  if (raw.isEmpty) {
    return 'Unknown';
  }
  final withSpaces = raw.replaceAll('_', ' ');
  return withSpaces[0].toUpperCase() + withSpaces.substring(1);
}

String buildProgressInsight({required int quizzes, required int attempts, required int queries, required double latestScore}) {
  if (quizzes == 0 && attempts == 0 && queries == 0) {
    return 'Start by uploading a document and generating your first quiz.';
  }
  if (latestScore >= 80) {
    return 'Strong momentum. Keep practicing mixed-difficulty quizzes to retain mastery.';
  }
  if (latestScore >= 60) {
    return 'Steady progress. Focus one revision cycle on weak topics, then retake a quiz.';
  }
  return 'Getting started. Each answer helps identify areas for deeper study.';
}
