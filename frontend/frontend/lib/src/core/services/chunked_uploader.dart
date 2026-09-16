import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'api_service.dart';

class ChunkedUploader {
  final ApiService _apiService;
  final Function(UploadProgress) onProgress;
  final Function(UploadResult) onComplete;
  final Function(String) onError;

  static const int chunkSize = 50 * 1024 * 1024; // 50MB chunks

  ChunkedUploader({
    required ApiService apiService,
    required this.onProgress,
    required this.onComplete,
    required this.onError,
  }) : _apiService = apiService;

  Future<void> uploadFile({
    required String filePath,
    required String courseId,
    required String lectureId,
    required String title,
    String? description,
    String fileType = 'video',
  }) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();
      final totalChunks = (fileSize / chunkSize).ceil();
      final uploadSessionId = _generateSessionId();

      print('===== UPLOAD DETAILS =====');
      print('Starting chunked upload: ${file.path}');
      print('Filename: ${file.path.split('/').last}');
      print('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      print('Total chunks: $totalChunks');
      print('Chunk size: ${(chunkSize / 1024 / 1024).toStringAsFixed(2)} MB');
      print('Course ID: $courseId');
      print(
          'Lecture ID: ${lectureId.isEmpty ? "Will generate new ID" : lectureId}');
      print('Title: $title');
      print('Description: ${description ?? ""}');
      print('File Type: $fileType');
      print('Upload Session ID: $uploadSessionId');
      print('===== END UPLOAD DETAILS =====');

      // Upload chunks sequentially
      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end =
            (start + chunkSize < fileSize) ? start + chunkSize : fileSize;

        print(
            '[CHUNK ${i + 1}/$totalChunks] Preparing chunk, size: ${((end - start) / 1024 / 1024).toStringAsFixed(2)} MB, range: $start-$end bytes');

        Uint8List chunkBytes;
        try {
          final chunk = await file.openRead(start, end).toList();
          chunkBytes = Uint8List.fromList(chunk.expand((x) => x).toList());
          print(
              '[CHUNK ${i + 1}/$totalChunks] Successfully read ${chunkBytes.length} bytes from file');
        } catch (readError) {
          print('[CHUNK ERROR] Failed to read chunk: $readError');
          throw Exception('Failed to read chunk from file: $readError');
        }

        // Create form data with fixed field order and consistent naming
        final formData = FormData.fromMap({
          'chunk': MultipartFile.fromBytes(
            chunkBytes,
            filename: file.path
                .split('/')
                .last, // Use actual filename, not 'chunk_$i'
          ),
          'chunkIndex': i.toString(),
          'totalChunks': totalChunks.toString(),
          'fileName': file.path.split('/').last,
          'courseId': courseId,
          'lectureId': lectureId.isEmpty
              ? 'lecture_${DateTime.now().millisecondsSinceEpoch}'
              : lectureId, // Ensure valid lecture_id
          'title': title,
          'description': description ?? '',
          'fileType': fileType,
          'uploadSessionId': uploadSessionId,
        });

        print('[CHUNK ${i + 1}/$totalChunks] Sending to server...');

        Map<String, dynamic> response;
        try {
          response = await _apiService.uploadChunk(formData);
          print(
              '[CHUNK ${i + 1}/$totalChunks] Response received: ${response.toString().substring(0, math.min(100, response.toString().length))}...');
        } catch (apiError) {
          print('[CHUNK API ERROR] Upload request failed: $apiError');
          throw Exception('Failed to upload chunk to server: $apiError');
        }

        if (response['success'] == true) {
          // Update progress
          print(
              '[CHUNK ${i + 1}/$totalChunks] Upload successful, updating progress');
          final progress = UploadProgress(
            chunkIndex: response['chunkIndex'] ?? i,
            totalChunks: response['totalChunks'] ?? totalChunks,
            percentage: response['progress'] != null
                ? response['progress']['percentage'] ?? 0
                : (i + 1) * 100 ~/ totalChunks,
            completed: response['progress'] != null
                ? response['progress']['completed'] ?? 0
                : 0,
            total: response['progress'] != null
                ? response['progress']['total'] ?? 0
                : 0,
            isComplete: response['isComplete'] ?? false,
            uploadSessionId: response['uploadSessionId'] ?? uploadSessionId,
          );

          onProgress(progress);

          if (response['isComplete'] == true) {
            print('[UPLOAD COMPLETE] Upload finished successfully!');
            print(
                '[UPLOAD COMPLETE] Response: ${response.toString().substring(0, math.min(300, response.toString().length))}...');
            final result = UploadResult(
              fileInfo: response['fileInfo'] ?? {},
              progress: response['progress'] ?? {},
              uploadSessionId: response['uploadSessionId'] ?? uploadSessionId,
            );
            onComplete(result);
            return;
          }
        } else {
          print(
              '[CHUNK ERROR] Upload failed: ${response['error'] ?? 'Unknown error'}');
          print('[CHUNK ERROR] Full response: $response');
          throw Exception(response['error'] ?? 'Chunk upload failed');
        }
      }
    } catch (e, stackTrace) {
      print('[UPLOAD ERROR] ===== CHUNKED UPLOAD FAILED =====');
      print('[UPLOAD ERROR] Error: $e');
      print('[UPLOAD ERROR] Stack trace: $stackTrace');
      onError('Upload failed: ${e.toString()}');
    }
  }

  String _generateSessionId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }
}

// Data classes
class UploadProgress {
  final int chunkIndex;
  final int totalChunks;
  final int percentage;
  final int completed;
  final int total;
  final bool isComplete;
  final String uploadSessionId;

  UploadProgress({
    required this.chunkIndex,
    required this.totalChunks,
    required this.percentage,
    required this.completed,
    required this.total,
    required this.isComplete,
    required this.uploadSessionId,
  });
}

class UploadResult {
  final Map<String, dynamic> fileInfo;
  final Map<String, dynamic> progress;
  final String uploadSessionId;

  UploadResult({
    required this.fileInfo,
    required this.progress,
    required this.uploadSessionId,
  });
}
