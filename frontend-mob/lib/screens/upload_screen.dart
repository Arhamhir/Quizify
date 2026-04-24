import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../models/app_models.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _title = TextEditingController();
  final _text = TextEditingController();
  Uint8List? _fileBytes;
  String? _fileName;
  String _sourceType = 'auto';
  bool _loading = false;
  String? _result;
  List<SessionDocumentModel> _documents = [];
  bool _loadingDocuments = false;

  static const Set<String> _imageExtensions = {
    'png',
    'jpg',
    'jpeg',
    'webp',
    'bmp',
    'tiff',
  };

  static const Set<String> _textExtensions = {
    'txt',
    'md',
    'csv',
  };

  static const Set<String> _docxExtensions = {
    'docx',
  };

  static const Set<String> _pptxExtensions = {
    'pptx',
  };

  @override
  void initState() {
    super.initState();
    _refreshDocuments();
  }

  String _detectSourceTypeFromName(String fileName) {
    final parts = fileName.toLowerCase().split('.');
    if (parts.length < 2) {
      return 'text';
    }
    final ext = parts.last;
    if (ext == 'pdf') {
      return 'pdf';
    }
    if (_imageExtensions.contains(ext)) {
      return 'image';
    }
    if (_textExtensions.contains(ext)) {
      return 'text';
    }
    if (_docxExtensions.contains(ext)) {
      return 'docx';
    }
    if (_pptxExtensions.contains(ext)) {
      return 'pptx';
    }
    return 'text';
  }

  Future<void> _refreshDocuments() async {
    setState(() => _loadingDocuments = true);
    try {
      final docs = await widget.apiClient.listDocuments(limit: 100);
      if (!mounted) {
        return;
      }
      setState(() => _documents = docs);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _documents = []);
    } finally {
      if (mounted) {
        setState(() => _loadingDocuments = false);
      }
    }
  }

  Future<void> _deleteDocument(String documentId) async {
    setState(() => _loading = true);
    try {
      await widget.apiClient.deleteDocument(documentId: documentId);
      await _refreshDocuments();
      if (!mounted) {
        return;
      }
      setState(() => _result = 'Document deleted.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _result = 'Delete failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.any);
    if (result == null || result.files.single.bytes == null) {
      return;
    }
    final file = result.files.single;
    setState(() {
      _fileBytes = file.bytes;
      _fileName = file.name;
      _title.text = _title.text.isEmpty ? file.name : _title.text;
      _sourceType = _detectSourceTypeFromName(file.name);
    });
  }

  Future<void> _captureImage() async {
    final picker = ImagePicker();
    final shot = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (shot == null) {
      return;
    }
    final bytes = await File(shot.path).readAsBytes();
    setState(() {
      _fileBytes = bytes;
      _fileName = shot.name;
      _sourceType = 'camera';
      _title.text = _title.text.isEmpty ? 'Camera Capture' : _title.text;
    });
  }

  Future<void> _submit() async {
    if (_fileBytes == null || _fileName == null) {
      setState(() => _result = 'Please select a file or capture an image first.');
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final response = await widget.apiClient.uploadDocument(
        title: _title.text.trim().isEmpty ? 'Untitled Notes' : _title.text.trim(),
        sourceType: _sourceType,
        fileName: _fileName!,
        fileBytes: _fileBytes!,
        extractedText: _text.text.trim(),
      );
      setState(
        () => _result =
        'Saved successfully.\nExtracted chars: ${response.extractedChars}\nChunks: ${response.chunkCount}',
      );
      await _refreshDocuments();
    } on dio.DioException catch (e) {
      if (!mounted) {
        return;
      }
      final serverDetail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail']?.toString() ?? '')
          : '';
      final isTimeout = e.type == dio.DioExceptionType.connectionTimeout ||
          e.type == dio.DioExceptionType.sendTimeout ||
          e.type == dio.DioExceptionType.receiveTimeout;
      setState(
        () => _result = isTimeout
            ? 'Upload timed out. Ensure backend is running and BACKEND_BASE_URL points to the correct host (web: http://localhost:8000, Android emulator: http://10.0.2.2:8000). Then retry.'
            : 'Failed: ${serverDetail.isNotEmpty ? serverDetail : (e.message ?? 'Request failed')}',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _result = 'Failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
                color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.upload_file_rounded, color: Color(0xFF7C3AED), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload Document',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'PDF, images, or notes',
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
          const Text(
            'Upload PDF, DOCX, PPTX, image, or camera notes and Quizify will parse text, run OCR when needed, and index chunks for better learning.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Document title'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sourceType,
                  decoration: const InputDecoration(labelText: 'Source type'),
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto detect')),
                    DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                    DropdownMenuItem(value: 'image', child: Text('Image')),
                    DropdownMenuItem(value: 'camera', child: Text('Camera')),
                    DropdownMenuItem(value: 'text', child: Text('Text fallback')),
                    DropdownMenuItem(value: 'docx', child: Text('DOCX')),
                    DropdownMenuItem(value: 'pptx', child: Text('PPTX slides')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _sourceType = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              labelText: 'Fallback text (optional)',
              helperText:
                  'Provide extracted text manually if automatic extraction fails. Used for:\n'
                  '• Scanned PDFs/images without readable text\n'
                  '• Unsupported file formats\n'
                  '• Empty or corrupted files',
            ),
          ),
          const SizedBox(height: 12),
          if (_fileName != null)
            Text('Selected file: $_fileName', style: TextStyle(color: Colors.grey.shade700)),
          if (_fileName != null) const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Pick File'),
              ),
              OutlinedButton.icon(
                onPressed: _captureImage,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Capture'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Document'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 10),
            Text(_result!),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Uploaded Documents',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _loadingDocuments ? null : _refreshDocuments,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh list',
              ),
            ],
          ),
          if (_loadingDocuments)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            )
          else if (_documents.isEmpty)
            const Text('No uploaded documents yet.')
          else
            ..._documents.map(
              (doc) => Card(
                child: ListTile(
                  title: Text(doc.title),
                  subtitle: Text(doc.sourceType.toUpperCase()),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete document',
                    onPressed: _loading ? null : () => _deleteDocument(doc.id),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
