class IngestDocumentResult {
  final String documentId;
  final String message;
  final int extractedChars;
  final int chunkCount;

  IngestDocumentResult({
    required this.documentId,
    required this.message,
    required this.extractedChars,
    required this.chunkCount,
  });

  factory IngestDocumentResult.fromJson(Map<String, dynamic> json) {
    return IngestDocumentResult(
      documentId: json['document_id'] as String,
      message: json['message'] as String,
      extractedChars: (json['extracted_chars'] as num?)?.toInt() ?? 0,
      chunkCount: (json['chunk_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class QuizQuestionModel {
  final String questionId;
  final String questionType;
  final String prompt;
  final List<String> options;
  final String answer;
  final String topic;

  QuizQuestionModel({
    required this.questionId,
    required this.questionType,
    required this.prompt,
    required this.options,
    required this.answer,
    required this.topic,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionModel(
      questionId: json['question_id'] as String,
      questionType: json['question_type'] as String,
      prompt: json['prompt'] as String,
      options: List<String>.from(json['options'] ?? const []),
      answer: json['answer'] as String,
      topic: json['topic'] as String,
    );
  }
}

class QuizResponse {
  final String quizId;
  final List<QuizQuestionModel> questions;

  QuizResponse({required this.quizId, required this.questions});

  factory QuizResponse.fromJson(Map<String, dynamic> json) {
    final rawQuestions = List<Map<String, dynamic>>.from(json['questions'] as List);
    return QuizResponse(
      quizId: json['quiz_id'] as String,
      questions: rawQuestions.map(QuizQuestionModel.fromJson).toList(),
    );
  }
}

class WeakTopic {
  final String topic;
  final int wrongCount;
  final String suggestion;

  WeakTopic({required this.topic, required this.wrongCount, required this.suggestion});

  factory WeakTopic.fromJson(Map<String, dynamic> json) {
    return WeakTopic(
      topic: json['topic'] as String,
      wrongCount: (json['wrong_count'] as num).toInt(),
      suggestion: json['suggestion'] as String,
    );
  }
}

class QuizSubmitResponseModel {
  final double scorePercent;
  final List<WeakTopic> weakTopics;
  final String nextStep;
  final List<QuizQuestionFeedbackModel> questionFeedback;

  QuizSubmitResponseModel({
    required this.scorePercent,
    required this.weakTopics,
    required this.nextStep,
    required this.questionFeedback,
  });

  factory QuizSubmitResponseModel.fromJson(Map<String, dynamic> json) {
    final weakRaw = List<Map<String, dynamic>>.from(json['weak_topics'] ?? const []);
    final feedbackRaw = List<Map<String, dynamic>>.from(json['question_feedback'] ?? const []);
    return QuizSubmitResponseModel(
      scorePercent: (json['score_percent'] as num).toDouble(),
      weakTopics: weakRaw.map(WeakTopic.fromJson).toList(),
      nextStep: json['next_step'] as String,
      questionFeedback: feedbackRaw.map(QuizQuestionFeedbackModel.fromJson).toList(),
    );
  }
}

class QuizQuestionFeedbackModel {
  final String questionId;
  final String questionPrompt;
  final String userAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final String topic;

  QuizQuestionFeedbackModel({
    required this.questionId,
    required this.questionPrompt,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.topic,
  });

  factory QuizQuestionFeedbackModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionFeedbackModel(
      questionId: json['question_id'] as String,
      questionPrompt: json['question_prompt'] as String? ?? '',
      userAnswer: json['user_answer'] as String? ?? '',
      correctAnswer: json['correct_answer'] as String? ?? '',
      isCorrect: json['is_correct'] as bool? ?? false,
      topic: json['topic'] as String? ?? 'General',
    );
  }
}

class QuizReasonResponseModel {
  final String questionId;
  final String explanation;

  QuizReasonResponseModel({required this.questionId, required this.explanation});

  factory QuizReasonResponseModel.fromJson(Map<String, dynamic> json) {
    return QuizReasonResponseModel(
      questionId: json['question_id'] as String,
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

class ProgressModel {
  final int totalQuizzes;
  final int totalAttempts;
  final int totalQueries;
  final double latestScore;
  final List<WeakTopic> weakestTopics;
  final List<DocumentWeakTopicGroupModel> weakTopicsByDocument;
  final String? updatedAt;

  ProgressModel({
    required this.totalQuizzes,
    required this.totalAttempts,
    required this.totalQueries,
    required this.latestScore,
    required this.weakestTopics,
    required this.weakTopicsByDocument,
    required this.updatedAt,
  });

  factory ProgressModel.fromJson(Map<String, dynamic> json) {
    final weakRaw = List<Map<String, dynamic>>.from(json['weakest_topics'] ?? const []);
    final groupedRaw = List<Map<String, dynamic>>.from(json['weak_topics_by_document'] ?? const []);
    return ProgressModel(
      totalQuizzes: (json['total_quizzes'] as num).toInt(),
      totalAttempts: (json['total_attempts'] as num).toInt(),
      totalQueries: (json['total_queries'] as num).toInt(),
      latestScore: (json['latest_score'] as num).toDouble(),
      weakestTopics: weakRaw.map(WeakTopic.fromJson).toList(),
      weakTopicsByDocument: groupedRaw.map(DocumentWeakTopicGroupModel.fromJson).toList(),
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class DocumentWeakTopicModel {
  final String topic;
  final int wrongCount;
  final int correctCount;
  final int remainingWrong;
  final String suggestion;

  DocumentWeakTopicModel({
    required this.topic,
    required this.wrongCount,
    required this.correctCount,
    required this.remainingWrong,
    required this.suggestion,
  });

  factory DocumentWeakTopicModel.fromJson(Map<String, dynamic> json) {
    return DocumentWeakTopicModel(
      topic: json['topic'] as String,
      wrongCount: (json['wrong_count'] as num?)?.toInt() ?? 0,
      correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
      remainingWrong: (json['remaining_wrong'] as num?)?.toInt() ?? 0,
      suggestion: json['suggestion'] as String? ?? '',
    );
  }
}

class DocumentWeakTopicGroupModel {
  final String documentId;
  final String documentTitle;
  final List<DocumentWeakTopicModel> topics;

  DocumentWeakTopicGroupModel({
    required this.documentId,
    required this.documentTitle,
    required this.topics,
  });

  factory DocumentWeakTopicGroupModel.fromJson(Map<String, dynamic> json) {
    return DocumentWeakTopicGroupModel(
      documentId: json['document_id'] as String,
      documentTitle: json['document_title'] as String? ?? 'Untitled document',
      topics: List<Map<String, dynamic>>.from(json['topics'] ?? const [])
          .map(DocumentWeakTopicModel.fromJson)
          .toList(),
    );
  }
}

class SessionDocumentModel {
  final String id;
  final String title;
  final String sourceType;
  final DateTime createdAt;

  SessionDocumentModel({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.createdAt,
  });

  factory SessionDocumentModel.fromJson(Map<String, dynamic> json) {
    return SessionDocumentModel(
      id: json['id'] as String,
      title: json['title'] as String,
      sourceType: json['source_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class SessionQuizModel {
  final String id;
  final String documentId;
  final String? title;
  final String difficulty;
  final DateTime createdAt;
  final double? latestScore;
  final int correctAnswers;
  final int wrongAnswers;
  final int answeredQuestions;
  final int attemptCount;

  SessionQuizModel({
    required this.id,
    required this.documentId,
    required this.title,
    required this.difficulty,
    required this.createdAt,
    required this.latestScore,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.answeredQuestions,
    required this.attemptCount,
  });

  factory SessionQuizModel.fromJson(Map<String, dynamic> json) {
    return SessionQuizModel(
      id: json['id'] as String,
      documentId: json['document_id'] as String,
      title: json['title'] as String?,
      difficulty: json['difficulty'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      latestScore: (json['latest_score'] as num?)?.toDouble(),
      correctAnswers: (json['correct_answers'] as num?)?.toInt() ?? 0,
      wrongAnswers: (json['wrong_answers'] as num?)?.toInt() ?? 0,
      answeredQuestions: (json['answered_questions'] as num?)?.toInt() ?? 0,
      attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class DocumentQuizProgressPointModel {
  final String quizId;
  final DateTime attemptedAt;
  final double scorePercent;
  final int correctAnswers;
  final int wrongAnswers;

  DocumentQuizProgressPointModel({
    required this.quizId,
    required this.attemptedAt,
    required this.scorePercent,
    required this.correctAnswers,
    required this.wrongAnswers,
  });

  factory DocumentQuizProgressPointModel.fromJson(Map<String, dynamic> json) {
    return DocumentQuizProgressPointModel(
      quizId: json['quiz_id'] as String,
      attemptedAt: DateTime.parse(json['attempted_at'] as String),
      scorePercent: (json['score_percent'] as num).toDouble(),
      correctAnswers: (json['correct_answers'] as num?)?.toInt() ?? 0,
      wrongAnswers: (json['wrong_answers'] as num?)?.toInt() ?? 0,
    );
  }
}

class DocumentQuizProgressModel {
  final String documentId;
  final String documentTitle;
  final int totalQuizzes;
  final int totalAttempts;
  final int totalCorrect;
  final int totalWrong;
  final List<DocumentQuizProgressPointModel> points;

  DocumentQuizProgressModel({
    required this.documentId,
    required this.documentTitle,
    required this.totalQuizzes,
    required this.totalAttempts,
    required this.totalCorrect,
    required this.totalWrong,
    required this.points,
  });

  factory DocumentQuizProgressModel.fromJson(Map<String, dynamic> json) {
    return DocumentQuizProgressModel(
      documentId: json['document_id'] as String,
      documentTitle: json['document_title'] as String? ?? 'Untitled document',
      totalQuizzes: (json['total_quizzes'] as num?)?.toInt() ?? 0,
      totalAttempts: (json['total_attempts'] as num?)?.toInt() ?? 0,
      totalCorrect: (json['total_correct'] as num?)?.toInt() ?? 0,
      totalWrong: (json['total_wrong'] as num?)?.toInt() ?? 0,
      points: List<Map<String, dynamic>>.from(json['points'] ?? const [])
          .map(DocumentQuizProgressPointModel.fromJson)
          .toList(),
    );
  }
}

class RecentSessionModel {
  final List<SessionDocumentModel> recentDocuments;
  final List<SessionQuizModel> recentQuizzes;
  final List<SessionReviewModel> recentReviews;
  final List<DocumentQuizProgressModel> documentQuizProgress;

  RecentSessionModel({
    required this.recentDocuments,
    required this.recentQuizzes,
    required this.recentReviews,
    required this.documentQuizProgress,
  });

  factory RecentSessionModel.fromJson(Map<String, dynamic> json) {
    return RecentSessionModel(
      recentDocuments: List<Map<String, dynamic>>.from(json['recent_documents'] ?? const [])
          .map(SessionDocumentModel.fromJson)
          .toList(),
      recentQuizzes: List<Map<String, dynamic>>.from(json['recent_quizzes'] ?? const [])
          .map(SessionQuizModel.fromJson)
          .toList(),
      recentReviews: List<Map<String, dynamic>>.from(json['recent_reviews'] ?? const [])
          .map(SessionReviewModel.fromJson)
          .toList(),
      documentQuizProgress: List<Map<String, dynamic>>.from(json['document_quiz_progress'] ?? const [])
          .map(DocumentQuizProgressModel.fromJson)
          .toList(),
    );
  }
}

class SessionReviewModel {
  final String id;
  final String documentId;
  final String? documentTitle;
  final String review;
  final DateTime createdAt;

  SessionReviewModel({
    required this.id,
    required this.documentId,
    required this.documentTitle,
    required this.review,
    required this.createdAt,
  });

  factory SessionReviewModel.fromJson(Map<String, dynamic> json) {
    return SessionReviewModel(
      id: json['id'] as String,
      documentId: json['document_id'] as String,
      documentTitle: json['document_title'] as String?,
      review: json['review'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ContinueSessionModel {
  final String? lastDocumentId;
  final String? lastQuizId;
  final String lastAction;
  final DateTime? lastActionAt;

  ContinueSessionModel({
    required this.lastDocumentId,
    required this.lastQuizId,
    required this.lastAction,
    required this.lastActionAt,
  });

  factory ContinueSessionModel.fromJson(Map<String, dynamic> json) {
    final raw = json['last_action_at'] as String?;
    return ContinueSessionModel(
      lastDocumentId: json['last_document_id'] as String?,
      lastQuizId: json['last_quiz_id'] as String?,
      lastAction: json['last_action'] as String? ?? 'dashboard',
      lastActionAt: raw == null ? null : DateTime.parse(raw),
    );
  }
}
