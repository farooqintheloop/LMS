import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/student_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/api_service.dart';

class StudentDashboardPage extends ConsumerStatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  ConsumerState<StudentDashboardPage> createState() =>
      _StudentDashboardPageState();
}

class _StudentDashboardPageState extends ConsumerState<StudentDashboardPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const StudentHomePage(),
    const StudentCoursesPage(),
    const StudentLiveClassesPage(),
    const StudentProgressPage(),
    const StudentProfilePage(),
  ];

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userName = authState.user?['firstName'] ?? 'Student';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Hi, $userName!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.backgroundMedium,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu, size: 20),
            ),
            onSelected: (String value) {
              switch (value) {
                case 'notifications':
                  // TODO: Navigate to notifications
                  break;
                case 'profile':
                  setState(() {
                    _selectedIndex = 4; // Profile tab
                  });
                  break;
                case 'logout':
                  _handleLogout();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'notifications',
                child: Row(
                  children: [
                    Icon(Icons.notifications_outlined,
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
                    Icon(Icons.person_outline, color: AppColors.primaryLight),
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
          const SizedBox(width: 16),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                _buildNavItem(1, Icons.book_outlined, Icons.book, 'Courses'),
                _buildNavItem(
                    2, Icons.video_call_outlined, Icons.video_call, 'Live'),
                _buildNavItem(
                    3, Icons.analytics_outlined, Icons.analytics, 'Progress'),
                _buildNavItem(
                    4, Icons.person_outlined, Icons.person, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? Colors.white : AppColors.textLight,
              size: 20,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color:
                    isSelected ? AppColors.primaryLight : AppColors.textLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class StudentHomePage extends StatelessWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _StudentHomePageContent();
  }
}

class _StudentHomePageContent extends ConsumerStatefulWidget {
  const _StudentHomePageContent();

  @override
  ConsumerState<_StudentHomePageContent> createState() =>
      _StudentHomePageContentState();
}

class _StudentHomePageContentState
    extends ConsumerState<_StudentHomePageContent> {
  @override
  void initState() {
    super.initState();
    // Load available and enrolled courses for the dashboard
    Future.microtask(() async {
      await ref.read(studentCoursesProvider.notifier).loadAvailableCourses();
      await ref.read(studentCoursesProvider.notifier).loadEnrolledCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final coursesState = ref.watch(studentCoursesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryLight.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.school,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back!',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            'Ready to continue learning?',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickStat(
                        context,
                        (coursesState.enrolledCourses.length).toString(),
                        'Enrolled Courses',
                        Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildQuickStat(
                        context,
                        '${coursesState.enrolledCourses.where((c) => (c['progress'] ?? 0) >= 100).length}',
                        'Completed',
                        Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildQuickStat(
                        context,
                        '60%',
                        'Progress',
                        Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Continue Watching Section
          Text(
            'Continue Watching',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (context, index) {
                return _buildContinueWatchingCard(context, index);
              },
            ),
          ),

          const SizedBox(height: 24),

          // My Courses Section (from provider)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Courses',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: coursesState.enrolledCourses.isEmpty
                ? Center(
                    child: Text(
                      'No enrolled courses yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textLight,
                          ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: coursesState.enrolledCourses.length,
                    itemBuilder: (context, index) {
                      final course = coursesState.enrolledCourses[index];
                      return _buildCourseCard(context, course);
                    },
                  ),
          ),

          const SizedBox(height: 24),

          // Available Courses (from provider)
          Text(
            'Available Courses',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: coursesState.availableCourses.isEmpty
                ? Center(
                    child: Text(
                      'No courses available right now',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textLight),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: coursesState.availableCourses.length,
                    itemBuilder: (context, index) {
                      final c = coursesState.availableCourses[index];
                      return GestureDetector(
                        onTap: () => _showCourseDetailAndEnroll(c),
                        child: _buildCourseCard(context, c),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 24),

          // Upcoming Live Classes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upcoming Live Classes',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to live classes
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 2,
            itemBuilder: (context, index) {
              return _buildLiveClassCard(context, index);
            },
          ),

          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  'Browse Courses',
                  Icons.explore,
                  AppColors.primaryLight,
                  () {
                    // TODO: Navigate to course catalog
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  'Join Live Class',
                  Icons.video_call,
                  AppColors.live,
                  () {
                    // TODO: Navigate to live classes
                  },
                ),
              ),
            ],
          ),
        ],
      ),
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
                    label: Text('Price: \$${price.toString()}'),
                    backgroundColor: AppColors.backgroundLight,
                  ),
                  const SizedBox(width: 8),
                  if (course['level'] != null)
                    Chip(
                      label: Text(course['level'].toString()),
                      backgroundColor: AppColors.backgroundLight,
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
                      if (mounted) Navigator.of(ctx).pop();
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

  Widget _buildQuickStat(
      BuildContext context, String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildContinueWatchingCard(BuildContext context, int index) {
    return Container(
      width: 240,
      height: 160, // Reduced height to prevent overflow
      margin: EdgeInsets.only(right: index == 2 ? 0 : 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 70, // Much smaller header
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.getCategoryColor(index),
                    AppColors.getCategoryColor(index).withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Stack(
                children: [
                  const Center(
                    child:
                        Icon(Icons.play_circle, size: 32, color: Colors.white),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${(index + 1) * 15}:${(index + 1) * 30}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8), // Reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'JavaScript Fundamentals - Part ${index + 1}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Column(
                      children: [
                        LinearProgressIndicator(
                          value: (index + 1) * 0.3,
                          backgroundColor: AppColors.backgroundMedium,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.getCategoryColor(index),
                          ),
                          minHeight: 4, // Thinner progress bar
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${((index + 1) * 30).round()}% complete',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textLight,
                                      fontSize: 10,
                                    ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                // TODO: Resume lecture
                              },
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                minimumSize: const Size(0, 24),
                              ),
                              child: const Text(
                                'Resume',
                                style: TextStyle(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildCourseCard(BuildContext context, Map<String, dynamic> course) {
    return Container(
      width: 180,
      height: 160, // Reduced height to prevent overflow
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 60, // Much smaller header
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Center(
                child: Icon(Icons.book, size: 24, color: Colors.white),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8), // Reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      course['title'] ?? 'Course Title',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Column(
                      children: [
                        LinearProgressIndicator(
                          value: (course['progress'] ?? 0.0).toDouble() / 100,
                          backgroundColor: AppColors.backgroundMedium,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryLight,
                          ),
                          minHeight: 4, // Thinner progress bar
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(course['progress'] ?? 0).round()}% complete',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textLight,
                                    fontSize: 10,
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
      ),
    );
  }

  Widget _buildLiveClassCard(BuildContext context, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.video_call, color: Colors.white, size: 28),
        ),
        title: Text(
          'Advanced JavaScript Concepts',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Today at ${10 + index}:00 AM',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Instructor: John Doe',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textLight,
                  ),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () {
            // TODO: Join live class
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.live,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Join'),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudentCoursesPage extends StatelessWidget {
  const StudentCoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Courses Page - Coming Soon',
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }
}

class StudentLiveClassesPage extends StatelessWidget {
  const StudentLiveClassesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Live Classes Page - Coming Soon',
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }
}

class StudentProgressPage extends StatelessWidget {
  const StudentProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Progress Page - Coming Soon',
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }
}

class StudentProfilePage extends ConsumerStatefulWidget {
  const StudentProfilePage({super.key});

  @override
  ConsumerState<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends ConsumerState<StudentProfilePage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _student;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final authState = ref.read(authProvider);
      final email = authState.user?['email'] as String?;

      if (email == null || email.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'No email found for current user';
        });
        return;
      }

      final result = await apiService.getStudentProfile(email: email);
      setState(() {
        _isLoading = false;
        _student = result['student'] as Map<String, dynamic>?;
        _error = _student == null ? 'Student profile not found' : null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 40),
              const SizedBox(height: 12),
              Text(
                'Failed to load profile',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textLight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final student = _student ?? {};
    final fullName = student['full_name'] as String? ?? '';
    final email = student['email'] as String? ?? '';
    final phone = student['phone_number'] as String? ?? '';
    final fatherName = student['father_name'] as String? ?? '';
    final emergencyPhone = student['emergency_phone_number'] as String? ?? '';
    final address = student['full_address'] as String? ?? '';
    final cnic = student['cnic_number'] as String? ?? '';
    final photoUrl = student['photo_url'] as String?;

    return Container(
      color: colorScheme.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            // Avatar
            CircleAvatar(
              radius: 48,
              backgroundColor: colorScheme.surfaceVariant,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Icon(
                      Icons.person,
                      size: 40,
                      color: colorScheme.onSurfaceVariant,
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              fullName.isNotEmpty ? fullName : 'Student',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onBackground.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),

            // Info cards
            _buildInfoCard(
              context,
              title: 'Phone Number',
              value: phone,
              icon: Icons.phone_outlined,
            ),
            _buildInfoCard(
              context,
              title: 'Father Name',
              value: fatherName,
              icon: Icons.family_restroom_outlined,
            ),
            _buildInfoCard(
              context,
              title: 'Emergency Phone',
              value: emergencyPhone,
              icon: Icons.emergency_outlined,
            ),
            _buildInfoCard(
              context,
              title: 'Address',
              value: address,
              icon: Icons.location_on_outlined,
            ),
            _buildInfoCard(
              context,
              title: 'CNIC Number',
              value: cnic,
              icon: Icons.badge_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : 'Not provided',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
