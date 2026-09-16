import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../core/providers/teacher_provider.dart';

class TeacherCoursesScreen extends ConsumerStatefulWidget {
  const TeacherCoursesScreen({super.key});

  @override
  ConsumerState<TeacherCoursesScreen> createState() =>
      _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends ConsumerState<TeacherCoursesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'All';

  final List<String> _statuses = [
    'All',
    'Active',
    'Draft',
    'Completed',
    'Archived',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load teacher courses
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherCoursesProvider.notifier).loadCourses();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch state to trigger rebuilds when data changes
    ref.watch(teacherCoursesProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('My Courses'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: Icon(Icons.search,
                color: Theme.of(context).colorScheme.onSurface),
            onPressed: () {
              _showSearchDialog();
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list,
                color: Theme.of(context).colorScheme.onSurface),
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
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
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search your courses...',
                prefixIcon: Icon(Icons.search,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Active Filters
          if (_selectedStatus != 'All')
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  _buildFilterChip(
                    label: _selectedStatus,
                    onRemove: () => setState(() => _selectedStatus = 'All'),
                  ),
                ],
              ),
            ),

          // Tab Bar
          Container(
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
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.secondary,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.secondary,
              tabs: const [
                Tab(text: 'All Courses'),
                Tab(text: 'Active'),
                Tab(text: 'Drafts'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllCoursesTab(),
                _buildActiveCoursesTab(),
                _buildDraftCoursesTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to create course
        },
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Course'),
      ),
    );
  }

  Widget _buildAllCoursesTab() {
    final coursesState = ref.watch(teacherCoursesProvider);

    if (coursesState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (coursesState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${coursesState.error}'),
            ElevatedButton(
              onPressed: () {
                ref.read(teacherCoursesProvider.notifier).loadCourses();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filteredCourses =
        _filterCourses(coursesState.courses.cast<Map<String, dynamic>>());

    if (filteredCourses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.book,
        title: 'No Courses Found',
        subtitle: 'Try adjusting your search or filters',
        actionText: 'Create Course',
        onAction: () {
          // TODO: Navigate to create course
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredCourses.length,
      itemBuilder: (context, index) {
        final course = filteredCourses[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: _buildTeacherCourseCard(course),
        );
      },
    );
  }

  Widget _buildActiveCoursesTab() {
    final coursesState = ref.watch(teacherCoursesProvider);
    final activeCourses = coursesState.courses
        .cast<Map<String, dynamic>>()
        .where((course) => course['status'] == 'Active')
        .toList();

    if (activeCourses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.play_circle,
        title: 'No Active Courses',
        subtitle: 'Start teaching to see active courses here',
        actionText: 'Create Course',
        onAction: () {
          // TODO: Navigate to create course
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeCourses.length,
      itemBuilder: (context, index) {
        final course = activeCourses[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: _buildTeacherCourseCard(course),
        );
      },
    );
  }

  Widget _buildDraftCoursesTab() {
    final coursesState = ref.watch(teacherCoursesProvider);
    final draftCourses = coursesState.courses
        .cast<Map<String, dynamic>>()
        .where((course) => course['status'] == 'Draft')
        .toList();

    if (draftCourses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.edit,
        title: 'No Draft Courses',
        subtitle: 'Start creating a course to see drafts here',
        actionText: 'Create Course',
        onAction: () {
          // TODO: Navigate to create course
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: draftCourses.length,
      itemBuilder: (context, index) {
        final course = draftCourses[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: _buildTeacherCourseCard(course),
        );
      },
    );
  }

  Widget _buildTeacherCourseCard(Map<String, dynamic> course) {
    final title = course['title'] as String;
    final description = course['description'] as String;
    final status = course['status'] as String;
    final students = course['students'] as int;
    final progress = course['progress'] as double;
    final lastUpdated = course['lastUpdated'] as String;
    // final thumbnail = course['thumbnail'];

    return Container(
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
          // Course Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status,
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Last updated: $lastUpdated',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textLight),
                  onSelected: (value) {
                    _handleCourseAction(value, course);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Course'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility, size: 18),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'analytics',
                      child: Row(
                        children: [
                          Icon(Icons.analytics, size: 18),
                          SizedBox(width: 8),
                          Text('Analytics'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(Icons.archive, size: 18),
                          SizedBox(width: 8),
                          Text('Archive'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Course Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course Title and Description
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                // Course Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildCourseStat(
                        icon: Icons.people,
                        label: 'Students',
                        value: students.toString(),
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildCourseStat(
                        icon: Icons.trending_up,
                        label: 'Progress',
                        value: '${(progress * 100).toInt()}%',
                        color: AppColors.getProgressColor(progress),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Navigate to course detail
                        },
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('View'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.secondary,
                          side: BorderSide(
                              color: Theme.of(context).colorScheme.secondary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Navigate to edit course
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: onRemove,
      backgroundColor: AppColors.secondary.withOpacity(0.1),
      labelStyle: const TextStyle(
        color: AppColors.secondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Courses'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Enter search terms...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _searchQuery = _searchController.text;
              });
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Filter Courses'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Status',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _statuses.map((status) {
                  return ChoiceChip(
                    label: Text(status),
                    selected: _selectedStatus == status,
                    onSelected: (selected) {
                      setState(() {
                        _selectedStatus = selected ? status : 'All';
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedStatus = 'All';
                });
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                this.setState(() {});
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCourseAction(String action, Map<String, dynamic> course) {
    switch (action) {
      case 'edit':
        // TODO: Navigate to edit course
        break;
      case 'view':
        // TODO: Navigate to course detail
        break;
      case 'analytics':
        // TODO: Navigate to analytics
        break;
      case 'archive':
        // TODO: Archive course
        break;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'draft':
        return AppColors.warning;
      case 'completed':
        return AppColors.info;
      case 'archived':
        return AppColors.textLight;
      default:
        return AppColors.textLight;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.play_circle;
      case 'draft':
        return Icons.edit;
      case 'completed':
        return Icons.check_circle;
      case 'archived':
        return Icons.archive;
      default:
        return Icons.circle;
    }
  }

  List<Map<String, dynamic>> _filterCourses(
      List<Map<String, dynamic>> courses) {
    return courses.where((course) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final title = course['title']?.toString().toLowerCase() ?? '';
        final description =
            course['description']?.toString().toLowerCase() ?? '';

        if (!title.contains(_searchQuery.toLowerCase()) &&
            !description.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      // Status filter
      if (_selectedStatus != 'All') {
        if (course['status'] != _selectedStatus) {
          return false;
        }
      }

      return true;
    }).toList();
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
                color: Theme.of(context).colorScheme.surfaceVariant,
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
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
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
