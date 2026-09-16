import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final String courseSlug;

  const CourseDetailScreen({
    super.key,
    required this.courseSlug,
  });

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _courseData;
  String? _courseId;
  List<Map<String, dynamic>> _resources = [];
  List<Map<String, dynamic>> _tasks = [];
  Map<String, dynamic>? _progressData;
  String? _error;
  final ApiService _apiService = ApiService();

  // Track completed items for this course (per student)
  final Set<String> _completedVideoIds = {};
  final Set<String> _completedTaskIds = {};
  final Set<String> _completedResourceIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCourseData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCourseData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load course detail data
      final courseDetail = await ref
          .read(studentCoursesProvider.notifier)
          .getCourseDetail(widget.courseSlug);
      final course = courseDetail['course'] as Map<String, dynamic>?;
      final resolvedCourseId =
          course?['_id']?.toString() ?? course?['id']?.toString() ?? widget.courseSlug;

      // Load course lectures (materials)
      Map<String, dynamic> lecturesData = {};
      try {
        lecturesData = await ref
            .read(studentCoursesProvider.notifier)
            .getCourseLectures(widget.courseSlug);
      } catch (e) {
        print('Failed to load course lectures: $e');
        // Continue without lectures if error
      }

      // Load assignments/tasks
      List<Map<String, dynamic>> tasks = [];
      try {
        final tasksResponse =
            await _apiService.getStudentAssignments(courseId: resolvedCourseId);
        tasks = List<Map<String, dynamic>>.from(tasksResponse['assignments'] ?? []);
      } catch (e) {
        print('Failed to load tasks: $e');
        // Continue without tasks if error
      }

      // Load completed items for this course
      List<Map<String, dynamic>> completedItems = [];
      try {
        final items = await _apiService.getCompletedCourseItems(
          courseId: resolvedCourseId,
        );
        completedItems = List<Map<String, dynamic>>.from(items);
      } catch (e) {
        print('Failed to load completed items: $e');
        // Continue without completed state if error
      }

      // Prepare local collections
      final resources =
          List<Map<String, dynamic>>.from(lecturesData['lectures'] ?? []);

      // Reset completion sets and populate from API
      _completedVideoIds.clear();
      _completedTaskIds.clear();
      _completedResourceIds.clear();

      for (final item in completedItems) {
        final type = item['item_type']?.toString();
        final id = item['item_id']?.toString();
        if (id == null || type == null) continue;
        if (type == 'video') {
          _completedVideoIds.add(id);
        } else if (type == 'task') {
          _completedTaskIds.add(id);
        } else if (type == 'resource') {
          _completedResourceIds.add(id);
        }
      }

      // Calculate progress summary based on items and completion
      final progressSummary = _calculateProgressSummary(
        course: course ?? {},
        resources: resources,
        tasks: tasks,
      );

      setState(() {
        _courseId = resolvedCourseId;
        _courseData = course;
        _resources = resources;
        _tasks = tasks;
        _progressData = progressSummary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Helper to extract a stable lecture/resource ID
  String _getLectureId(Map<String, dynamic> resource) {
    final lectureId = resource['lecture_id']?.toString();
    if (lectureId != null && lectureId.isNotEmpty) return lectureId;
    final id = resource['_id']?.toString() ?? resource['id']?.toString();
    return id ?? '';
  }

  /// Helper to extract a stable task/assignment ID
  String _getTaskId(Map<String, dynamic> task) {
    final id = task['_id']?.toString() ?? task['id']?.toString();
    return id ?? '';
  }

  /// Calculate progress summary based on completed items vs total items
  Map<String, dynamic> _calculateProgressSummary({
    required Map<String, dynamic> course,
    required List<Map<String, dynamic>> resources,
    required List<Map<String, dynamic>> tasks,
  }) {
    // Split lectures into videos vs non-video resources
    final videoLectures = resources.where((resource) {
      final hasVideo = resource['finalVideoUrl'] != null;
      final isVideo = hasVideo || resource['material_type'] == 'video';
      return isVideo;
    }).toList();

    final nonVideoResources = resources.where((resource) {
      final hasVideo = resource['finalVideoUrl'] != null;
      final isVideo = hasVideo || resource['material_type'] == 'video';
      return !isVideo;
    }).toList();

    final totalVideos = videoLectures.length;
    final totalResources = nonVideoResources.length;
    final totalTasks = tasks.length;

    int completedVideos = 0;
    for (final lecture in videoLectures) {
      final id = _getLectureId(lecture);
      if (id.isNotEmpty && _completedVideoIds.contains(id)) {
        completedVideos++;
      }
    }

    int completedResources = 0;
    for (final res in nonVideoResources) {
      final id = _getLectureId(res);
      if (id.isNotEmpty && _completedResourceIds.contains(id)) {
        completedResources++;
      }
    }

    int completedTasks = 0;
    for (final task in tasks) {
      final id = _getTaskId(task);
      if (id.isNotEmpty && _completedTaskIds.contains(id)) {
        completedTasks++;
      }
    }

    final totalItems = totalVideos + totalResources + totalTasks;
    final completedItems = completedVideos + completedResources + completedTasks;
    final completionPercentage =
        totalItems == 0 ? 0.0 : completedItems / totalItems;

    return {
      'completion_percentage': completionPercentage,
      'total_items': totalItems,
      'completed_items': completedItems,
      // Keep lecture-style fields for backwards compatibility
      'total_lectures': totalItems,
      'completed_lectures': completedItems,
      'total_videos': totalVideos,
      'completed_videos': completedVideos,
      'total_resources': totalResources,
      'completed_resources': completedResources,
      'total_tasks': totalTasks,
      'completed_tasks': completedTasks,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: const Text('Course Details'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: const Text('Course Details'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading course',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadCourseData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_courseData == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: const Text('Course Details'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Text('Course not found'),
        ),
      );
    }

    return GradientScaffold(
      appBar: GradientAppBar(
        title: Text(_courseData!['title'] ?? 'Course Details'),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              final courseId = _courseData!['_id'] ??
                  _courseData!['id'] ??
                  widget.courseSlug;
              final instructorName =
                  _courseData!['instructor_name'] ?? 'Instructor';
              context.push('/student/chat/$courseId', extra: {
                'courseTitle': _courseData!['title'] ?? 'Course',
                'instructorName': instructorName,
              });
            },
            tooltip: 'Chat with Instructor',
          ),
          IconButton(
            icon: const Icon(Icons.download_for_offline),
            onPressed: () {
              context.push('/student/downloaded-videos');
            },
            tooltip: 'Downloaded Videos',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCourseData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCourseData,
        child: CustomScrollView(
          slivers: [
            // Course Header
            SliverToBoxAdapter(
              child: _buildCourseHeader(),
            ),

            // Progress Section
            SliverToBoxAdapter(
              child: _buildProgressSection(),
            ),

            // Tabbed Content
            SliverToBoxAdapter(
              child: _buildTabbedContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseHeader() {
    final course = _courseData!;
    final thumbnail = course['thumbnail'];
    final instructor = course['instructor_name'] ?? 'Unknown Instructor';
    final difficulty = course['difficulty'] ?? 'Beginner';
    final estimatedHours = course['estimated_hours'] ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course Image and Basic Info
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 400) {
                // Stack vertically on small screens
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course Thumbnail
                    Center(
                      child: Container(
                        width: 100,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).colorScheme.surfaceVariant,
                        ),
                        child: thumbnail != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  thumbnail,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceVariant,
                                      ),
                                      child: const Icon(
                                        Icons.book,
                                        size: 32,
                                        color: AppColors.textLight,
                                      ),
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.book,
                                size: 32,
                                color: AppColors.textLight,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Course Info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course['title'] ?? 'Course Title',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'by $instructor',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Chip(
                              label: Text(difficulty),
                              backgroundColor:
                                  Theme.of(context).colorScheme.surfaceVariant,
                              labelStyle: const TextStyle(fontSize: 11),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            Chip(
                              label: Text('${estimatedHours}h'),
                              backgroundColor:
                                  Theme.of(context).colorScheme.surfaceVariant,
                              labelStyle: const TextStyle(fontSize: 11),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                // Original row layout for larger screens
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course Thumbnail
                    Container(
                      width: 120,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(context).colorScheme.surfaceVariant,
                      ),
                      child: thumbnail != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                thumbnail,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceVariant,
                                    ),
                                    child: const Icon(
                                      Icons.book,
                                      size: 40,
                                      color: AppColors.textLight,
                                    ),
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons.book,
                              size: 40,
                              color: AppColors.textLight,
                            ),
                    ),
                    const SizedBox(width: 16),
                    // Course Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course['title'] ?? 'Course Title',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'by $instructor',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Chip(
                                label: Text(difficulty),
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant,
                                labelStyle: const TextStyle(fontSize: 12),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text('${estimatedHours}h'),
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant,
                                labelStyle: const TextStyle(fontSize: 12),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),
          // Course Description
          if (course['description'] != null) ...[
            Text(
              'About this course',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              course['description'],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    if (_progressData == null) return const SizedBox.shrink();

    final progress = _progressData!;
    final completionPercentage =
        (progress['completion_percentage'] ?? 0.0).toDouble();
    final totalItems =
        progress['total_items'] ?? progress['total_lectures'] ?? 0;
    final completedItems =
        progress['completed_items'] ?? progress['completed_lectures'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Progress',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(completionPercentage * 100).toInt()}% Complete',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completedItems of $totalItems items completed',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              CircularProgressIndicator(
                value: completionPercentage,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary),
                strokeWidth: 8,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: completionPercentage,
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildTabbedContent() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Content'),
                Tab(text: 'Tasks'),
                Tab(text: 'Resources'),
              ],
            ),
          ),

          // Tab Content
          SizedBox(
            height: 500,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildContentTab(),
                _buildTasksTab(),
                _buildResourcesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTab() {
    // Filter resources to only include videos
    List<Map<String, dynamic>> videoResources = _resources.where((resource) {
      // Check for uploaded materials (new structure)
      final hasVideo = resource['finalVideoUrl'] != null;
      // Fallback to old structure
      final isVideo = hasVideo || resource['material_type'] == 'video';
      return isVideo;
    }).toList();

    if (videoResources.isEmpty) {
      return _buildEmptyState(
        icon: Icons.video_library,
        title: 'No Videos Available',
        subtitle: 'Video content will be available soon',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: videoResources.length,
      itemBuilder: (context, index) {
        final resource = videoResources[index];
        final title = resource['title'] ??
            resource['video_metadata']?['originalName'] ??
            'Video Lecture';
        final size = resource['video_metadata']?['size'] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(resource['description'] as String? ?? 'Video lecture'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'VIDEO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatFileSize(size),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () {
              _openResource(resource);
            },
            onLongPress: () async {
              if (_courseId == null) return;
              final lectureId = _getLectureId(resource);
              if (lectureId.isEmpty) return;
              final alreadyCompleted = _completedVideoIds.contains(lectureId);
              await _handleMarkItemComplete(
                itemType: 'video',
                itemId: lectureId,
                itemTitle: title,
                alreadyCompleted: alreadyCompleted,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTasksTab() {
    if (_tasks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_outlined,
        title: 'No Tasks Available',
        subtitle: 'Tasks will appear here when assigned by your teacher',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        final dueDate = task['due_date'];
        final isOverdue = dueDate != null && 
            DateTime.parse(dueDate).isBefore(DateTime.now());

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isOverdue ? AppColors.error : AppColors.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.assignment,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              task['title'] ?? 'Untitled Task',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task['description'] != null && task['description'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(task['description']),
                  ),
                Row(
                  children: [
                    if (dueDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOverdue 
                              ? AppColors.error.withOpacity(0.1)
                              : AppColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Due: ${_formatDate(dueDate)}',
                          style: TextStyle(
                            color: isOverdue ? AppColors.error : AppColors.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (task['points'] != null && task['points'] > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${task['points']} points',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                if (task['file_url'] != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _downloadFile(task['file_url'], task['file_name'] ?? 'task_file.pdf'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primaryLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.download,
                            size: 16,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'File attached',
                            style: TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onLongPress: () async {
              if (_courseId == null) return;
              final taskId = _getTaskId(task);
              if (taskId.isEmpty) return;
              final alreadyCompleted = _completedTaskIds.contains(taskId);
              await _handleMarkItemComplete(
                itemType: 'task',
                itemId: taskId,
                itemTitle: task['title'] ?? 'Task',
                alreadyCompleted: alreadyCompleted,
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Unknown';
    try {
      if (dateValue is String) {
        final date = DateTime.parse(dateValue);
        return '${date.day}/${date.month}/${date.year}';
      }
      return dateValue.toString();
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: $e'),
        ),
      );
    }
  }

  /// Handle "mark as complete" for any course item (video, task, resource)
  Future<void> _handleMarkItemComplete({
    required String itemType,
    required String itemId,
    required String itemTitle,
    required bool alreadyCompleted,
  }) async {
    if (_courseId == null) return;

    if (alreadyCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This $itemType is already marked as complete.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Mark as complete?'),
            content: Text(
              'Do you want to mark "$itemTitle" as complete?\n\n'
              'This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Mark Complete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await _apiService.completeCourseItem(
        courseId: _courseId!,
        itemType: itemType,
        itemId: itemId,
      );

      setState(() {
        if (itemType == 'video') {
          _completedVideoIds.add(itemId);
        } else if (itemType == 'task') {
          _completedTaskIds.add(itemId);
        } else if (itemType == 'resource') {
          _completedResourceIds.add(itemId);
        }
        _progressData = _calculateProgressSummary(
          course: _courseData ?? {},
          resources: _resources,
          tasks: _tasks,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$itemTitle" marked as complete.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark as complete: $e'),
        ),
      );
    }
  }

  Widget _buildResourcesTab() {
    // Filter resources to exclude videos
    List<Map<String, dynamic>> nonVideoResources = _resources.where((resource) {
      // Check for uploaded materials (new structure)
      final hasVideo = resource['finalVideoUrl'] != null;
      // Fallback to old structure
      final isVideo = hasVideo || resource['material_type'] == 'video';
      return !isVideo; // Keep only non-video resources
    }).toList();

    if (nonVideoResources.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_outlined,
        title: 'No Resources Available',
        subtitle: 'Course resources will be available soon',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: nonVideoResources.length,
      itemBuilder: (context, index) {
        final resource = nonVideoResources[index];

        // Check for uploaded materials (new structure)
        final hasFile = resource['finalFileUrl'] != null;
        final fileMetadata = resource['file_metadata'];

        // Fallback to old structure
        final isPdf = hasFile || resource['material_type'] == 'pdf';
        final isDoc = resource['material_type'] == 'doc';

        // Get display info
        final title = resource['title'] ??
            fileMetadata?['originalName'] ??
            'Resource Material';
        final size = fileMetadata?['size'] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPdf
                    ? AppColors.warning
                    : isDoc
                        ? AppColors.info
                        : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPdf
                        ? Icons.picture_as_pdf
                        : isDoc
                            ? Icons.description
                            : Icons.attachment,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(resource['description'] as String? ?? 'Course material'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPdf
                                ? AppColors.warning
                                : isDoc
                                    ? AppColors.info
                                : Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (isPdf
                                    ? 'PDF'
                                    : isDoc
                                        ? 'DOC'
                                        : 'FILE')
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatFileSize(size),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () {
              _openResource(resource);
            },
            onLongPress: () async {
              if (_courseId == null) return;
              final lectureId = _getLectureId(resource);
              if (lectureId.isEmpty) return;
              final alreadyCompleted = _completedResourceIds.contains(lectureId);
              await _handleMarkItemComplete(
                itemType: 'resource',
                itemId: lectureId,
                itemTitle: title,
                alreadyCompleted: alreadyCompleted,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  void _openResource(Map<String, dynamic> resource) {
    // Check for uploaded materials first (new structure)
    final videoUrl = resource['finalVideoUrl'];
    final fileUrl = resource['finalFileUrl'];
    final videoMetadata = resource['video_metadata'];
    final fileMetadata = resource['file_metadata'];

    // Fallback to old structure
    final materialType = resource['material_type'] ??
        (videoUrl != null
            ? 'video'
            : fileUrl != null
                ? 'pdf'
                : 'unknown');
    final url = videoUrl ?? fileUrl ?? resource['file_url'] ?? resource['url'];
    final resourceId = resource['_id'] ?? resource['id'];
    final resourceTitle = resource['title'] ??
        videoMetadata?['originalName'] ??
        fileMetadata?['originalName'] ??
        'Resource';

    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resource not available'),
        ),
      );
      return;
    }

    if (videoUrl != null || materialType == 'video') {
      // Open video in video player
      context.push('/student/video-player', extra: {
        'lectureId': resourceId,
        'lectureTitle': resourceTitle,
        'courseTitle': _courseData!['title'],
        'videoUrl': url,
        'needsStreamingUrl':
            true, // Flag to indicate we need to fetch signed URL
      });
    } else if (fileUrl != null && fileUrl.toLowerCase().contains('.pdf')) {
      // Open PDF viewer for PDF files
      context.push('/student/pdf-viewer', extra: {
        'lectureId': resourceId,
        'lectureTitle': resourceTitle,
        'courseTitle': _courseData!['title'],
        'pdfUrl': fileUrl,
      });
    } else {
      // Try to open other file types in external app
      try {
        final uri = Uri.parse(url);
        launchUrl(uri, mode: LaunchMode.externalApplication).then((success) {
          if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
                content: Text(
                    'Cannot open $resourceTitle. Please download manually.'),
          action: SnackBarAction(
                  label: 'Copy Link',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
          ),
        ),
      );
          }
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
          ),
        );
      }
    }
  }
}
