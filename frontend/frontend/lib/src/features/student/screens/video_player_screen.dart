import 'dart:io';
import 'dart:async'; // Add Timer import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../core/services/video_download_service.dart';
import '../../../core/services/api_service.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String lectureId;
  final String lectureTitle;
  final String courseTitle;
  final String? videoUrl; // Made optional for streaming API
  final bool needsStreamingUrl; // Flag to fetch signed URL

  const VideoPlayerScreen({
    super.key,
    required this.lectureId,
    required this.lectureTitle,
    required this.courseTitle,
    this.videoUrl,
    this.needsStreamingUrl = false,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  double _progress = 0.0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isVideoInitialized = false;
  String? _errorMessage;
  String? _streamingUrl; // Store the signed URL from streaming API
  String? _streamingType; // Store streaming type (hls or single)
  bool _isLoadingStreamingUrl = false;

  // New video control states
  bool _isFullScreen = false;
  double _playbackSpeed = 1.0;
  bool _showControls = true;
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;
  Timer? _controlsTimer; // Timer for auto-hiding controls

  final List<Map<String, dynamic>> _notes = [];
  final List<Map<String, dynamic>> _bookmarks = [];
  final TextEditingController _noteController = TextEditingController();

  // Download functionality
  final VideoDownloadService _downloadService = VideoDownloadService();
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isDownloaded = false;

  // API service
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize animation controller for controls
    _controlsAnimationController = AnimationController(
      // Slower animation for a smoother transition
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _controlsAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    ));

    _loadMockData();
    _initializeVideo();
    _checkDownloadStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    _controlsAnimationController.dispose();
    _videoController?.dispose();
    _controlsTimer?.cancel(); // Cancel timer when widget is disposed

    // Reset orientation and system UI when leaving the video player
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      String? videoUrl = widget.videoUrl;

      // Check if the video is downloaded and use the local file if available
      final isDownloaded =
          await _downloadService.isVideoDownloaded(widget.lectureId);
      if (isDownloaded) {
        print('Video is downloaded, attempting to use local file');
        final videoFile =
            await _downloadService.getDecryptedVideoFile(widget.lectureId);
        if (videoFile != null && await videoFile.exists()) {
          videoUrl = videoFile.path;
          print('Using downloaded video file: $videoUrl');

          // Update state
          setState(() {
            _isDownloaded = true;
            _streamingUrl = videoUrl;
          });
        } else {
          print(
              'Downloaded video file not accessible, falling back to streaming');
          setState(() {
            _isDownloaded = false;
          });
        }
      }

      // If we need to fetch streaming URL, do that first
      if (widget.needsStreamingUrl && videoUrl == null) {
        setState(() {
          _isLoadingStreamingUrl = true;
        });

        try {
          final streamingResponse =
              await _apiService.getStreamingUrl(widget.lectureId);
          if (streamingResponse['success'] == true) {
            final lectureData = streamingResponse['lecture'];
            videoUrl = lectureData['video_url'];
            _streamingType = lectureData['streaming_type'];

            // Store the streaming URL for downloads and external opening
            setState(() {
              _streamingUrl = videoUrl;
            });

            print('Streaming URL fetched: $videoUrl');
            print('Streaming type: $_streamingType');
          } else {
            throw Exception(
                streamingResponse['error'] ?? 'Failed to get streaming URL');
          }
        } catch (e) {
          setState(() {
            _errorMessage = 'Failed to get video URL: $e';
            _isLoadingStreamingUrl = false;
          });
          return;
        }

        setState(() {
          _isLoadingStreamingUrl = false;
        });
      }

      if (videoUrl != null && videoUrl.isNotEmpty) {
        print('Loading video URL: $videoUrl'); // Debug log

        // Validate URL format
        if (!_isValidVideoUrl(videoUrl)) {
          setState(() {
            _errorMessage = 'Invalid video URL format: $videoUrl';
          });
          return;
        }

        // Check if it's a local file (offline video)
        if (videoUrl.startsWith('/') || videoUrl.startsWith('file://')) {
          print('Initializing local video file: $videoUrl');
          try {
            // Normalize the file path - remove any 'file://' prefix
            String normalizedPath = videoUrl;
            if (normalizedPath.startsWith('file://')) {
              normalizedPath = normalizedPath.substring(7);
            }

            final file = File(normalizedPath);

            // Check if file exists
            if (!await file.exists()) {
              print(
                  'Local video file does not exist, attempting to recreate: $normalizedPath');

              // If this is a cache file, it might have been deleted after hot reload
              if (normalizedPath.contains('/cache/')) {
                // Try to get a fresh file from the download service
                final videoFile = await _downloadService
                    .getDecryptedVideoFile(widget.lectureId);
                if (videoFile != null && await videoFile.exists()) {
                  print('Successfully retrieved fresh file: ${videoFile.path}');
                  _videoController = VideoPlayerController.file(videoFile);

                  // Update the path for future reference
                  setState(() {
                    _streamingUrl = videoFile.path;
                  });
                } else {
                  throw Exception('Could not retrieve video file after reload');
                }
              } else {
                throw Exception(
                    'Local video file does not exist: $normalizedPath');
              }
            } else {
              print(
                  'Local video file exists, size: ${await file.length()} bytes');
              _videoController = VideoPlayerController.file(file);
            }
          } catch (e) {
            print('Error initializing local video file: $e');
            // Instead of throwing, try to fall back to streaming
            if (widget.needsStreamingUrl) {
              print('Falling back to streaming after local file error');
              setState(() {
                _isDownloaded = false;
                _errorMessage = null;
              });

              // Reset videoUrl to null and try to get streaming URL
              videoUrl = null;

              // Try to get streaming URL
              try {
                final streamingResponse =
                    await _apiService.getStreamingUrl(widget.lectureId);
                if (streamingResponse['success'] == true) {
                  final lectureData = streamingResponse['lecture'];
                  videoUrl = lectureData['video_url'];
                  _streamingType = lectureData['streaming_type'];
                  print('Falling back to streaming URL: $videoUrl');
                  _videoController =
                      VideoPlayerController.networkUrl(Uri.parse(videoUrl!));
                } else {
                  throw Exception(streamingResponse['error'] ??
                      'Failed to get streaming URL');
                }
              } catch (streamingError) {
                print(
                    'Failed to get streaming URL as fallback: $streamingError');
                throw Exception(
                    'Cannot play video: $e. Streaming fallback also failed: $streamingError');
              }
            } else {
              throw Exception('Cannot open local video file: $e');
            }
          }
        } else {
          print('Initializing network video URL: $videoUrl');
          _videoController =
              VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        }

        // Add error listener with more detailed error handling
        _videoController!.addListener(() {
          if (_videoController!.value.hasError) {
            final error = _videoController!.value.errorDescription;
            print('Video error: $error'); // Debug log

            setState(() {
              _errorMessage = _getDetailedErrorMessage(error);
            });
          }
        });

        // Add timeout for initialization with longer duration
        await _videoController!.initialize().timeout(
          const Duration(minutes: 2), // Increased from 30 seconds to 2 minutes
          onTimeout: () {
            throw Exception('Video initialization timeout after 2 minutes');
          },
        );

        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
            _totalDuration = _videoController!.value.duration;
          });

          // Add listener for position updates
          _videoController!.addListener(_videoListener);
        }
      } else {
        setState(() {
          _errorMessage = 'No video URL provided';
        });
      }
    } catch (e) {
      print('Video initialization error: $e'); // Debug log
      setState(() {
        _errorMessage = 'Failed to load video: $e\nURL: ${widget.videoUrl}';
      });
    }
  }

  bool _isValidVideoUrl(String url) {
    try {
      // Handle local file paths that start with / (Android paths)
      if (url.startsWith('/data/') ||
          url.startsWith('/storage/') ||
          url.startsWith('/cache/') ||
          url.contains('/cache/')) {
        print('Valid local Android file path: $url');
        return true;
      }

      // Handle file:// URLs
      if (url.startsWith('file://')) {
        print('Valid file:// URL: $url');
        return true;
      }

      // Handle regular http(s) URLs
      final uri = Uri.parse(url);
      final isValid = uri.hasScheme &&
          (uri.scheme == 'http' ||
              uri.scheme == 'https' ||
              uri.scheme == 'file');

      if (isValid) {
        print('Valid URL with scheme ${uri.scheme}: $url');
      } else {
        print('Invalid URL scheme ${uri.scheme}: $url');
      }

      return isValid;
    } catch (e) {
      print('Invalid URL format: $url - Error: $e');
      return false;
    }
  }

  String _getDetailedErrorMessage(String? error) {
    if (error == null) return 'Unknown video error';

    // Parse common ExoPlayer errors
    if (error.contains('Source error') ||
        error.contains('SocketTimeoutException')) {
      return 'Video source error: The video file may be taking too long to download.\n\nTry:\n• Checking your internet connection\n• Retrying the video with the retry button below\n• Opening the video externally\n• Contacting support if the issue persists';
    } else if (error.contains('Network error')) {
      return 'Network error: Unable to download the video.\n\nTry:\n• Checking your internet connection\n• Retrying the video with the retry button below\n• Opening externally as fallback';
    } else if (error.contains('Decoder error')) {
      return 'Video decoder error: The video format is not supported by your device.\n\nTry:\n• Opening the video externally\n• Using a different device\n• Contacting support';
    } else if (error.contains('Renderer error')) {
      return 'Video renderer error: Unable to display the video.\n\nTry:\n• Restarting the app\n• Opening the video externally\n• Using a different device';
    } else if (error.contains('Timeout') || error.contains('timed out')) {
      return 'Video loading timeout: The video took too long to load.\n\nTry:\n• Checking your internet connection\n• Retrying the video with the retry button below\n• Opening externally';
    } else if (error.contains('ExoPlaybackException')) {
      return 'Video playback error: There was a problem with the video player.\n\nTry:\n• Retrying the video with the retry button below\n• Checking your internet connection\n• Opening the video externally';
    }

    return 'Video playback error: $error';
  }

  void _videoListener() {
    if (_videoController != null && mounted) {
      setState(() {
        _currentPosition = _videoController!.value.position;
        _totalDuration = _videoController!.value.duration;
        _isPlaying = _videoController!.value.isPlaying;
        _progress = _totalDuration.inMilliseconds > 0
            ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
            : 0.0;
      });
    }
  }

  void _loadMockData() {
    // Mock notes and bookmarks
    _notes.addAll([
      {
        'id': '1',
        'text': 'Important concept about state management',
        'position': 120,
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      },
      {
        'id': '2',
        'text': 'Remember to implement error handling here',
        'position': 300,
        'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
      },
    ]);

    _bookmarks.addAll([
      {
        'id': '1',
        'title': 'State Management Introduction',
        'position': 120,
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      },
      {
        'id': '2',
        'title': 'Error Handling Section',
        'position': 300,
        'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
      },
    ]);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  void _addBookmark() {
    final bookmark = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': 'Bookmark at ${_formatDuration(_currentPosition)}',
      'position': _currentPosition.inSeconds,
      'timestamp': DateTime.now(),
    };

    setState(() {
      _bookmarks.add(bookmark);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bookmark added at ${_formatDuration(_currentPosition)}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _addNote() {
    if (_noteController.text.trim().isNotEmpty) {
      final note = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': _noteController.text.trim(),
        'position': _currentPosition.inSeconds,
        'timestamp': DateTime.now(),
      };

      setState(() {
        _notes.add(note);
      });

      _noteController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note added successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _openInExternalPlayer() async {
    try {
      // Use the streaming URL if available, otherwise use widget videoUrl
      final videoUrl = _streamingUrl ?? widget.videoUrl;
      if (videoUrl == null || videoUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No video URL available to open externally'),
          ),
        );
        return;
      }

      final uri = Uri.parse(videoUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open video: $videoUrl'),
            action: SnackBarAction(
              label: 'Copy Link',
              onPressed: () {
                // TODO: Copy link to clipboard
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening video: $e'),
        ),
      );
    }
  }

  // Method to retry with a fresh streaming URL
  void _retryWithFreshUrl() async {
    setState(() {
      _isLoadingStreamingUrl = true;
      _errorMessage = null;
    });

    try {
      // Dispose current controller if it exists
      if (_videoController != null) {
        await _videoController!.dispose();
        _videoController = null;
      }

      // Try to refresh the streaming URL first
      if (widget.needsStreamingUrl) {
        try {
          final refreshResponse =
              await _apiService.refreshStreamingUrl(widget.lectureId);
          if (refreshResponse['success'] == true) {
            final lectureData = refreshResponse['lecture'];
            _streamingUrl = lectureData['video_url'];
            _streamingType = lectureData['streaming_type'];

            print('Refreshed streaming URL: $_streamingUrl');
            print('Streaming type: $_streamingType');
          }
        } catch (e) {
          print('Failed to refresh streaming URL: $e');
          // Continue with initialization anyway, using the original URL
        }
      }

      // Initialize video with potentially new URL
      await _initializeVideo();
    } catch (e) {
      setState(() {
        _isLoadingStreamingUrl = false;
        _errorMessage = 'Failed to retry: $e';
      });
    }
  }

  // Check if video is already downloaded
  Future<void> _checkDownloadStatus() async {
    try {
      final isDownloaded =
          await _downloadService.isVideoDownloaded(widget.lectureId);

      if (isDownloaded) {
        // Verify the downloaded file can be accessed
        final videoFile =
            await _downloadService.getDecryptedVideoFile(widget.lectureId);
        if (videoFile != null && await videoFile.exists()) {
          print(
              'Downloaded video verified: ${videoFile.path}, size: ${await videoFile.length()} bytes');
        } else {
          print('Downloaded video exists but cannot be accessed');
          // If file can't be accessed, consider it not downloaded
          if (mounted) {
            setState(() {
              _isDownloaded = false;
            });
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _isDownloaded = isDownloaded;
        });
      }
    } catch (e) {
      print('Error checking download status: $e');
      if (mounted) {
        setState(() {
          _isDownloaded = false;
        });
      }
    }
  }

  // Download video for offline viewing
  Future<void> _downloadVideo() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      // Use the streaming URL if available, otherwise use widget videoUrl
      final videoUrl = _streamingUrl ?? widget.videoUrl;
      if (videoUrl == null || videoUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No video URL available for download'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final result = await _downloadService.downloadVideo(
        videoUrl: videoUrl,
        lectureId: widget.lectureId,
        lectureTitle: widget.lectureTitle,
        courseTitle: widget.courseTitle,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        if (result['success']) {
          setState(() {
            _isDownloaded = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: AppColors.success,
              action: SnackBarAction(
                label: 'View Downloads',
                textColor: Colors.white,
                onPressed: () {
                  context.push('/student/downloaded-videos');
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  // Delete downloaded video
  Future<void> _deleteDownloadedVideo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Downloaded Video'),
        content: const Text(
            'Are you sure you want to delete this downloaded video? You will need to download it again to watch offline.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await _downloadService.deleteDownloadedVideo(widget.lectureId);
      if (mounted) {
        if (success) {
          setState(() {
            _isDownloaded = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Downloaded video deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete downloaded video'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // New video control methods
  void _jumpForward() {
    if (_videoController != null) {
      final currentPosition = _videoController!.value.position;
      final newPosition = currentPosition + const Duration(seconds: 10);
      _videoController!.seekTo(newPosition);
    }
  }

  void _jumpBackward() {
    if (_videoController != null) {
      final currentPosition = _videoController!.value.position;
      final newPosition = currentPosition - const Duration(seconds: 10);
      _videoController!.seekTo(newPosition);
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      // Always show controls when toggling fullscreen
      _showControls = true;
    });

    // Cancel any existing timer
    _controlsTimer?.cancel();

    if (_isFullScreen) {
      // Enter fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      // In landscape mode, controls are always visible, no need for timer
      _controlsAnimationController.reverse();
    } else {
      // Exit fullscreen - restore portrait mode and normal UI
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Show controls briefly when exiting fullscreen
      _controlsAnimationController.reverse();
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _showControls && _isPlaying) {
          setState(() {
            _showControls = false;
          });
          _controlsAnimationController.forward();
        }
      });
    }
  }

  void _changePlaybackSpeed(double speed) {
    if (_videoController != null) {
      _videoController!.setPlaybackSpeed(speed);
      setState(() {
        _playbackSpeed = speed;
      });
    }
  }

  // Add a dedicated method for toggling play/pause
  void _togglePlayPause() {
    if (_videoController != null) {
      setState(() {
        if (_isPlaying) {
          _videoController!.pause();
        } else {
          _videoController!.play();
        }
      });
    }
  }

  void _toggleControls() {
    // Cancel any existing timer
    _controlsTimer?.cancel();

    // In landscape mode, toggle controls visibility instead of play/pause
    if (_isFullScreen) {
      setState(() {
        _showControls = !_showControls;
      });
      return;
    }

    // In portrait mode, toggle controls visibility
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _controlsAnimationController.reverse();

      // Start a timer to auto-hide controls (only in portrait mode)
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _showControls && _isPlaying) {
          setState(() {
            _showControls = false;
          });
          _controlsAnimationController.forward();
        }
      });
    } else {
      _controlsAnimationController.forward();
    }
  }

  void _showSpeedSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      isScrollControlled: true, // Allow custom height
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height *
              0.6, // Max 60% of screen height
          minHeight: 200, // Minimum height
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Playback Speed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Make the speed options scrollable
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _getSpeedOptions()
                      .map((option) => ListTile(
                            title: Text(
                              option['label'],
                              style: TextStyle(
                                color: _playbackSpeed == option['speed']
                                    ? AppColors.primaryLight
                                    : Colors.white,
                                fontWeight: _playbackSpeed == option['speed']
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            onTap: () {
                              _changePlaybackSpeed(option['speed']);
                              Navigator.pop(context);
                            },
                          ))
                      .toList(),
                ),
              ),
            ),
            // Add some bottom padding for better UX
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getSpeedOptions() {
    return [
      {'label': '0.5x', 'speed': 0.5},
      {'label': '0.75x', 'speed': 0.75},
      {'label': '1x', 'speed': 1.0},
      {'label': '1.25x', 'speed': 1.25},
      {'label': '1.5x', 'speed': 1.5},
      {'label': '2x', 'speed': 2.0},
    ];
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    double size = 24,
    bool isPrimary = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.primaryLight.withOpacity(0.2)
            : Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPrimary
              ? AppColors.primaryLight.withOpacity(0.5)
              : Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: size),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _retryWithFreshUrl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Retry Video'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _openInExternalPlayer,
                  child: const Text('Open Externally'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_isLoadingStreamingUrl) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'Getting Video Access...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Securing video stream...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isVideoInitialized || _videoController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'Loading Video...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            if (_streamingType != null) ...[
              const SizedBox(height: 8),
              Text(
                'Streaming type: $_streamingType',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_isFullScreen) {
      // In fullscreen mode, use split screen for double-tap gestures
      return Stack(
        children: [
          // Center video player
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),

          // Overlay for gestures - always active in fullscreen
          Row(
            children: [
              // Left side for backward navigation (double tap)
              Expanded(
                child: GestureDetector(
                  onTap: _toggleControls,
                  onDoubleTap: _jumpBackward,
                  behavior: HitTestBehavior.translucent,
                ),
              ),

              // Right side for forward navigation (double tap)
              Expanded(
                child: GestureDetector(
                  onTap: _toggleControls,
                  onDoubleTap: _jumpForward,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // In portrait mode, use regular tap behavior
      return GestureDetector(
        onTap: _toggleControls,
        child: Center(
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lectureTitle = widget.lectureTitle;

    if (_isFullScreen) {
      return PopScope(
        canPop: false, // Prevent default back navigation
        onPopInvoked: (didPop) {
          if (!didPop) {
            // Exit fullscreen instead of navigating back
            _toggleFullScreen();
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Fullscreen Video Player
              Positioned.fill(
                child: _buildVideoPlayer(),
              ),

              // Fullscreen Controls - toggle visibility with single tap
              if (_showControls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildFullscreenTopBar(),
                ),

              if (_showControls)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildFullscreenControls(),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          lectureTitle,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Show more options
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Video Player Section
            Expanded(
              child: Stack(
                children: [
                  // Video Player
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.black,
                    alignment: Alignment.center, // Center the video
                    child: _buildVideoPlayer(),
                  ),

                  // Top Bar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildTopBar(),
                  ),

                  // Video Controls
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedBuilder(
                      animation: _controlsAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _controlsAnimation.value * 100),
                          child: Opacity(
                            opacity: 1.0 - _controlsAnimation.value,
                            child: _buildVideoControls(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Content Tabs
            Container(
              height: 300,
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  // Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Notes'),
                        Tab(text: 'Bookmarks'),
                      ],
                    ),
                  ),

                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildNotesTab(),
                        _buildBookmarksTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: const EdgeInsets.all(8),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.lectureTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.courseTitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add, color: Colors.white, size: 20),
            onPressed: _addBookmark,
            tooltip: 'Add Bookmark',
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: const EdgeInsets.all(8),
          ),
          IconButton(
            icon: const Icon(Icons.note_add, color: Colors.white, size: 20),
            onPressed: () {
              _tabController.animateTo(1);
              _showAddNoteDialog();
            },
            tooltip: 'Add Note',
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.8),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress Bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primaryLight,
                inactiveTrackColor: Colors.white.withOpacity(0.2),
                thumbColor: Colors.white,
                overlayColor: AppColors.primaryLight.withOpacity(0.3),
                trackHeight: 4.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: _progress.clamp(0.0, 1.0),
                onChanged: (value) {
                  if (_videoController != null) {
                    final position = _totalDuration * value;
                    _videoController!.seekTo(position);
                  }
                },
              ),
            ),
          ),

          // Time and Controls
          Row(
            children: [
              Flexible(
                child: Text(
                  _formatDuration(_currentPosition),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),

              // 10-second backward button
              IconButton(
                icon:
                    const Icon(Icons.replay_10, color: Colors.white, size: 24),
                onPressed: _jumpBackward,
                tooltip: 'Jump Back 10s',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),

              // Play/Pause button
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 28,
                ),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () {
                  if (_videoController != null) {
                    if (_isPlaying) {
                      _videoController!.pause();
                    } else {
                      _videoController!.play();
                    }
                  }
                },
              ),

              // 10-second forward button
              IconButton(
                icon:
                    const Icon(Icons.forward_10, color: Colors.white, size: 24),
                onPressed: _jumpForward,
                tooltip: 'Jump Forward 10s',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),

              const Spacer(),
              Flexible(
                child: Text(
                  _formatDuration(_totalDuration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Additional Controls Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Speed control
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Text(
                    '${_playbackSpeed}x',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  onPressed: _showSpeedSelector,
                  tooltip: 'Playback Speed',
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
              ),

              // Fullscreen button
              _buildControlButton(
                icon: Icons.fullscreen,
                onPressed: _toggleFullScreen,
                tooltip: 'Fullscreen',
                size: 20,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Download Progress or Download Button
          if (_isDownloading)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.download, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Downloading... ${(_downloadProgress * 100).toInt()}%',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryLight),
                  ),
                ),
              ],
            )
          else if (_isDownloaded)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.download_done,
                      color: Colors.green, size: 20),
                  onPressed: _deleteDownloadedVideo,
                  tooltip: 'Delete Downloaded Video',
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: const EdgeInsets.all(8),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Downloaded',
                    style: const TextStyle(color: Colors.green, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon:
                      const Icon(Icons.download, color: Colors.white, size: 20),
                  onPressed: _downloadVideo,
                  tooltip: 'Download for Offline Viewing',
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: const EdgeInsets.all(8),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Download',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFullscreenTopBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.black.withOpacity(0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Row(
          children: [
            // Back button
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                onPressed: _toggleFullScreen,
                tooltip: 'Exit Fullscreen',
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.lectureTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Exit fullscreen button
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.fullscreen_exit,
                    color: Colors.white, size: 24),
                onPressed: _toggleFullScreen,
                tooltip: 'Exit Fullscreen',
                padding: const EdgeInsets.all(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Control buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Download button (left)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon:
                      const Icon(Icons.download, color: Colors.white, size: 20),
                  onPressed: _isDownloaded ? null : _downloadVideo,
                  tooltip:
                      _isDownloaded ? 'Already Downloaded' : 'Download Video',
                ),
              ),

              // Central Play/Pause button
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                ),
                child: IconButton(
                  iconSize: 32,
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: _togglePlayPause,
                  tooltip: _isPlaying ? 'Pause' : 'Play',
                ),
              ),

              // Speed button (right)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton.icon(
                  icon: const Icon(Icons.speed, color: Colors.white, size: 16),
                  label: Text(
                    '${_playbackSpeed}x',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  onPressed: _showSpeedSelector,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryLight,
              inactiveTrackColor: Colors.white.withOpacity(0.2),
              thumbColor: Colors.white,
              overlayColor: AppColors.primaryLight.withOpacity(0.3),
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: _progress.clamp(0.0, 1.0),
              onChanged: (value) {
                if (_videoController != null) {
                  final position = _totalDuration * value;
                  _videoController!.seekTo(position);
                }
              },
            ),
          ),

          // Time indicators
          Row(
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const Spacer(),
              Text(
                _formatDuration(_totalDuration),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 48,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lecture Progress',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(_progress * 100).toInt()}% complete',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Lecture Info
          Text(
            'Lecture Information',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 16),

          _buildInfoRow('Title', widget.lectureTitle),
          _buildInfoRow('Course', widget.courseTitle),
          _buildInfoRow('Duration', _formatDuration(_totalDuration)),
          _buildInfoRow('Current Position', _formatDuration(_currentPosition)),

          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 400) {
                // Stack buttons vertically on small screens
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addBookmark,
                        icon: const Icon(Icons.bookmark_add, size: 18),
                        label: const Text('Add Bookmark'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                          side: BorderSide(
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddNoteDialog(),
                        icon: const Icon(Icons.note_add, size: 18),
                        label: const Text('Add Note'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.secondary,
                          side: BorderSide(
                              color: Theme.of(context).colorScheme.secondary),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // Side by side on larger screens
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addBookmark,
                        icon: const Icon(Icons.bookmark_add, size: 18),
                        label: const Text('Add Bookmark'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                          side: BorderSide(
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddNoteDialog(),
                        icon: const Icon(Icons.note_add, size: 18),
                        label: const Text('Add Note'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.secondary,
                          side: BorderSide(
                              color: Theme.of(context).colorScheme.secondary),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    return Column(
      children: [
        // Add Note Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    hintText: 'Add a note...',
                    hintStyle: const TextStyle(fontSize: 12),
                    border: const OutlineInputBorder(),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  maxLines: 1,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addNote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  minimumSize: const Size(60, 36),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Add', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        // Notes List
        Expanded(
          child: _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.note,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No notes yet',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add notes while watching the lecture',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return _buildNoteCard(note);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBookmarksTab() {
    return Column(
      children: [
        // Add Bookmark Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 350) {
                // Stack vertically on very small screens
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Position: ${_formatDuration(_currentPosition)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addBookmark,
                        icon: const Icon(Icons.bookmark_add, size: 16),
                        label: const Text('Add Bookmark'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // Side by side on larger screens
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Current Position: ${_formatDuration(_currentPosition)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _addBookmark,
                      icon: const Icon(Icons.bookmark_add, size: 16),
                      label: const Text('Add Bookmark'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        minimumSize: const Size(120, 36),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),

        // Bookmarks List
        Expanded(
          child: _bookmarks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No bookmarks yet',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add bookmarks to quickly navigate to important parts',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookmarks.length,
                  itemBuilder: (context, index) {
                    final bookmark = _bookmarks[index];
                    return _buildBookmarkCard(bookmark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                // Use theme colors instead of hardcoded colors for better dark mode support
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                // Use theme colors instead of hardcoded colors for better dark mode support
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.backgroundMedium,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatDuration(Duration(seconds: note['position'] as int)),
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatTimestamp(note['timestamp'] as DateTime),
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            note['text'] as String,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkCard(Map<String, dynamic> bookmark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.backgroundMedium,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bookmark,
              color: AppColors.primaryLight,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookmark['title'] as String,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(bookmark['timestamp'] as DateTime),
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add a note at: ${_formatDuration(_currentPosition)}'),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: 'Enter your note...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _addNote();
              Navigator.pop(context);
            },
            child: const Text('Add Note'),
          ),
        ],
      ),
    );
  }
}
