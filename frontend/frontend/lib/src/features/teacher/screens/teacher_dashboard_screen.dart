import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/teacher_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/stats_card.dart';
import '../../../core/theme/app_colors.dart';

class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends ConsumerState<TeacherDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    // Load dashboard data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherDashboardProvider.notifier).loadDashboard();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final dashboardState = ref.watch(teacherDashboardProvider);

    // Show loading state
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

    // Show error state
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
                        color: AppColors.textMedium,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    ref.read(teacherDashboardProvider.notifier).loadDashboard();
                  },
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Welcome back, ${authState.user?['firstName'] ?? 'Teacher'}!',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.secondary,
                      AppColors.secondaryDark,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu, color: Colors.white, size: 20),
                ),
                color: Theme.of(context).colorScheme.surface,
                onSelected: (String value) {
                  switch (value) {
                    case 'notifications':
                      // TODO: Navigate to notifications
                      break;
                    case 'messages':
                      context.push('/teacher/conversations');
                      break;
                    case 'profile':
                      // TODO: Navigate to profile
                      break;
                    case 'theme':
                      ref.read(themeModeProvider.notifier).toggleTheme();
                      break;
                    case 'logout':
                      _handleLogout();
                      break;
                  }
                },
                itemBuilder: (BuildContext context) {
                  final themeMode = ref.watch(themeModeProvider);
                  final isDark = themeMode == ThemeMode.dark;
                  
                  return [
                    PopupMenuItem<String>(
                      value: 'notifications',
                      child: Row(
                        children: [
                          Icon(Icons.notifications_outlined,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text('Notifications',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface)),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'messages',
                      child: Row(
                        children: [
                          Icon(Icons.chat_outlined,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text('Messages',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface)),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text('Profile',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'theme',
                      child: Row(
                        children: [
                          Icon(
                            isDark ? Icons.light_mode : Icons.dark_mode,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isDark ? 'Light Mode' : 'Dark Mode',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface)),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout,
                              color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 12),
                          Text('Logout',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        ],
                      ),
                    ),
                  ];
                },
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Dashboard Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Stats
                  Text(
                    'Teaching Overview',
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
                          title: 'Active Courses',
                          value: dashboardState.dashboardData?['dashboard']
                                      ?['total_courses']
                                  ?.toString() ??
                              '0',
                          subtitle: 'This semester',
                          icon: Icons.book,
                          color: AppColors.secondary,
                          onTap: () {
                            // TODO: Navigate to courses
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StatsCard(
                          title: 'Total Students',
                          value: dashboardState.dashboardData?['dashboard']
                                      ?['total_students']
                                  ?.toString() ??
                              '0',
                          subtitle: 'Enrolled',
                          icon: Icons.people,
                          color: AppColors.primaryLight,
                          onTap: () {
                            // TODO: Navigate to students
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
                          title: 'Live Classes',
                          value: '3',
                          subtitle: 'This week',
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
                          title: 'Avg. Rating',
                          value: '4.8',
                          subtitle: 'Student feedback',
                          icon: Icons.star,
                          color: AppColors.warning,
                          onTap: () {
                            // TODO: Navigate to reviews
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // My Courses
                  Text(
                    'My Courses',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 16),
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
                    child: SizedBox(
                      height: 300,
                      child: _buildMyCoursesTab(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionCard(
                          icon: Icons.add_circle,
                          title: 'Create Course',
                          subtitle: 'Start a new course',
                          color: AppColors.secondary,
                          onTap: () {
                            // TODO: Navigate to create course
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildQuickActionCard(
                          icon: Icons.video_call,
                          title: 'Schedule Class',
                          subtitle: 'Plan live session',
                          color: AppColors.live,
                          onTap: () {
                            // TODO: Navigate to schedule class
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionCard(
                          icon: Icons.upload_file,
                          title: 'Upload Content',
                          subtitle: 'Add lectures & materials',
                          color: AppColors.primaryLight,
                          onTap: () {
                            // TODO: Navigate to upload content
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildQuickActionCard(
                          icon: Icons.analytics,
                          title: 'View Analytics',
                          subtitle: 'Check performance',
                          color: AppColors.info,
                          onTap: () {
                            // TODO: Navigate to analytics
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyCoursesTab() {
    final dashboardState = ref.watch(teacherDashboardProvider);
    final myCourses = dashboardState.dashboardData?['dashboard']
            ?['recent_courses'] as List<dynamic>? ??
        [];

    if (myCourses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.book,
                size: 64,
                color: AppColors.textLight,
              ),
              SizedBox(height: 16),
              Text(
                'No Courses Assigned',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMedium,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You have not been assigned any courses yet',
                style: TextStyle(
                  color: AppColors.textLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: myCourses.length,
      itemBuilder: (context, index) {
        final course = myCourses[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.book,
                  color: AppColors.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['title']?.toString() ?? 'Untitled Course',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${course['enrolled_students'] ?? 0} students • ${course['status'] ?? 'Draft'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created: ${_formatDate(course['created_at'])}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                onPressed: () {
                  final courseId = course['_id']?.toString() ?? course['id']?.toString();
                  if (courseId != null) {
                    context.push('/teacher/course/$courseId', extra: {
                      'courseData': course,
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 28,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
}
