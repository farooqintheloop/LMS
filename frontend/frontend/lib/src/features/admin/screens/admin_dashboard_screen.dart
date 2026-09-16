import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/stats_card.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final apiService = ApiService();
      final response = await apiService.getAdminDashboard();

      if (mounted) {
        setState(() {
          _dashboardData = response;
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
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.background.withOpacity(0.92)
            : Theme.of(context).colorScheme.background,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.background.withOpacity(0.92)
            : Theme.of(context).colorScheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error loading dashboard',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchDashboardData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final overview =
        Map<String, dynamic>.from(_dashboardData?['overview'] ?? {});
    final recentActivity =
        Map<String, dynamic>.from(_dashboardData?['recent_activity'] ?? {});
    final systemHealth =
        Map<String, dynamic>.from(_dashboardData?['system_health'] ?? {});
    final growthMetrics =
        Map<String, dynamic>.from(_dashboardData?['growth_metrics'] ?? {});

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.background.withOpacity(0.92)
          : Theme.of(context).colorScheme.background,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            centerTitle: false,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surface.withOpacity(0.9)
                : Theme.of(context).colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 16,
                bottom: 12,
                end:
                    88, // reserve space for ThemeToggle + menu on small screens
              ),
              title: Text(
                'Welcome back, ${authState.user?['firstName'] ?? 'Admin'}!',
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.backgroundDark,
                      AppColors.primaryDark,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              const ThemeToggleButton(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) async {
                  switch (value) {
                    case 'notifications':
                      // TODO: Navigate to notifications
                      break;
                    case 'settings':
                      // TODO: Navigate to settings
                      break;
                    case 'profile':
                      // TODO: Navigate to profile
                      break;
                    case 'help':
                      // TODO: Navigate to help
                      break;
                    case 'logout':
                      await ref.read(authProvider.notifier).logout();
                      if (mounted) {
                        context.go('/login');
                      }
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'notifications',
                    child: ListTile(
                      leading: Icon(Icons.notifications),
                      title: Text('Notifications'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings),
                      title: Text('Settings'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'profile',
                    child: ListTile(
                      leading: Icon(Icons.person),
                      title: Text('My Profile'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'help',
                    child: ListTile(
                      leading: Icon(Icons.help),
                      title: Text('Help & Support'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title:
                          Text('Logout', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
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
                  // System Overview Stats
                  Text(
                    'System Overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 600) {
                        // Stack vertically on small screens
                        return Column(
                          children: [
                            StatsCard(
                              title: 'Total Students',
                              value: '${overview['total_students'] ?? 0}',
                              subtitle:
                                  '+${growthMetrics['new_users_7d'] ?? 0} this week',
                              icon: Icons.people,
                              color: AppColors.primaryLight,
                              showTrend: true,
                              trendValue: (growthMetrics['new_users_7d'] ?? 0)
                                  .toDouble(),
                              isPositiveTrend: true,
                              onTap: () {
                                context.push('/admin/students');
                              },
                            ),
                            const SizedBox(height: 12),
                            StatsCard(
                              title: 'Total Teachers',
                              value: '${overview['total_teachers'] ?? 0}',
                              subtitle:
                                  '+${growthMetrics['new_users_7d'] ?? 0} this week',
                              icon: Icons.school,
                              color: AppColors.success,
                              showTrend: true,
                              trendValue: (growthMetrics['new_users_7d'] ?? 0)
                                  .toDouble(),
                              isPositiveTrend: true,
                              onTap: () {
                                context.push('/admin/teachers');
                              },
                            ),
                          ],
                        );
                      } else {
                        // Side by side on larger screens
                        return Row(
                          children: [
                            Expanded(
                              child: StatsCard(
                                title: 'Total Students',
                                value: '${overview['total_students'] ?? 0}',
                                subtitle:
                                    '+${growthMetrics['new_users_7d'] ?? 0} this week',
                                icon: Icons.people,
                                color: AppColors.primaryLight,
                                showTrend: true,
                                trendValue: (growthMetrics['new_users_7d'] ?? 0)
                                    .toDouble(),
                                isPositiveTrend: true,
                                onTap: () {
                                  context.push('/admin/students');
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: StatsCard(
                                title: 'Total Teachers',
                                value: '${overview['total_teachers'] ?? 0}',
                                subtitle:
                                    '+${growthMetrics['new_users_7d'] ?? 0} this week',
                                icon: Icons.school,
                                color: AppColors.success,
                                showTrend: true,
                                trendValue: (growthMetrics['new_users_7d'] ?? 0)
                                    .toDouble(),
                                isPositiveTrend: true,
                                onTap: () {
                                  context.push('/admin/teachers');
                                },
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 600) {
                        // Stack vertically on small screens
                        return Column(
                          children: [
                            StatsCard(
                              title: 'Total Courses',
                              value: '${overview['total_courses'] ?? 0}',
                              subtitle:
                                  '+${growthMetrics['new_courses_7d'] ?? 0} this week',
                              icon: Icons.book,
                              color: AppColors.warning,
                              showTrend: true,
                              trendValue: (growthMetrics['new_courses_7d'] ?? 0)
                                  .toDouble(),
                              isPositiveTrend: true,
                              onTap: () {
                                context.push('/admin/courses');
                              },
                            ),
                            const SizedBox(height: 12),
                            StatsCard(
                              title: 'Total Lectures',
                              value: '${overview['total_lectures'] ?? 0}',
                              subtitle: 'Course content',
                              icon: Icons.video_library,
                              color: AppColors.info,
                              showTrend: false,
                              onTap: () {
                                context.push('/admin/lectures');
                              },
                            ),
                          ],
                        );
                      } else {
                        // Side by side on larger screens
                        return Row(
                          children: [
                            Expanded(
                              child: StatsCard(
                                title: 'Total Courses',
                                value: '${overview['total_courses'] ?? 0}',
                                subtitle:
                                    '+${growthMetrics['new_courses_7d'] ?? 0} this week',
                                icon: Icons.book,
                                color: AppColors.warning,
                                showTrend: true,
                                trendValue:
                                    (growthMetrics['new_courses_7d'] ?? 0)
                                        .toDouble(),
                                isPositiveTrend: true,
                                onTap: () {
                                  context.push('/admin/courses');
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: StatsCard(
                                title: 'Total Lectures',
                                value: '${overview['total_lectures'] ?? 0}',
                                subtitle: 'Course content',
                                icon: Icons.video_library,
                                color: AppColors.info,
                                showTrend: false,
                                onTap: () {
                                  context.push('/admin/lectures');
                                },
                              ),
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
                        child: StatsCard(
                          title: 'Live Classes',
                          value: '${overview['total_live_classes'] ?? 0}',
                          subtitle: 'Active sessions',
                          icon: Icons.live_tv,
                          color: AppColors.error,
                          showTrend: false,
                          onTap: () {
                            // TODO: Navigate to live classes
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StatsCard(
                          title: 'Total Enrollments',
                          value: '${overview['total_enrollments'] ?? 0}',
                          subtitle:
                              '+${growthMetrics['new_enrollments_7d'] ?? 0} this week',
                          icon: Icons.trending_up,
                          color: AppColors.success,
                          showTrend: true,
                          trendValue: (growthMetrics['new_enrollments_7d'] ?? 0)
                              .toDouble(),
                          isPositiveTrend: true,
                          onTap: () {
                            // TODO: Navigate to enrollments
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // System Health Section
                  Text(
                    'System Health',
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
                          title: 'Active Users Today',
                          value: '${systemHealth['active_users_today'] ?? 0}',
                          subtitle: 'Currently online',
                          icon: Icons.online_prediction,
                          color: AppColors.success,
                          showTrend: false,
                          onTap: () {
                            // TODO: Navigate to user activity
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StatsCard(
                          title: 'Courses with Content',
                          value: '${systemHealth['courses_with_content'] ?? 0}',
                          subtitle: 'Ready for students',
                          icon: Icons.content_copy,
                          color: AppColors.info,
                          showTrend: false,
                          onTap: () {
                            context.push('/admin/courses');
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Recent Activity & Management
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context)
                              .colorScheme
                              .surface
                              .withOpacity(0.98)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withOpacity(0.4)
                              : Theme.of(context).shadowColor.withOpacity(0.1),
                          blurRadius:
                              Theme.of(context).brightness == Brightness.dark
                                  ? 25
                                  : 10,
                          offset: const Offset(0, 4),
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
                                BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            labelColor: Theme.of(context).colorScheme.primary,
                            unselectedLabelColor:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            indicatorColor:
                                Theme.of(context).colorScheme.primary,
                            tabs: const [
                              Tab(text: 'Recent Activity'),
                              Tab(text: 'Users'),
                              Tab(text: 'Courses'),
                              Tab(text: 'System Health'),
                            ],
                          ),
                        ),

                        // Tab Content
                        SizedBox(
                          height: 400,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildRecentActivityTab(recentActivity),
                              _buildUserManagementTab(),
                              _buildCourseManagementTab(),
                              _buildSystemHealthTab(systemHealth),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context)
                              .colorScheme
                              .surface
                              .withOpacity(0.98)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withOpacity(0.4)
                              : Theme.of(context).shadowColor.withOpacity(0.1),
                          blurRadius:
                              Theme.of(context).brightness == Brightness.dark
                                  ? 25
                                  : 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Actions',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickActionCard(
                                icon: Icons.person_add,
                                title: 'Add Student',
                                subtitle: 'Create new student account',
                                color: AppColors.primaryLight,
                                onTap: () => context.push('/admin/students'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildQuickActionCard(
                                icon: Icons.school,
                                title: 'Add Teacher',
                                subtitle: 'Create new teacher account',
                                color: AppColors.success,
                                onTap: () => context.push('/admin/teachers'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickActionCard(
                                icon: Icons.book,
                                title: 'Create Course',
                                subtitle: 'Add new course to platform',
                                color: AppColors.warning,
                                onTap: () => context.push('/admin/courses'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildQuickActionCard(
                                icon: Icons.video_library,
                                title: 'Upload Lecture',
                                subtitle: 'Add content to courses',
                                color: AppColors.info,
                                onTap: () => context.push('/admin/lectures'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickActionCard(
                                icon: Icons.analytics,
                                title: 'View Reports',
                                subtitle: 'Check platform analytics',
                                color: AppColors.success,
                                onTap: () => context.push('/admin/reports'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildQuickActionCard(
                                icon: Icons.settings,
                                title: 'System Settings',
                                subtitle: 'Configure platform settings',
                                color: AppColors.warning,
                                onTap: () {
                                  // TODO: Navigate to system settings
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityTab(Map<String, dynamic> recentActivity) {
    final newUsers = recentActivity['new_users'] ?? [];
    final newCourses = recentActivity['new_courses'] ?? [];
    final newEnrollments = recentActivity['new_enrollments'] ?? [];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity (Last 7 Days)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (newUsers.isNotEmpty) ...[
              Text(
                'New Users',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
              ),
              const SizedBox(height: 8),
              ...newUsers
                  .take(3)
                  .map((user) => ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(user['name'] ?? 'Unknown User'),
                        subtitle: Text('${user['role']} • ${user['email']}'),
                        dense: true,
                      ))
                  .toList(),
              const SizedBox(height: 16),
            ],
            if (newCourses.isNotEmpty) ...[
              Text(
                'New Courses',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
              ),
              const SizedBox(height: 8),
              ...newCourses
                  .take(3)
                  .map((course) => ListTile(
                        leading: const Icon(Icons.book),
                        title: Text(course['title'] ?? 'Unknown Course'),
                        subtitle: Text(
                            'Instructor: ${course['instructor_name'] ?? 'Unknown'}'),
                        dense: true,
                      ))
                  .toList(),
              const SizedBox(height: 16),
            ],
            if (newEnrollments.isNotEmpty) ...[
              Text(
                'New Enrollments',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
              ),
              const SizedBox(height: 8),
              ...newEnrollments
                  .take(3)
                  .map((enrollment) => ListTile(
                        leading: const Icon(Icons.person_add),
                        title: Text(
                            enrollment['student_name'] ?? 'Unknown Student'),
                        subtitle: Text(
                            'Enrolled in: ${enrollment['course_title'] ?? 'Unknown Course'}'),
                        dense: true,
                      ))
                  .toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserManagementTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Management',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/admin/students'),
                    icon: const Icon(Icons.people),
                    label: const Text('Manage Students'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/admin/teachers'),
                    icon: const Icon(Icons.school),
                    label: const Text('Manage Teachers'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // User Statistics
            Text(
              'User Statistics',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
            ),
            const SizedBox(height: 8),

            ListTile(
              leading: const Icon(Icons.people, color: AppColors.primaryLight),
              title: const Text('Total Students'),
              trailing: Text(
                '${_dashboardData?['overview']?['total_students'] ?? 0}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              dense: true,
            ),

            ListTile(
              leading: const Icon(Icons.school, color: AppColors.success),
              title: const Text('Total Teachers'),
              trailing: Text(
                '${_dashboardData?['overview']?['total_teachers'] ?? 0}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              dense: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseManagementTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Course Management',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/admin/courses'),
                    icon: const Icon(Icons.book),
                    label: const Text('Manage Courses'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/admin/lectures'),
                    icon: const Icon(Icons.video_library),
                    label: const Text('Manage Lectures'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Course Statistics
            Text(
              'Course Statistics',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
            ),
            const SizedBox(height: 8),

            ListTile(
              leading: const Icon(Icons.book, color: AppColors.warning),
              title: const Text('Total Courses'),
              trailing: Text(
                '${_dashboardData?['overview']?['total_courses'] ?? 0}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              dense: true,
            ),

            ListTile(
              leading: const Icon(Icons.video_library, color: AppColors.info),
              title: const Text('Total Lectures'),
              trailing: Text(
                '${_dashboardData?['overview']?['total_lectures'] ?? 0}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              dense: true,
            ),

            ListTile(
              leading: const Icon(Icons.trending_up, color: AppColors.success),
              title: const Text('Total Enrollments'),
              trailing: Text(
                '${_dashboardData?['overview']?['total_enrollments'] ?? 0}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              dense: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemHealthTab(Map<String, dynamic> systemHealth) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Health',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // System Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System Status: ${systemHealth['database_status'] ?? 'Unknown'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'All systems are operating normally',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Health Metrics
            Text(
              'Health Metrics',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
            ),
            const SizedBox(height: 8),

            ListTile(
              leading:
                  const Icon(Icons.online_prediction, color: AppColors.success),
              title: const Text('Active Users Today'),
              trailing: Text(
                '${systemHealth['active_users_today'] ?? 0}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              dense: true,
            ),

            ListTile(
              leading: const Icon(Icons.content_copy, color: AppColors.info),
              title: const Text('Courses with Content'),
              trailing: Text(
                '${systemHealth['courses_with_content'] ?? 0}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              dense: true,
            ),

            ListTile(
              leading: const Icon(Icons.star, color: AppColors.warning),
              title: const Text('Average Course Rating'),
              trailing: Text(
                '${systemHealth['average_course_rating'] ?? 0}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              dense: true,
            ),
          ],
        ),
      ),
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
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surface.withOpacity(0.98)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withOpacity(0.4)
                  : AppColors.shadowLight,
              blurRadius:
                  Theme.of(context).brightness == Brightness.dark ? 25 : 20,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.outline.withOpacity(0.15)
                  : Colors.transparent,
              blurRadius: 1,
              offset: const Offset(0, 0),
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
}
