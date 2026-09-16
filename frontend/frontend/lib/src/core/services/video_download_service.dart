import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VideoDownloadService {
  static const String _storageKey = 'downloaded_videos';
  static const String _encryptionKey = 'video_encryption_key';

  final Dio _dio = Dio();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Get secure directory for video storage
  Future<Directory> _getSecureDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final secureDir = Directory(path.join(appDir.path, 'secure_videos'));

    if (!await secureDir.exists()) {
      await secureDir.create(recursive: true);
    }

    return secureDir;
  }

  // Generate encryption key for video files
  Future<String> _getEncryptionKey() async {
    String? key = await _secureStorage.read(key: _encryptionKey);
    if (key == null) {
      // Generate a new key
      final randomBytes = List.generate(
          32, (index) => DateTime.now().millisecondsSinceEpoch % 256);
      key = base64Encode(randomBytes);
      await _secureStorage.write(key: _encryptionKey, value: key);
    }
    return key;
  }

  // Simple encryption for video files (XOR cipher)
  Uint8List _encryptVideo(Uint8List data, String key) {
    final keyBytes = utf8.encode(key);
    final encrypted = Uint8List(data.length);

    for (int i = 0; i < data.length; i++) {
      encrypted[i] = data[i] ^ keyBytes[i % keyBytes.length];
    }

    return encrypted;
  }

  // Simple decryption for video files
  Uint8List _decryptVideo(Uint8List encryptedData, String key) {
    // XOR cipher is symmetric, so encryption and decryption are the same
    return _encryptVideo(encryptedData, key);
  }

  // Download video with progress tracking
  Future<Map<String, dynamic>> downloadVideo({
    required String videoUrl,
    required String lectureId,
    required String lectureTitle,
    required String courseTitle,
    Function(double)? onProgress,
  }) async {
    try {
      // Check if already downloaded
      final existingVideo = await getDownloadedVideo(lectureId);
      if (existingVideo != null) {
        return {
          'success': false,
          'message': 'Video already downloaded',
          'video': existingVideo,
        };
      }

      // Create secure filename
      final fileName =
          '${lectureId}_${DateTime.now().millisecondsSinceEpoch}.enc';
      final secureDir = await _getSecureDirectory();
      final filePath = path.join(secureDir.path, fileName);

      // Download video
      await _dio.download(
        videoUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      // Read downloaded file
      final file = File(filePath);
      final videoData = await file.readAsBytes();

      // Get encryption key
      final encryptionKey = await _getEncryptionKey();

      // Encrypt video data
      final encryptedData = _encryptVideo(videoData, encryptionKey);

      // Write encrypted file
      await file.writeAsBytes(encryptedData);

      // Get file size
      final fileSize = await file.length();

      // Create video metadata
      final videoInfo = {
        'lectureId': lectureId,
        'lectureTitle': lectureTitle,
        'courseTitle': courseTitle,
        'fileName': fileName,
        'filePath': filePath,
        'fileSize': fileSize,
        'downloadDate': DateTime.now().toIso8601String(),
        'originalUrl': videoUrl,
      };

      // Save metadata to secure storage
      await _saveVideoMetadata(videoInfo);

      return {
        'success': true,
        'message': 'Video downloaded successfully',
        'video': videoInfo,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Download failed: $e',
      };
    }
  }

  // Save video metadata to secure storage
  Future<void> _saveVideoMetadata(Map<String, dynamic> videoInfo) async {
    final videos = await getDownloadedVideos();
    videos[videoInfo['lectureId']] = videoInfo;

    final jsonString = jsonEncode(videos);
    await _secureStorage.write(key: _storageKey, value: jsonString);
  }

  // Get all downloaded videos
  Future<Map<String, dynamic>> getDownloadedVideos() async {
    try {
      final jsonString = await _secureStorage.read(key: _storageKey);
      if (jsonString != null) {
        return Map<String, dynamic>.from(jsonDecode(jsonString));
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // Get specific downloaded video
  Future<Map<String, dynamic>?> getDownloadedVideo(String lectureId) async {
    final videos = await getDownloadedVideos();
    return videos[lectureId];
  }

  // Get decrypted video file for playback
  Future<File?> getDecryptedVideoFile(String lectureId) async {
    try {
      print('Getting decrypted video file for lecture: $lectureId');
      final videoInfo = await getDownloadedVideo(lectureId);
      if (videoInfo == null) {
        print('No video info found for lecture: $lectureId');
        return null;
      }

      final filePath = videoInfo['filePath'];
      print('Original encrypted file path: $filePath');
      final file = File(filePath);

      if (!await file.exists()) {
        print('Encrypted file does not exist: $filePath');
        return null;
      }

      print('Reading encrypted data, file size: ${await file.length()} bytes');
      // Read encrypted data
      final encryptedData = await file.readAsBytes();

      // Get encryption key
      final encryptionKey = await _getEncryptionKey();

      print('Decrypting video data...');
      // Decrypt video data
      final decryptedData = _decryptVideo(encryptedData, encryptionKey);

      // Create temporary decrypted file with unique name to avoid conflicts
      final tempDir = await getTemporaryDirectory();
      final uniqueId = DateTime.now().millisecondsSinceEpoch.toString() +
          '_' +
          DateTime.now().microsecond.toString();
      final tempFileName = '${lectureId}_temp_$uniqueId.mp4';
      final tempFilePath = path.join(tempDir.path, tempFileName);
      final tempFile = File(tempFilePath);

      print('Writing decrypted data to temporary file: $tempFilePath');
      // Write decrypted data
      await tempFile.writeAsBytes(decryptedData);

      // Verify file was created successfully
      if (!await tempFile.exists()) {
        print('Failed to create temporary video file');
        throw Exception('Failed to create temporary video file');
      }

      final fileSize = await tempFile.length();
      print(
          'Created temporary video file: ${tempFile.path}, size: ${fileSize} bytes');

      if (fileSize == 0) {
        print('Warning: Temporary file has zero size');
        throw Exception('Temporary file has zero size');
      }

      return tempFile;
    } catch (e) {
      print('Error getting decrypted video file: $e');
      return null;
    }
  }

  // Delete downloaded video
  Future<bool> deleteDownloadedVideo(String lectureId) async {
    try {
      final videoInfo = await getDownloadedVideo(lectureId);
      if (videoInfo == null) return false;

      // Delete encrypted file
      final file = File(videoInfo['filePath']);
      if (await file.exists()) {
        await file.delete();
      }

      // Remove from metadata
      final videos = await getDownloadedVideos();
      videos.remove(lectureId);

      final jsonString = jsonEncode(videos);
      await _secureStorage.write(key: _storageKey, value: jsonString);

      return true;
    } catch (e) {
      return false;
    }
  }

  // Check if video is downloaded
  Future<bool> isVideoDownloaded(String lectureId) async {
    final videoInfo = await getDownloadedVideo(lectureId);
    if (videoInfo == null) return false;

    final file = File(videoInfo['filePath']);
    return await file.exists();
  }

  // Get total downloaded videos size
  Future<int> getTotalDownloadedSize() async {
    try {
      final videos = await getDownloadedVideos();
      int totalSize = 0;

      for (final video in videos.values) {
        totalSize += video['fileSize'] as int;
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  // Clear all downloaded videos
  Future<void> clearAllDownloads() async {
    try {
      final videos = await getDownloadedVideos();

      // Delete all files
      for (final video in videos.values) {
        final file = File(video['filePath']);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Clear metadata
      await _secureStorage.delete(key: _storageKey);
    } catch (e) {
      // Handle error silently
    }
  }

  // Format file size
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
