import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/course_card.dart';
import '../../../core/widgets/live_class_card.dart';
import '../../../core/widgets/progress_card.dart';
import '../../../core/widgets/stats_card.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../dashboard/presentation/pages/student_dashboard_page.dart'
    show StudentProfilePage;

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() =>
      _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends ConsumerState<StudentDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Use addPostFrameCallback to avoid modifying providers during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      await ref.read(studentDashboardProvider.notifier).loadDashboard();
      // Also load available courses for the dashboard
      await ref.read(studentCoursesProvider.notifier).loadAvailableCourses();
    } catch (e) {
      // If there's an error, show a more helpful message
      print('Dashboard loading error: $e');
    }
  }

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      context.go('/login');
    }
  }

  void _showDetailedProgress(Map<String, dynamic> progress) {
    final recentSessions =
        List<Map<String, dynamic>>.from(progress['recent_sessions'] ?? []);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detailed Progress',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Last 5 sessions',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (recentSessions.isEmpty)
                const Text('No recent sessions yet.')
              else
                ...recentSessions.map((session) {
                  final loginAt = session['login_at'] as String?;
                  final logoutAt = session['logout_at'] as String?;
                  final durationMin = session['duration_minutes'] ?? 0;

                  DateTime? loginTime;
                  DateTime? logoutTime;
                  try {
                    if (loginAt != null) {
                      loginTime = DateTime.parse(loginAt);
                    }
                    if (logoutAt != null) {
                      logoutTime = DateTime.parse(logoutAt);
                    }
                  } catch (_) {}

                  final loginStr = loginTime != null
                      ? '${loginTime.toLocal()}'
                      : 'Unknown';
                  final logoutStr = logoutTime != null
                      ? '${logoutTime.toLocal()}'
                      : 'Active / Unknown';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: Text('Login: $loginStr'),
                    subtitle: Text('Logout: $logoutStr'),
                    trailing: Text('${durationMin} min'),
                  );
                }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showHoursGoalDialog(Map<String, dynamic> progress) async {
    final currentGoal = progress['total_hours'] ?? 0;
    final controller = TextEditingController(
      text: currentGoal != null && currentGoal != 0 ? '$currentGoal' : '',
    );

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Set Study Hours Goal'),
            content: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Hours to spend',
                hintText: 'e.g. 2',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final input = controller.text.trim();
    if (input.isEmpty) return;

    final hours = double.tryParse(input);
    if (hours == null || hours < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid non-negative number of hours.'),
        ),
      );
      return;
    }

    try {
      await apiService.updateHoursGoal(hours);
      // Reload progress only
      await ref.read(studentDashboardProvider.notifier).loadProgress();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Study hours goal updated.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update goal: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final dashboardState = ref.watch(studentDashboardProvider);
    final coursesState = ref.watch(studentCoursesProvider);

    // Show loading indicator while data is being fetched
    if (dashboardState.isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading dashboard...'),
            ],
          ),
        ),
      );
    }

    // Show error state if there's an error
    if (dashboardState.error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                  'Error loading dashboard',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.error,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  dashboardState.error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _loadDashboardData(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GradientScaffold(
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: CustomScrollView(
          slivers: [
            // Custom App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: Theme.of(context).colorScheme.primary,
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final isCollapsed = constraints.biggest.height <=
                      kToolbarHeight + MediaQuery.of(context).padding.top;

                  return FlexibleSpaceBar(
                    titlePadding: EdgeInsets.only(
                      left: isCollapsed ? 16 : 0,
                      bottom: isCollapsed ? 16 : 0,
                    ),
                    title: Text(
                      'Welcome back, ${authState.user?['firstName'] ?? 'Student'}!',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: isCollapsed ? 16 : 18,
                      ),
                    ),
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryLight,
                            AppColors.primaryDark,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              actions: [
                const ThemeToggleButton(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onSelected: (String value) {
                    switch (value) {
                      case 'downloaded':
                        context.push('/student/downloaded-videos');
                        break;
                      case 'notifications':
                        // TODO: Navigate to notifications
                        break;
                      case 'profile':
                        // Navigate to student profile page showing full details
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StudentProfilePage(),
                          ),
                        );
                        break;
                      case 'logout':
                        _handleLogout();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'downloaded',
                      child: Row(
                        children: [
                          Icon(Icons.download_for_offline,
                              color: AppColors.primaryLight),
                          SizedBox(width: 12),
                          Text('Downloaded Videos'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'notifications',
                      child: Row(
                        children: [
                          Icon(Icons.notifications,
                              color: AppColors.primaryLight),
                          SizedBox(width: 12),
                          Text('Notifications'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person, color: AppColors.primaryLight),
                          SizedBox(width: 12),
                          Text('Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: AppColors.error),
                          SizedBox(width: 12),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Dashboard Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress Overview
                    if (dashboardState.progress != null)
                      ProgressCard(
                        progress: dashboardState.progress!,
                        onTap: () {
                          _showDetailedProgress(dashboardState.progress!);
                        },
                        onHoursTap: () {
                          _showHoursGoalDialog(dashboardState.progress!);
                        },
                      ),

                    const SizedBox(height: 24),

                    // Quick Stats
                    Text(
                      'Quick Overview',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: StatsCard(
                            title: 'Enrolled\nCourses',
                            value: '${dashboardState.courses.length}',
                            icon: Icons.book,
                            color: AppColors.primaryLight,
                            onTap: () {
                              // TODO: Navigate to courses
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StatsCard(
                            title: 'Available\nCourses',
                            value: '${coursesState.availableCourses.length}',
                            icon: Icons.explore,
                            color: AppColors.secondary,
                            onTap: () {
                              context.push('/student/courses');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: StatsCard(
                            title: 'Live\nClasses',
                            value: '${dashboardState.liveClasses.length}',
                            icon: Icons.video_call,
                            color: AppColors.live,
                            onTap: () {
                              // TODO: Navigate to live classes
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StatsCard(
                            title: 'Total\nProgress',
                        value: dashboardState.progress != null
                            ? '${(((dashboardState.progress?['overall_progress'] ?? 0.0) as num) * 100).toInt()}%'
                            : '0%',
                            icon: Icons.trending_up,
                            color: AppColors.success,
                            onTap: () {
                              // TODO: Navigate to progress
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Available Courses Section
                    if (coursesState.availableCourses.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Available Courses',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          TextButton(
                            onPressed: () {
                              context.push('/student/courses');
                            },
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height:
                            420, // Reduced from 460 to 420 to match our optimized card height
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              coursesState.availableCourses.take(3).length,
                          itemBuilder: (context, index) {
                            final course = coursesState.availableCourses[index];
                            return Container(
                              width: 240,
                              margin: EdgeInsets.only(
                                right: index <
                                        coursesState.availableCourses
                                                .take(3)
                                                .length -
                                            1
                                    ? 16
                                    : 0,
                              ),
                              child: CourseCard(
                                course: course,
                                onTap: () {
                                  _showCourseDetailAndEnroll(course);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Tabbed Content
                    Container(
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
                              color:
                                  Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16)),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              labelColor: Theme.of(context).colorScheme.primary,
                              unselectedLabelColor: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              indicatorColor:
                                  Theme.of(context).colorScheme.primary,
                              indicatorWeight: 3,
                              tabs: const [
                                Tab(text: 'My Courses'),
                                Tab(text: 'Live Classes'),
                              ],
                            ),
                          ),

                          // Tab Content
                          SizedBox(
                            height: 400,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildMyCoursesTab(dashboardState),
                                _buildLiveClassesTab(dashboardState),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // View All Courses Button
                    if (coursesState.availableCourses.isNotEmpty ||
                        dashboardState.courses.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: ElevatedButton(
                            onPressed: () => context.push('/student/courses'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryLight,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'View All Courses',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // View All Live Classes Button
                    if (dashboardState.liveClasses.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: Navigate to live classes screen
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'View All Live Classes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyCoursesTab(StudentDashboardState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.courses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.book,
        title: 'No Courses Yet',
        subtitle: 'Enroll in your first course to get started',
        actionText: 'Browse Courses',
        onAction: () {
          context.push('/student/courses');
        },
      );
    }

    // Filter courses that are enrolled (have any progress or are marked as enrolled)
    final enrolledCourses = state.courses.where((course) {
      final isEnrolled =
          course['is_enrolled'] ?? true; // Default to true if not specified
      final hasProgress = (course['progress'] ?? 0.0) > 0.0;
      return isEnrolled || hasProgress;
    }).toList();

    if (enrolledCourses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.play_circle,
        title: 'No Courses in Progress',
        subtitle: 'Start learning to see your progress here',
        actionText: 'Start Learning',
        onAction: () {
          context.push('/student/courses');
        },
      );
    }

    // Sort by progress (highest first), then by title
    enrolledCourses.sort((a, b) {
      final progressA = a['progress'] ?? 0.0;
      final progressB = b['progress'] ?? 0.0;
      if (progressA != progressB) {
        return progressB.compareTo(progressA);
      }
      final titleA = a['title'] ?? '';
      final titleB = b['title'] ?? '';
      return titleA.compareTo(titleB);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: enrolledCourses.length,
      itemBuilder: (context, index) {
        final course = enrolledCourses[index];
        return CourseCard(
          course: course,
          showProgress: true,
          isEnrolled: true,
          onTap: () {
            // Debug: Print course data to see what fields are available
            print('Course data: $course');
            print('Course keys: ${course.keys.toList()}');

            // Try to get the course identifier, prioritizing slug, then id, then _id
            final courseId = course['slug'] ?? course['id'] ?? course['_id'];
            print('Selected course ID: $courseId');

            if (courseId != null) {
              context.push('/student/course/$courseId');
            } else {
              // Show error if no valid course identifier found
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Course identifier not found'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildLiveClassesTab(StudentDashboardState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.liveClasses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.video_call,
        title: 'No Live Classes',
        subtitle: 'Check back later for upcoming live sessions',
        actionText: 'View Schedule',
        onAction: () {
          context.push('/student/courses');
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.liveClasses.length,
      itemBuilder: (context, index) {
        final liveClass = state.liveClasses[index];
        return LiveClassCard(
          liveClass: liveClass,
          onTap: () {
            // TODO: Navigate to live class detail
            context.push('/student/live-class/${liveClass['id']}');
          },
          onJoin: () {
            // TODO: Join live class
          },
        );
      },
    );
  }

  void _showCourseDetailAndEnroll(Map<String, dynamic> course) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final price = course['price'] ?? 0;
        final double usd = (price is num)
            ? price.toDouble()
            : double.tryParse(price.toString()) ?? 0.0;
        // Approximate USD -> PKR conversion; adjust as needed or fetch from API
        final double pkr = usd * 280.0;
        final description = course['description'] ?? 'No description';
        final slug = course['slug'] ?? course['id'] ?? course['_id'];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.book, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      course['title'] ?? 'Course',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description.toString(),
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    label: Text(
                      'Price: PKR ${pkr.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: Theme.of(ctx).brightness == Brightness.dark
                        ? Theme.of(ctx)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.4)
                        : Theme.of(ctx)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.3),
                    side: BorderSide(
                      color: Theme.of(ctx).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (course['difficulty'] != null)
                    Chip(
                      label: Text(
                        course['difficulty'].toString(),
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor:
                          Theme.of(ctx).brightness == Brightness.dark
                              ? Theme.of(ctx)
                                  .colorScheme
                                  .surfaceVariant
                                  .withOpacity(0.4)
                              : Theme.of(ctx)
                                  .colorScheme
                                  .surfaceVariant
                                  .withOpacity(0.3),
                      side: BorderSide(
                        color:
                            Theme.of(ctx).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.how_to_reg),
                  label: const Text('Enroll'),
                  onPressed: () async {
                    try {
                      await ref
                          .read(studentCoursesProvider.notifier)
                          .enrollInCourse(slug.toString());
                      if (mounted) {
                        Navigator.of(ctx).pop();
                        // Refresh dashboard data
                        await _loadDashboardData();
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Successfully enrolled!')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Failed to enroll: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.backgroundMedium,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                icon,
                size: 40,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(actionText),
            ),
          ],
        ),
      ),
    );
  }
}
