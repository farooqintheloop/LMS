import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/stats_card.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class AdminCourseManagementScreen extends ConsumerStatefulWidget {
  const AdminCourseManagementScreen({super.key});

  @override
  ConsumerState<AdminCourseManagementScreen> createState() =>
      _AdminCourseManagementScreenState();
}

class _AdminCourseManagementScreenState
    extends ConsumerState<AdminCourseManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  // Real data from API
  List<Map<String, dynamic>> _courses = [];
  Map<String, dynamic>? _coursesData;
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  bool _loadingAnalytics = false;
  String? _error;

  // Removed status filter per requirement
  final List<String> _categoryFilters = [
    'All',
    'Mobile Development',
    'Web Development',
    'Data Science'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchCoursesData();
    _fetchAnalytics();
  }

  Future<void> _fetchCoursesData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final apiService = ApiService();
      final response = await apiService.getAdminCourses();

      if (mounted) {
        setState(() {
          _coursesData = response;
          _courses = List<Map<String, dynamic>>.from(response['courses'] ?? []);
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

  Future<void> _fetchAnalytics() async {
    setState(() => _loadingAnalytics = true);
    try {
      final api = ApiService();
      final data = await api.getAdminAnalytics();
      setState(() => _analytics = data);
    } catch (_) {
      // ignore for now, keep placeholder
    } finally {
      if (mounted) setState(() => _loadingAnalytics = false);
    }
  }

  Future<void> _openCreateCourseForm(BuildContext context) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0');
    String? selectedTeacherId;
    String selectedCategory = 'Web Development';
    String selectedLevel = 'beginner';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>>(
          future: ApiService().getAvailableTeachers(),
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            // Use new response shape: { success, instructors: [ { id, name, email, ... } ] }
            final List<dynamic> instructorsList = (snapshot.data != null
                    ? (snapshot.data!['instructors'] as List<dynamic>?)
                    : null) ??
                <dynamic>[];

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create Course',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 8),
                  loading
                      ? const LinearProgressIndicator()
                      : DropdownButtonFormField<String>(
                          value: selectedTeacherId,
                          items: instructorsList.map((t) {
                            final String id =
                                (t['id'] ?? t['_id'] ?? '').toString();
                            final String name = (t['name'] ??
                                    ((t['first_name'] ?? '') +
                                        ' ' +
                                        (t['last_name'] ?? '')) ??
                                    '')
                                .toString()
                                .trim();
                            final String email =
                                (t['email'] ?? 'Unknown').toString();
                            final String display = name.isEmpty ? email : name;
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(display),
                            );
                          }).toList(),
                          onChanged: (val) => selectedTeacherId = val,
                          decoration:
                              const InputDecoration(labelText: 'Instructor'),
                        ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: const [
                      DropdownMenuItem(
                          value: 'Web Development',
                          child: Text('Web Development')),
                      DropdownMenuItem(
                          value: 'Mobile Development',
                          child: Text('Mobile Development')),
                      DropdownMenuItem(
                          value: 'Data Science', child: Text('Data Science')),
                      DropdownMenuItem(
                          value: 'Machine Learning',
                          child: Text('Machine Learning')),
                      DropdownMenuItem(value: 'DevOps', child: Text('DevOps')),
                      DropdownMenuItem(
                          value: 'Cybersecurity', child: Text('Cybersecurity')),
                    ],
                    onChanged: (val) => selectedCategory = val!,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedLevel,
                    items: const [
                      DropdownMenuItem(
                          value: 'beginner', child: Text('Beginner')),
                      DropdownMenuItem(
                          value: 'intermediate', child: Text('Intermediate')),
                      DropdownMenuItem(
                          value: 'advanced', child: Text('Advanced')),
                    ],
                    onChanged: (val) => selectedLevel = val!,
                    decoration: const InputDecoration(labelText: 'Level'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                      controller: descCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price')),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading
                          ? null
                          : () async {
                              if (selectedTeacherId == null ||
                                  selectedTeacherId!.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Please select an instructor')),
                                );
                                return;
                              }
                              final api = ApiService();
                              try {
                                // Find selected instructor object for name
                                final selectedInstructor =
                                    instructorsList.firstWhere(
                                  (t) =>
                                      ((t['id'] ?? t['_id'] ?? '').toString() ==
                                          selectedTeacherId),
                                  orElse: () => null,
                                );
                                final String instructorName =
                                    selectedInstructor == null
                                        ? 'Assigned'
                                        : (((selectedInstructor['name'] ??
                                                    ((selectedInstructor[
                                                                'first_name'] ??
                                                            '') +
                                                        ' ' +
                                                        (selectedInstructor[
                                                                'last_name'] ??
                                                            '')))
                                                .toString())
                                            .trim());

                                final body = {
                                  'title': titleCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'category': selectedCategory,
                                  'level': selectedLevel,
                                  'price':
                                      double.tryParse(priceCtrl.text.trim()) ??
                                          0,
                                  'instructor_id': selectedTeacherId,
                                  'instructor_name': instructorName.isEmpty
                                      ? 'Assigned'
                                      : instructorName,
                                };
                                await api.createCourse(body);
                                if (mounted) Navigator.of(ctx).pop();
                                setState(() {
                                  _courses.add({
                                    'id': DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString(),
                                    'title': body['title'],
                                    'category': 'Web Development',
                                    'difficulty': 'Beginner',
                                    'status': 'Active',
                                    'teacher': body['instructor_name'],
                                    'enrolledStudents': 0,
                                    'rating': 0.0,
                                    'lecturesCount': 0,
                                    'duration': '0 hours',
                                    'price': body['price'],
                                  });
                                });
                              } catch (e) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Failed: $e')),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Create'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> get _filteredCourses {
    var filtered = _courses;

    // Removed status filter per requirement; keep category and search filters only

    if (_selectedCategory != 'All') {
      filtered = filtered
          .where((course) => course['category'] == _selectedCategory)
          .toList();
    }

    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered
          .where((course) =>
              (course['title'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(searchTerm) ||
              (course['teacher'] ?? (course['instructor_name'] ?? ''))
                  .toString()
                  .toLowerCase()
                  .contains(searchTerm))
          .toList();
    }

    return filtered;
  }

  int get _totalCoursesFromAnalyticsOrPagination {
    final analyticsTotal = _analytics?['analytics']?['total_courses'] ??
        _analytics?['overview']?['total_courses'];
    if (analyticsTotal is num) return analyticsTotal.toInt();
    final paginationTotal = _coursesData?['pagination']?['total'];
    if (paginationTotal is num) return paginationTotal.toInt();
    return _courses.length;
  }

  int get _totalStudentsFromAnalytics {
    final totalEnrollments = _analytics?['analytics']?['total_enrollments'] ??
        _analytics?['overview']?['total_enrollments'];
    if (totalEnrollments is num) return totalEnrollments.toInt();
    return 0;
  }

  int get _activeCoursesCount {
    return _courses
        .where((c) => (c['status'] ?? '').toString().toLowerCase() == 'active')
        .length;
  }

  List<Map<String, dynamic>> get _aggregatedCategoriesFromCourses {
    final Map<String, Map<String, int>> bucket = {};
    for (final course in _courses) {
      final rawCategory = course['category'];
      final String categoryName =
          (rawCategory is String && rawCategory.trim().isNotEmpty)
              ? rawCategory
              : 'Uncategorized';
      final int enrolled = (course['enrolled_students_count'] ??
              course['enrolled_students'] ??
              0) is num
          ? (course['enrolled_students_count'] ??
              course['enrolled_students'] ??
              0)
          : 0;
      bucket.putIfAbsent(
          categoryName, () => {'course_count': 0, 'student_count': 0});
      bucket[categoryName]!['course_count'] =
          (bucket[categoryName]!['course_count'] ?? 0) + 1;
      bucket[categoryName]!['student_count'] =
          (bucket[categoryName]!['student_count'] ?? 0) + enrolled;
    }
    return bucket.entries
        .map((e) => {
              'name': e.key,
              'course_count': e.value['course_count'] ?? 0,
              'student_count': e.value['student_count'] ?? 0,
            })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.background.withOpacity(0.95)
            : Theme.of(context).colorScheme.background,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.background.withOpacity(0.95)
            : Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: const Text('Course Management'),
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
              Text('Error loading courses: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchCoursesData,
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
          : Colors.white,
      appBar: AppBar(
        title: const Text('Course Management'),
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
                    title: 'Total\nCourses',
                    value: _totalCoursesFromAnalyticsOrPagination.toString(),
                    subtitle: 'All time',
                    icon: Icons.book,
                    color: AppColors.primaryLight,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatsCard(
                    title: 'Active\nCourses',
                    value: _activeCoursesCount.toString(),
                    subtitle: 'Published',
                    icon: Icons.check_circle,
                    color: AppColors.success,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatsCard(
                    title: 'Total\nStudents',
                    value: _totalStudentsFromAnalytics.toString(),
                    subtitle: 'Enrolled',
                    icon: Icons.people,
                    color: AppColors.info,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),

          // Search and Filters
          Container(
            padding: const EdgeInsets.all(16),
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
                    hintText: 'Search courses...',
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
                const SizedBox(height: 16),
                // Category Filter
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.3)),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        underline: const SizedBox(),
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        icon: Icon(Icons.arrow_drop_down,
                            color: Theme.of(context).colorScheme.onSurface),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface),
                        items: _categoryFilters.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 16),
                // Create Course button on separate line
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openCreateCourseForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Course'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
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
                Tab(text: 'All Courses'),
                Tab(text: 'Analytics'),
                Tab(text: 'Categories'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllCoursesTab(),
                _buildAnalyticsTab(),
                _buildCategoriesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllCoursesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredCourses.length,
      itemBuilder: (context, index) {
        final course = _filteredCourses[index];
        return _buildCourseCard(course);
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
                  'Course Performance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 16),
                if (_loadingAnalytics)
                  const Center(child: CircularProgressIndicator())
                else if ((_analytics != null) || (_coursesData != null))
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StatsCard(
                              title: 'Total Students',
                              value: _totalStudentsFromAnalytics.toString(),
                              subtitle: 'Platform-wide',
                              icon: Icons.people,
                              color: AppColors.primaryLight,
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: StatsCard(
                              title: 'Total Courses',
                              value: _totalCoursesFromAnalyticsOrPagination
                                  .toString(),
                              subtitle: 'Available',
                              icon: Icons.book,
                              color: AppColors.warning,
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: StatsCard(
                              title: 'Enrollments',
                              value: _totalStudentsFromAnalytics.toString(),
                              subtitle: 'Active',
                              icon: Icons.trending_up,
                              color: AppColors.success,
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: StatsCard(
                              title: 'Teachers',
                              value: ((_analytics?['analytics']
                                          ?['total_users']) ??
                                      (_analytics?['overview']
                                          ?['total_teachers']) ??
                                      0)
                                  .toString(),
                              subtitle: 'Active',
                              icon: Icons.school,
                              color: AppColors.info,
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.5)
                          : Colors.white,
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
                    child: Center(
                      child: Text(
                        'No analytics available',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    final List<dynamic> categories = _aggregatedCategoriesFromCourses;

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
                'Category Overview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 16),
              ...categories.map(
                (category) => _buildCategoryItem(
                  (category['name'] ?? '').toString(),
                  (category['course_count'] ?? 0) as int,
                  (category['student_count'] ?? 0) as int,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(
      String category, int courseCount, int studentCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.outline.withOpacity(0.2)
              : Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getCategoryColor(category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getCategoryIcon(category),
              color: _getCategoryColor(category),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$courseCount course • $studentCount students',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
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
                            color:
                                _getCategoryColor(course['category'] as String)
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getCategoryColor(
                                      course['category'] as String)
                                  .withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            _getCategoryIcon(course['category'] as String),
                            color:
                                _getCategoryColor(course['category'] as String),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course['title'] as String? ?? 'Untitled Course',
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
                              const SizedBox(height: 4),
                              Text(
                                '${course['enrolled_students'] ?? 0} students',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Removed three-dots menu per requirement
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if ((course['status'] as String?) != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getStatusColor(course['status'] as String)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              course['status'] as String? ?? 'Unknown',
                              style: TextStyle(
                                color: _getStatusColor(
                                    course['status'] as String? ?? ''),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                _getCategoryColor(course['category'] as String)
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            course['category'] as String? ?? 'General',
                            style: TextStyle(
                              color: _getCategoryColor(
                                  course['category'] as String? ?? ''),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
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
                        color: _getCategoryColor(course['category'] as String)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getCategoryColor(course['category'] as String)
                              .withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _getCategoryIcon(course['category'] as String),
                        color: _getCategoryColor(course['category'] as String),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course['title'] as String? ?? 'Untitled Course',
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
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if ((course['status'] as String?) != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                            course['status'] as String)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    course['status'] as String? ?? 'Unknown',
                                    style: TextStyle(
                                      color: _getStatusColor(
                                          course['status'] as String? ?? ''),
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
                                  color: _getCategoryColor(
                                          course['category'] as String)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  course['category'] as String? ?? 'General',
                                  style: TextStyle(
                                    color: _getCategoryColor(
                                        course['category'] as String? ?? ''),
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
                    // Removed three-dots menu per requirement
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCourseStat(
                  icon: Icons.person,
                  label: 'Teacher',
                  value: (course['instructor_name'] as String? ??
                      (course['teacher'] as String? ?? 'Unknown')),
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCourseStat(
                  icon: Icons.people,
                  label: 'Students',
                  value: (course['enrolled_students'] ?? 0).toString(),
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCourseStat(
                  icon: Icons.star,
                  label: 'Rating',
                  value: ((course['rating'] ?? 0.0) as num).toStringAsFixed(1),
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCourseStat(
                  icon: Icons.play_circle,
                  label: 'Lectures',
                  value: (course['lectures_count'] ?? 0).toString(),
                  color: AppColors.info,
                ),
              ),
            ],
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'draft':
        return AppColors.warning;
      case 'archived':
        return AppColors.textLight;
      default:
        return AppColors.textLight;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'mobile development':
        return AppColors.primaryLight;
      case 'web development':
        return AppColors.secondary;
      case 'data science':
        return AppColors.success;
      default:
        return AppColors.textLight;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'mobile development':
        return Icons.mobile_friendly;
      case 'web development':
        return Icons.web;
      case 'data science':
        return Icons.analytics;
      default:
        return Icons.school;
    }
  }
}
