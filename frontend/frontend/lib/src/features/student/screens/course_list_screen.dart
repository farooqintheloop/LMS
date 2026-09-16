import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/widgets/course_card.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class CourseListScreen extends ConsumerStatefulWidget {
  const CourseListScreen({super.key});

  @override
  ConsumerState<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends ConsumerState<CourseListScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedDifficulty = 'All';
  String _selectedSortBy = 'Popularity';

  final List<String> _categories = [
    'All',
    'Programming',
    'Design',
    'Business',
    'Marketing',
    'Language',
    'Music',
    'Photography',
  ];

  final List<String> _difficulties = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  final List<String> _sortOptions = [
    'Popularity',
    'Newest',
    'Rating',
    'Price',
    'Duration',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCourses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    await ref.read(studentCoursesProvider.notifier).loadAvailableCourses();
    await ref.read(studentCoursesProvider.notifier).loadFeaturedCourses();
    await ref.read(studentCoursesProvider.notifier).loadPopularCourses();
    // Ensure enrolled courses are loaded for "My Courses" tab
    await ref.read(studentCoursesProvider.notifier).loadEnrolledCourses();
  }

  @override
  Widget build(BuildContext context) {
    final coursesState = ref.watch(studentCoursesProvider);

    return GradientScaffold(
      resizeToAvoidBottomInset: false,
      appBar: GradientAppBar(
        title: const Text('Discover Courses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.download_for_offline),
            onPressed: () {
              context.push('/student/downloaded-videos');
            },
            tooltip: 'Downloaded Videos',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
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
                hintText: 'Search for courses...',
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
          if (_selectedCategory != 'All' || _selectedDifficulty != 'All')
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_selectedCategory != 'All')
                    _buildFilterChip(
                      label: _selectedCategory,
                      onRemove: () => setState(() => _selectedCategory = 'All'),
                    ),
                  if (_selectedDifficulty != 'All')
                    _buildFilterChip(
                      label: _selectedDifficulty,
                      onRemove: () =>
                          setState(() => _selectedDifficulty = 'All'),
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
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Featured'),
                Tab(text: 'Popular'),
                Tab(text: 'My'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllCoursesTab(coursesState),
                _buildFeaturedCoursesTab(coursesState),
                _buildPopularCoursesTab(coursesState),
                _buildMyCoursesTab(coursesState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllCoursesTab(StudentCoursesState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredCourses = _filterCourses(state.availableCourses);

    if (filteredCourses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search,
        title: 'No Courses Found',
        subtitle: 'Try adjusting your search or filters',
        actionText: 'Clear Filters',
        onAction: () {
          setState(() {
            _searchQuery = '';
            _selectedCategory = 'All';
            _selectedDifficulty = 'All';
          });
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredCourses.length,
      itemBuilder: (context, index) {
        final course = filteredCourses[index];
        return CourseCard(
          course: course,
          onTap: () {
            _showCourseDetailAndEnroll(course);
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
                    backgroundColor: Theme.of(ctx).colorScheme.surfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  if (course['level'] != null)
                    Chip(
                      label: Text(course['level'].toString()),
                      backgroundColor: Theme.of(ctx).colorScheme.surfaceVariant,
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
                        // Switch to My Courses tab
                        _tabController.animateTo(3);
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

  Widget _buildFeaturedCoursesTab(StudentCoursesState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredCourses = _filterCourses(state.featuredCourses);

    if (filteredCourses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.star,
        title: 'No Featured Courses',
        subtitle: 'Check back later for featured content',
        actionText: 'Browse All Courses',
        onAction: () {
          _tabController.animateTo(0);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredCourses.length,
      itemBuilder: (context, index) {
        final course = filteredCourses[index];
        return CourseCard(
          course: course,
          onTap: () {
            // TODO: Navigate to course detail
          },
        );
      },
    );
  }

  Widget _buildPopularCoursesTab(StudentCoursesState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredCourses = _filterCourses(state.popularCourses);

    if (filteredCourses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.trending_up,
        title: 'No Popular Courses',
        subtitle: 'Check back later for popular content',
        actionText: 'Browse All Courses',
        onAction: () {
          _tabController.animateTo(0);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredCourses.length,
      itemBuilder: (context, index) {
        final course = filteredCourses[index];
        return CourseCard(
          course: course,
          onTap: () {
            // TODO: Navigate to course detail
          },
        );
      },
    );
  }

  Widget _buildMyCoursesTab(StudentCoursesState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.enrolledCourses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.book,
        title: 'No Enrolled Courses',
        subtitle: 'Enroll in courses to see them here',
        actionText: 'Discover Courses',
        onAction: () {
          _tabController.animateTo(0);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.enrolledCourses.length,
      itemBuilder: (context, index) {
        final course = state.enrolledCourses[index];
        return CourseCard(
          course: course,
          showProgress: true,
          isEnrolled: true,
          onTap: () {
            final courseId = course['slug'] ?? course['id'] ?? course['_id'];
            context.push('/student/course/$courseId');
          },
        );
      },
    );
  }

  List<dynamic> _filterCourses(List<dynamic> courses) {
    return courses.where((course) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final title = course['title']?.toString().toLowerCase() ?? '';
        final description =
            course['description']?.toString().toLowerCase() ?? '';
        final instructor =
            course['instructor']?['name']?.toString().toLowerCase() ?? '';

        if (!title.contains(_searchQuery.toLowerCase()) &&
            !description.contains(_searchQuery.toLowerCase()) &&
            !instructor.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategory != 'All') {
        final category = course['category']?.toString() ?? '';
        if (category != _selectedCategory) {
          return false;
        }
      }

      // Difficulty filter
      if (_selectedDifficulty != 'All') {
        final difficulty = course['difficulty']?.toString().toLowerCase() ?? '';
        if (difficulty != _selectedDifficulty.toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: onRemove,
      backgroundColor: AppColors.primaryLight.withOpacity(0.1),
      labelStyle: const TextStyle(
        color: AppColors.primaryLight,
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
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category Filter
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Category',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _categories.map((category) {
                    return ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = selected ? category : 'All';
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Difficulty Filter
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Difficulty',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _difficulties.map((difficulty) {
                    return ChoiceChip(
                      label: Text(difficulty),
                      selected: _selectedDifficulty == difficulty,
                      onSelected: (selected) {
                        setState(() {
                          _selectedDifficulty = selected ? difficulty : 'All';
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Sort By
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Sort By',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedSortBy,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _sortOptions.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(option),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSortBy = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedCategory = 'All';
                  _selectedDifficulty = 'All';
                  _selectedSortBy = 'Popularity';
                });
              },
              child: const Text('Clear All'),
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
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
