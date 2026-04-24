import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_models.dart';

class ApiClient {
  ApiClient({required this.baseUrl})
      : _dio = dio.Dio(
          dio.BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 45),
            receiveTimeout: const Duration(minutes: 2),
            sendTimeout: const Duration(minutes: 2),
          ),
        );

  final String baseUrl;
  final dio.Dio _dio;
  ProgressModel? _progressCache;
  DateTime? _progressCachedAt;
  RecentSessionModel? _recentSessionCache;
  DateTime? _recentSessionCachedAt;
  List<SessionDocumentModel>? _documentsCache;
  DateTime? _documentsCachedAt;

  static const Duration _progressCacheTtl = Duration(seconds: 45);
  static const Duration _recentSessionCacheTtl = Duration(seconds: 45);
  static const Duration _documentsCacheTtl = Duration(minutes: 2);

  bool _isFresh(DateTime? timestamp, Duration ttl) {
    if (timestamp == null) {
      return false;
    }
    return DateTime.now().difference(timestamp) <= ttl;
  }

  void _invalidateProgressAndRecentCaches() {
    _progressCache = null;
    _progressCachedAt = null;
    _recentSessionCache = null;
    _recentSessionCachedAt = null;
  }

  void _invalidateDocumentCache() {
    _documentsCache = null;
    _documentsCachedAt = null;
  }

  String _bearer() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception(
        'No active session token. User is not logged in. Ensure Supabase.initialize() completed successfully.',
      );
    }
    return 'Bearer $token';
  }

  dio.Options _authOptions() {
    try {
      return dio.Options(headers: {'Authorization': _bearer()});
    } catch (e) {
      throw Exception('Auth headers failed: $e. Restart the app and sign in again.');
    }
  }

  Future<IngestDocumentResult> uploadDocument({
    required String title,
    required String sourceType,
    required String fileName,
    required Uint8List fileBytes,
    String extractedText = '',
  }) async {
    final formData = dio.FormData.fromMap({
      'title': title,
      'source_type': sourceType,
      'extracted_text': extractedText,
      'file': dio.MultipartFile.fromBytes(fileBytes, filename: fileName),
    });
    final response = await _dio.post(
      '/v1/documents/upload',
      data: formData,
      options: _authOptions().copyWith(
        connectTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(minutes: 4),
        receiveTimeout: const Duration(minutes: 4),
      ),
    );
    _invalidateDocumentCache();
    _recentSessionCache = null;
    _recentSessionCachedAt = null;
    return IngestDocumentResult.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<SessionDocumentModel>> listDocuments({int limit = 100, bool forceRefresh = false}) async {
    if (!forceRefresh && limit == 100 && _documentsCache != null && _isFresh(_documentsCachedAt, _documentsCacheTtl)) {
      return List<SessionDocumentModel>.from(_documentsCache!);
    }

    final response = await _dio.get(
      '/v1/documents',
      queryParameters: {'limit': limit},
      options: _authOptions(),
    );
    final data = List<Map<String, dynamic>>.from(response.data as List);
    final docs = data.map(SessionDocumentModel.fromJson).toList();
    if (limit == 100) {
      _documentsCache = docs;
      _documentsCachedAt = DateTime.now();
    }
    return docs;
  }

  Future<void> deleteDocument({required String documentId}) async {
    await _dio.delete('/v1/documents/$documentId', options: _authOptions());
    _invalidateDocumentCache();
    _recentSessionCache = null;
    _recentSessionCachedAt = null;
  }

  Future<void> deleteQuiz({required String quizId}) async {
    await _dio.delete('/v1/quizzes/$quizId', options: _authOptions());
    _invalidateProgressAndRecentCaches();
  }

  Future<QuizResponse> generateQuiz({
    required String documentId,
    required int questionCount,
    required String difficulty,
    List<String> focusTopics = const [],
  }) async {
    final response = await _dio.post(
      '/v1/quiz/generate',
      data: {
        'document_id': documentId,
        'question_count': questionCount,
        'difficulty': difficulty,
        'focus_topics': focusTopics,
      },
      options: _authOptions(),
    );
    return QuizResponse.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<QuizSubmitResponseModel> submitQuiz({
    required String quizId,
    required Map<String, String> answers,
  }) async {
    final response = await _dio.post(
      '/v1/quiz/submit',
      data: {
        'quiz_id': quizId,
        'answers': answers.entries
            .map((entry) => {'question_id': entry.key, 'user_answer': entry.value})
            .toList(),
      },
      options: _authOptions(),
    );
    _invalidateProgressAndRecentCaches();
    return QuizSubmitResponseModel.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<QuizReasonResponseModel> explainQuizAnswer({
    required String quizId,
    required String questionId,
    required String userAnswer,
  }) async {
    final response = await _dio.post(
      '/v1/quiz/reason',
      data: {
        'quiz_id': quizId,
        'question_id': questionId,
        'user_answer': userAnswer,
      },
      options: _authOptions(),
    );
    return QuizReasonResponseModel.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<String> askQuery({required String documentId, required String question}) async {
    final response = await _dio.post(
      '/v1/agent/query',
      data: {'document_id': documentId, 'question': question},
      options: _authOptions(),
    );
    _invalidateProgressAndRecentCaches();
    return Map<String, dynamic>.from(response.data as Map)['answer'] as String;
  }

  Future<String> generateReview({required String documentId}) async {
    final response = await _dio.post(
      '/v1/agent/review',
      data: {'document_id': documentId},
      options: _authOptions(),
    );
    _recentSessionCache = null;
    _recentSessionCachedAt = null;
    return Map<String, dynamic>.from(response.data as Map)['review'] as String;
  }

  Future<String> generateQuickNotes({required String documentId, required List<String> topics}) async {
    final response = await _dio.post(
      '/v1/agent/quick-notes',
      data: {'document_id': documentId, 'topics': topics},
      options: _authOptions(),
    );
    return Map<String, dynamic>.from(response.data as Map)['notes'] as String;
  }

  Future<void> testConnection() async {
    try {
      final response = await _dio.get('/health');
      if (response.statusCode != 200) {
        throw Exception('Backend returned status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(
        'Cannot reach backend at $baseUrl. Ensure it is running and firewall allows it. Error: $e',
      );
    }
  }

  Future<ProgressModel> getProgress({bool forceRefresh = false}) async {
    if (!forceRefresh && _progressCache != null && _isFresh(_progressCachedAt, _progressCacheTtl)) {
      return _progressCache!;
    }

    final response = await _dio.get('/v1/progress', options: _authOptions());
    final progress = ProgressModel.fromJson(Map<String, dynamic>.from(response.data as Map));
    _progressCache = progress;
    _progressCachedAt = DateTime.now();
    return progress;
  }

  Future<RecentSessionModel> getRecentSession({bool forceRefresh = false}) async {
    if (!forceRefresh && _recentSessionCache != null && _isFresh(_recentSessionCachedAt, _recentSessionCacheTtl)) {
      return _recentSessionCache!;
    }

    final response = await _dio.get('/v1/session/recent', options: _authOptions());
    final recent = RecentSessionModel.fromJson(Map<String, dynamic>.from(response.data as Map));
    _recentSessionCache = recent;
    _recentSessionCachedAt = DateTime.now();
    return recent;
  }

  Future<ContinueSessionModel> getContinueSession() async {
    final response = await _dio.get('/v1/session/continue', options: _authOptions());
    return ContinueSessionModel.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
