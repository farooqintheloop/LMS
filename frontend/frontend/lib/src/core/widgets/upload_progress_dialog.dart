import 'package:flutter/material.dart';
import '../services/chunked_uploader.dart';
import '../services/api_service.dart';

class UploadProgressDialog extends StatefulWidget {
  final String filePath;
  final String fileName;
  final String courseId;
  final String lectureId;
  final String title;
  final String? description;
  final String fileType;
  final ApiService apiService;
  final Function(UploadResult) onComplete;
  final Function(String) onError;

  const UploadProgressDialog({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.courseId,
    required this.lectureId,
    required this.title,
    this.description,
    this.fileType = 'video',
    required this.apiService,
    required this.onComplete,
    required this.onError,
  });

  @override
  State<UploadProgressDialog> createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<UploadProgressDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  double _uploadProgress = 0.0;
  bool _isUploading = false;
  String _uploadStatus = 'Preparing upload...';
  int _currentChunk = 0;
  int _totalChunks = 0;
  String _sessionId = '';
  bool _isComplete = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Start the upload process after the dialog is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startUpload();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startUpload() {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Starting upload...';
    });
    _animationController.forward();

    // Start the actual chunked upload
    _performChunkedUpload();
  }

  Future<void> _performChunkedUpload() async {
    try {
      final uploader = ChunkedUploader(
        apiService: widget.apiService,
        onProgress: _updateProgress,
        onComplete: _onComplete,
        onError: _onError,
      );

      await uploader.uploadFile(
        filePath: widget.filePath,
        courseId: widget.courseId,
        lectureId: widget.lectureId,
        title: widget.title,
        description: widget.description,
        fileType: widget.fileType,
      );
    } catch (e) {
      _onError(e.toString());
    }
  }

  void _updateProgress(UploadProgress progress) {
    setState(() {
      _uploadProgress = progress.percentage / 100.0;
      _currentChunk = progress.chunkIndex + 1;
      _totalChunks = progress.totalChunks;
      _sessionId = progress.uploadSessionId;
      _uploadStatus =
          'Uploading chunk $_currentChunk of $_totalChunks (${progress.percentage}%)';
    });
  }

  void _onComplete(UploadResult result) {
    setState(() {
      _isComplete = true;
      _uploadProgress = 1.0;
      _uploadStatus = 'Upload completed successfully!';
    });

    // Wait a moment to show completion, then close
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onComplete(result);
      }
    });
  }

  void _onError(String error) {
    setState(() {
      _isUploading = false;
      _errorMessage = error;
      _uploadStatus = 'Upload failed: $error';
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onError(error);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.cloud_upload,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Uploading File',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.fileName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Progress Section
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Column(
                  children: [
                    // Circular Progress Indicator
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: _isUploading
                                ? _uploadProgress
                                : _animation.value,
                            strokeWidth: 6,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _isComplete
                                  ? Colors.green
                                  : _errorMessage.isNotEmpty
                                      ? Colors.red
                                      : Colors.blue,
                            ),
                          ),
                        ),
                        Text(
                          _isUploading
                              ? '${(_uploadProgress * 100).toStringAsFixed(0)}%'
                              : _isComplete
                                  ? '✓'
                                  : _errorMessage.isNotEmpty
                                      ? '✗'
                                      : '0%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isComplete
                                ? Colors.green
                                : _errorMessage.isNotEmpty
                                    ? Colors.red
                                    : Colors.blue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Progress Bar
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey[300],
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor:
                            _isUploading ? _uploadProgress : _animation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              colors: _isComplete
                                  ? [Colors.green, Colors.greenAccent]
                                  : _errorMessage.isNotEmpty
                                      ? [Colors.red, Colors.redAccent]
                                      : [Colors.blue, Colors.blueAccent],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Status Text
                    Text(
                      _uploadStatus,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _isComplete
                                ? Colors.green
                                : _errorMessage.isNotEmpty
                                    ? Colors.red
                                    : Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                      textAlign: TextAlign.center,
                    ),

                    if (_totalChunks > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Chunk $_currentChunk of $_totalChunks',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],

                    if (_sessionId.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Session: ${_sessionId.substring(0, 8)}...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                              fontFamily: 'monospace',
                            ),
                      ),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Cancel Button (only show if not complete and not error)
            if (!_isComplete && _errorMessage.isEmpty)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel Upload',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
