import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/stats_card.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/upload_progress_dialog.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';

class AdminLectureManagementScreen extends ConsumerStatefulWidget {
  const AdminLectureManagementScreen({super.key});

  @override
  ConsumerState<AdminLectureManagementScreen> createState() =>
      _AdminLectureManagementScreenState();
}

class _AdminLectureManagementScreenState
    extends ConsumerState<AdminLectureManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String _selectedCourse = 'All';

  // Real data from API
  List<Map<String, dynamic>> _lectures = [];
  Map<String, dynamic>? _lecturesData;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _analytics = {};

  final List<String> _statusFilters = [
    'All',
    'Published',
    'Draft',
    'Processing'
  ];

  List<String> _courseFilters = ['All'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchLecturesData();
  }

  Future<void> _fetchLecturesData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final apiService = ApiService();
      final response = await apiService.getAdminLectures();

      if (mounted) {
        setState(() {
          _lecturesData = response;
          _lectures =
              List<Map<String, dynamic>>.from(response['lectures'] ?? []);
          _analytics = response['analytics'] ?? {};

          // Extract course names for filter
          final courses = _lectures
              .map((lecture) => lecture['course_title'] as String? ?? 'Unknown')
              .toSet()
              .toList();
          _courseFilters = ['All', ...courses];

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredLectures {
    var filtered = _lectures;

    if (_selectedFilter != 'All') {
      filtered = filtered
          .where((lecture) => lecture['status'] == _selectedFilter)
          .toList();
    }

    if (_selectedCourse != 'All') {
      filtered = filtered
          .where((lecture) => lecture['course_title'] == _selectedCourse)
          .toList();
    }

    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered.where((lecture) {
        final title = (lecture['title'] as String? ?? '').toLowerCase();
        final course = (lecture['course_title'] as String? ?? '').toLowerCase();
        final teacher =
            (lecture['instructor_name'] as String? ?? '').toLowerCase();
        return title.contains(searchTerm) ||
            course.contains(searchTerm) ||
            teacher.contains(searchTerm);
      }).toList();
    }

    return filtered;
  }

  Future<void> _showUploadDialog() async {
    String? selectedCourseId;
    String lectureTitle = '';
    String lectureDescription = '';
    PlatformFile? selectedFile;

    // Get available courses for lecture upload
    final apiService = ApiService();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Upload Lecture'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Course Selection
                      FutureBuilder<Map<String, dynamic>>(
                        future: apiService.getAdminCourses(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }

                          final courses =
                              snapshot.data?['courses'] as List<dynamic>? ?? [];

                          // Set default value if not already set and courses are available
                          if (selectedCourseId == null && courses.isNotEmpty) {
                            selectedCourseId = courses.first['id'].toString();
                          }

                          if (courses.isEmpty) {
                            return Text(
                              'No courses available. Please create a course first.',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error),
                            );
                          }

                          return DropdownButtonFormField<String>(
                            value: selectedCourseId,
                            decoration: const InputDecoration(
                              labelText: 'Select Course',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 16),
                            ),
                            isExpanded: true,
                            isDense: true,
                            style: const TextStyle(fontSize: 14),
                            items: courses.map((course) {
                              return DropdownMenuItem<String>(
                                value: course['id'].toString(),
                                child: Text(
                                  course['title'] ?? 'Unknown Course',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            selectedItemBuilder: (BuildContext context) {
                              return courses.map<Widget>((course) {
                                return Text(
                                  course['title'] ?? 'Unknown Course',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(fontSize: 14),
                                );
                              }).toList();
                            },
                            onChanged: (value) {
                              setDialogState(() {
                                selectedCourseId = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a course';
                              }
                              return null;
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Lecture Title
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Lecture Title',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          lectureTitle = value;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Lecture Description field
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Lecture Description (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 1,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        onChanged: (value) {
                          lectureDescription = value;
                        },
                      ),

                      const SizedBox(height: 16),

                      // File Selection
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            if (selectedFile == null)
                              const Column(
                                children: [
                                  Icon(Icons.cloud_upload,
                                      size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Select a file to upload'),
                                  Text('Supported: MP4, PDF, DOC, DOCX',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  Icon(
                                    _getFileIcon(selectedFile!.extension ?? ''),
                                    size: 32,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(selectedFile!.name),
                                  Text(
                                      '${(selectedFile!.size / 1024 / 1024).toStringAsFixed(1)} MB',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () async {
                                final result =
                                    await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: [
                                    'mp4',
                                    'mov',
                                    'avi',
                                    'pdf',
                                    'doc',
                                    'docx'
                                  ],
                                );

                                if (result != null && result.files.isNotEmpty) {
                                  setDialogState(() {
                                    selectedFile = result.files.first;
                                  });
                                }
                              },
                              child: Text(selectedFile == null
                                  ? 'Choose File'
                                  : 'Change File'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: (selectedCourseId != null &&
                          lectureTitle.isNotEmpty &&
                          selectedFile != null)
                      ? () async {
                          // Determine file type
                          String fileType = 'pdf';
                          if (selectedFile!.extension?.toLowerCase() == 'mp4' ||
                              selectedFile!.extension?.toLowerCase() == 'mov' ||
                              selectedFile!.extension?.toLowerCase() == 'avi') {
                            fileType = 'video';
                          }

                          // Generate unique lecture ID
                          String lectureId =
                              'lecture_${DateTime.now().millisecondsSinceEpoch}';

                          // Get file size to determine if we need chunked upload
                          final file = File(selectedFile!.path!);
                          final fileSize = await file.length();
                          final isLargeFile =
                              fileSize > 50 * 1024 * 1024; // 50MB threshold

                          if (isLargeFile) {
                            // Use chunked upload for large files
                            _showChunkedUploadDialog(
                              context,
                              selectedFile!.path!,
                              selectedCourseId!,
                              lectureId,
                              lectureTitle,
                              lectureDescription,
                              fileType,
                            );
                          } else {
                            // Use regular upload for small files
                            _performRegularUpload(
                              context,
                              selectedFile!.path!,
                              selectedCourseId!,
                              lectureId,
                              fileType,
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Upload'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.file_present;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.background.withOpacity(0.98)
            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.background.withOpacity(0.98)
            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        appBar: AppBar(
          title: const Text('Lecture Management'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surface.withOpacity(0.9)
              : AppColors.backgroundDark,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          actions: const [
            ThemeToggleButton(),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading lectures: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchLecturesData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.background.withOpacity(0.98)
          : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      appBar: AppBar(
        title: const Text('Lecture Management'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface.withOpacity(0.9)
            : AppColors.backgroundDark,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: const [
          ThemeToggleButton(),
        ],
      ),
      body: Column(
        children: [
          // Stats Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surface.withOpacity(0.9)
                : AppColors.backgroundDark,
            child: Row(
              children: [
                Expanded(
                  child: StatsCard(
                    title: 'Total\nLectures',
                    value: (_lecturesData?['overview']?['total_lectures'] ?? 0)
                        .toString(),
                    subtitle: 'All time',
                    icon: Icons.play_circle,
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatsCard(
                    title: 'Published\nLectures',
                    value:
                        (_lecturesData?['overview']?['published_lectures'] ?? 0)
                            .toString(),
                    subtitle: 'Live content',
                    icon: Icons.check_circle,
                    color: Colors.green,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatsCard(
                    title: 'Total\nViews',
                    value: (_lecturesData?['overview']?['total_views'] ?? 0)
                        .toString(),
                    subtitle: 'Student engagement',
                    icon: Icons.visibility,
                    color: Colors.blue,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),

          // Search and Filters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surface.withOpacity(0.95)
                : Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search lectures...',
                    hintStyle: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6)),
                    prefixIcon: Icon(Icons.search,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.3),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                // Filters Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedFilter,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          filled: true,
                          isDense: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.3),
                              width: 1.0,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.3),
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.0,
                            ),
                          ),
                        ),
                        isExpanded: true,
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        icon: const SizedBox.shrink(),
                        iconSize: 0,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13),
                        items: _statusFilters.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(
                              status,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFilter = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCourse,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          filled: true,
                          isDense: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.3),
                              width: 1.0,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.3),
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.0,
                            ),
                          ),
                        ),
                        isExpanded: true,
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        icon: const SizedBox.shrink(),
                        iconSize: 0,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13),
                        items: _courseFilters.map((course) {
                          return DropdownMenuItem(
                            value: course,
                            child: Text(
                              course.length > 20
                                  ? '${course.substring(0, 20)}...'
                                  : course,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCourse = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Upload Lecture button on separate line
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showUploadDialog,
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload Lecture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surface.withOpacity(0.98)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withOpacity(0.5)
                    : Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'All Lectures'),
                Tab(text: 'Analytics'),
                Tab(text: 'Content Quality'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllLecturesTab(),
                _buildAnalyticsTab(),
                _buildContentQualityTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllLecturesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredLectures.length,
      itemBuilder: (context, index) {
        final lecture = _filteredLectures[index];
        return _buildLectureCard(lecture);
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surface.withOpacity(0.95)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.3)
                      : Theme.of(context).shadowColor.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lecture Performance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.5)
                        : Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.2)
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: _buildLectureAnalyticsChart(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentQualityTab() {
    final qualityMetrics =
        _analytics['quality_metrics'] as Map<String, dynamic>? ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surface.withOpacity(0.95)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.3)
                    : Theme.of(context).shadowColor.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Content Quality Metrics',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 16),
              _buildQualityMetric(
                  'Lectures with Notes',
                  qualityMetrics['lectures_with_notes'] ?? 0,
                  _lectures.length,
                  Colors.green),
              _buildQualityMetric(
                  'Lectures with Subtitles',
                  qualityMetrics['lectures_with_subtitles'] ?? 0,
                  _lectures.length,
                  Colors.orange),
              _buildQualityMetric(
                  'HD Quality Videos',
                  qualityMetrics['hd_videos'] ?? 0,
                  _lectures.length,
                  Colors.blue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQualityMetric(
      String label, int current, int total, Color color) {
    final percentage = total > 0 ? (current / total * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$current/$total ($percentage%)',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: total > 0 ? current / total : 0,
            backgroundColor: Theme.of(context).colorScheme.outline,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildLectureAnalyticsChart() {
    final analyticsData = _analytics['view_trends'] as List<dynamic>? ?? [];

    if (analyticsData.isEmpty) {
      return Center(
        child: Text(
          'No analytics data available',
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final days = [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun'
                  ];
                  if (value.toInt() < days.length) {
                    return Text(days[value.toInt()],
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ));
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ));
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: analyticsData.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(),
                    (entry.value['views'] ?? 0).toDouble());
              }).toList(),
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLectureCard(Map<String, dynamic> lecture) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface.withOpacity(0.95)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.3)
                : Theme.of(context).shadowColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 400) {
                // Stack layout for small screens
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 45,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            _getContentTypeIcon(
                                lecture['content_type'] as String? ?? 'video'),
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lecture['title'] as String? ??
                                    'Untitled Lecture',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lecture['course_title'] as String? ??
                                    'Unknown Course',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (value) {
                            // TODO: Handle lecture action
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'duplicate',
                              child: Row(
                                children: [
                                  Icon(Icons.copy, size: 16),
                                  SizedBox(width: 8),
                                  Text('Duplicate'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                                    lecture['status'] as String? ?? '')
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            lecture['status'] as String? ?? 'Unknown',
                            style: TextStyle(
                              color: _getStatusColor(
                                  lecture['status'] as String? ?? ''),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            lecture['content_type'] as String? ?? 'Video',
                            style: const TextStyle(
                              color: Colors.purple,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${lecture['duration'] ?? '0:00'}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                // Original row layout for larger screens
                return Row(
                  children: [
                    Container(
                      width: 80,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _getContentTypeIcon(
                            lecture['content_type'] as String? ?? 'video'),
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lecture['title'] as String? ?? 'Untitled Lecture',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lecture['course_title'] as String? ??
                                'Unknown Course',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                          lecture['status'] as String? ?? '')
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  lecture['status'] as String? ?? 'Unknown',
                                  style: TextStyle(
                                    color: _getStatusColor(
                                        lecture['status'] as String? ?? ''),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  lecture['content_type'] as String? ?? 'Video',
                                  style: const TextStyle(
                                    color: Colors.purple,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        // TODO: Handle lecture actions
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'add_notes',
                          child: Row(
                            children: [
                              Icon(Icons.note_add, size: 18),
                              SizedBox(width: 8),
                              Text('Add Notes'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'add_subtitles',
                          child: Row(
                            children: [
                              Icon(Icons.subtitles, size: 18),
                              SizedBox(width: 8),
                              Text('Add Subtitles'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildLectureStat(
                  icon: Icons.person,
                  label: 'Teacher',
                  value: lecture['instructor_name'] as String? ?? 'Unknown',
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLectureStat(
                  icon: Icons.visibility,
                  label: 'Views',
                  value: (lecture['views'] ?? 0).toString(),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLectureStat(
                  icon: Icons.timer,
                  label: 'Duration',
                  value: _formatDuration(lecture['duration']),
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLectureStat(
                  icon: Icons.check_circle,
                  label: 'Completion',
                  value:
                      '${(lecture['completion_rate'] ?? 0).toStringAsFixed(1)}%',
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.upload_file,
                  label: 'File Size',
                  value: _formatFileSize(lecture['file_size']),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.calendar_today,
                  label: 'Upload Date',
                  value: _formatDate(lecture['created_at']),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.edit,
                  label: 'Last Modified',
                  value: _formatDate(lecture['updated_at']),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Content Features
          Row(
            children: [
              if (lecture['has_notes'] == true)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.note,
                        size: 14,
                        color: Colors.green,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Notes',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (lecture['has_subtitles'] == true)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.subtitles,
                        size: 14,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Subtitles',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getContentTypeIcon(String contentType) {
    switch (contentType.toLowerCase()) {
      case 'video':
        return Icons.play_circle;
      case 'document':
        return Icons.description;
      case 'pdf':
        return Icons.picture_as_pdf;
      default:
        return Icons.file_present;
    }
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return '0:00';
    if (duration is String) return duration;
    if (duration is int) {
      final hours = duration ~/ 3600;
      final minutes = (duration % 3600) ~/ 60;
      if (hours > 0) {
        return '$hours:${minutes.toString().padLeft(2, '0')}:00';
      } else {
        return '$minutes:00';
      }
    }
    return duration.toString();
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return 'Unknown';
    if (size is String) return size;
    if (size is int) {
      if (size > 1024 * 1024 * 1024) {
        return '${(size / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
      } else if (size > 1024 * 1024) {
        return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
      } else {
        return '${(size / 1024).toStringAsFixed(1)} KB';
      }
    }
    return size.toString();
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      if (date is String) {
        return DateTime.parse(date).toString().split(' ')[0];
      }
      return date.toString().split(' ')[0];
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildLectureStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return Colors.green;
      case 'draft':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      default:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    }
  }

  // Helper method to show chunked upload dialog
  void _showChunkedUploadDialog(
    BuildContext context,
    String filePath,
    String courseId,
    String lectureId,
    String title,
    String? description,
    String fileType,
  ) {
    // Close the upload dialog first
    Navigator.of(context).pop();

    // Show chunked upload progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UploadProgressDialog(
        filePath: filePath,
        fileName: File(filePath).path.split('/').last,
        courseId: courseId,
        lectureId: lectureId,
        title: title,
        description: description,
        fileType: fileType,
        apiService: ApiService(),
        onComplete: (result) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'File uploaded successfully! Size: ${(result.fileInfo['size'] / 1024 / 1024).toStringAsFixed(2)} MB'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );

          // Refresh the lectures list
          _fetchLecturesData();
        },
        onError: (error) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: $error'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        },
      ),
    );
  }

  // Helper method to perform regular upload for small files
  Future<void> _performRegularUpload(
    BuildContext context,
    String filePath,
    String courseId,
    String lectureId,
    String fileType,
  ) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final apiService = ApiService();

      // Upload file using regular method
      final result = await apiService.uploadLectureFile(
        filePath: filePath,
        courseId: courseId,
        lectureId: lectureId,
        fileType: fileType,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Close upload dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('File uploaded successfully! URL: ${result['file']['url']}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      // Refresh the lectures list
      _fetchLecturesData();
    } catch (e) {
      // Close loading dialog if open
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
