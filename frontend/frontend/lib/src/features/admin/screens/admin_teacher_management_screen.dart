import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/stats_card.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminTeacherManagementScreen extends ConsumerStatefulWidget {
  const AdminTeacherManagementScreen({super.key});

  @override
  ConsumerState<AdminTeacherManagementScreen> createState() =>
      _AdminTeacherManagementScreenState();
}

class _AdminTeacherManagementScreenState
    extends ConsumerState<AdminTeacherManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  // Real data from API
  List<Map<String, dynamic>> _teachers = [];
  Map<String, dynamic>? _teachersData;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _analytics = {};

  final List<String> _statusFilters = ['All', 'Active', 'Inactive'];
  // Removed unused specialization filters

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchTeachersData();
  }

  Future<void> _fetchTeachersData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final apiService = ApiService();
      // Use curated instructors endpoint for accurate teacher list
      final resp = await apiService.getAvailableTeachers();
      final List<dynamic> rawInstructors =
          resp['instructors'] as List<dynamic>? ?? [];

      // Normalize fields
      final List<Map<String, dynamic>> teachers =
          rawInstructors.map<Map<String, dynamic>>((u) {
        final String name = (u['name'] ?? '').toString();
        final parts = name.split(' ');
        final String firstName = parts.isNotEmpty ? parts.first : '';
        final String lastName =
            parts.length > 1 ? parts.sublist(1).join(' ') : '';
        return {
          '_id': u['id'] ?? u['_id'],
          'email': u['email'],
          'first_name': firstName,
          'last_name': lastName,
          'status': 'Active',
          'is_active': true,
          'date_joined': u['date_joined'],
          'last_login': u['last_login'],
          'phone': u['phone'] ?? '',
          'qualification': u['qualification'] ?? 'N/A',
          'specialization': u['specialization'] ?? 'General',
          'courses_count': u['courses_count'] ?? 0,
          'students_count': u['students_count'] ?? 0,
          'rating':
              (u['rating'] is num) ? (u['rating'] as num).toDouble() : 0.0,
        };
      }).toList();

      // Overview metrics
      final int totalTeachers = teachers.length;
      final int activeTeachers = teachers.length;
      final double avgRating = teachers.isNotEmpty
          ? (teachers
                  .map((t) => (t['rating'] as double))
                  .reduce((a, b) => a + b) /
              teachers.length)
          : 0.0;

      // Performance trends (simple last 6 months from date_joined if present)
      final DateTime now = DateTime.now();
      List<Map<String, dynamic>> performanceTrends = [];
      for (int i = 5; i >= 0; i--) {
        final DateTime start = DateTime(now.year, now.month - i, 1);
        final DateTime end = DateTime(now.year, now.month - i + 1, 1);
        final monthly = teachers.where((t) {
          final String? dj = t['date_joined'] as String?;
          if (dj == null || dj.isEmpty) return false;
          try {
            final d = DateTime.parse(dj);
            return !d.isBefore(start) && d.isBefore(end);
          } catch (_) {
            return false;
          }
        }).toList();
        final double monthAvg = monthly.isNotEmpty
            ? monthly
                    .map((t) => (t['rating'] as double))
                    .fold<double>(0.0, (a, b) => a + b) /
                monthly.length
            : 0.0;
        performanceTrends.add({'rating': monthAvg});
      }

      if (mounted) {
        setState(() {
          _teachersData = {
            'overview': {
              'total_teachers': totalTeachers,
              'active_teachers': activeTeachers,
              'average_rating': avgRating,
            }
          };
          _teachers = teachers;
          _analytics = {
            'performance_trends': performanceTrends,
          };
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

  List<Map<String, dynamic>> get _filteredTeachers {
    var filtered = _teachers;

    // Filter by status
    if (_selectedFilter != 'All') {
      filtered = filtered
          .where((teacher) => teacher['status'] == _selectedFilter)
          .toList();
    }

    // Filter by search
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered.where((teacher) {
        final name =
            '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'
                .toLowerCase();
        final email = (teacher['email'] ?? '').toLowerCase();
        final specialization = (teacher['specialization'] ?? '').toLowerCase();
        return name.contains(searchTerm) ||
            email.contains(searchTerm) ||
            specialization.contains(searchTerm);
      }).toList();
    }

    return filtered;
  }

  void _handleTeacherAction(String action, Map<String, dynamic> teacher) {
    switch (action) {
      case 'edit':
        // TODO: Show edit teacher dialog
        break;
      case 'deactivate':
        // TODO: Deactivate teacher
        break;
      case 'activate':
        // TODO: Activate teacher
        break;
      case 'delete':
        // TODO: Delete teacher
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
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
            ? Theme.of(context).colorScheme.background.withOpacity(0.95)
            : Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: const Text('Teacher Management'),
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
              Text('Error loading teachers: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchTeachersData,
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
          ? Theme.of(context).colorScheme.background.withOpacity(0.92)
          : Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Teacher Management'),
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
                  child: SizedBox(
                    height: 250,
                    child: StatsCard(
                      title: 'Total\nTeacher',
                      value:
                          (_teachersData?['overview']?['total_teachers'] ?? 0)
                              .toString(),
                      subtitle: 'All time',
                      icon: Icons.school,
                      color: AppColors.secondary,
                      onTap: () {},
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 250,
                    child: StatsCard(
                      title: 'Active\nTeacher',
                      value:
                          (_teachersData?['overview']?['active_teachers'] ?? 0)
                              .toString(),
                      subtitle: 'Currently teaching',
                      icon: Icons.check_circle,
                      color: AppColors.success,
                      onTap: () {},
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 250,
                    child: StatsCard(
                      title: 'Average\nRating',
                      value:
                          (_teachersData?['overview']?['average_rating'] ?? 0.0)
                              .toStringAsFixed(1),
                      subtitle: 'Student feedback',
                      icon: Icons.star,
                      color: AppColors.warning,
                      onTap: () {},
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search and Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText:
                        'Search teachers by name, email, or specialization...',
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

                // Status Filter
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
                        value: _selectedFilter,
                        underline: const SizedBox(),
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        icon: Icon(Icons.arrow_drop_down,
                            color: Theme.of(context).colorScheme.onSurface),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface),
                        items: _statusFilters.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFilter = value!;
                          });
                        },
                      ),
                    ),
                    const Spacer(),
                  ],
                ),

                const SizedBox(height: 16),

                // Add Teacher button on separate line
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Add teacher functionality
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Teacher'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
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
                Tab(text: 'All Teachers'),
                Tab(text: 'Performance'),
                Tab(text: 'Analytics'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllTeachersTab(),
                _buildPerformanceTab(),
                _buildAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllTeachersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredTeachers.length,
      itemBuilder: (context, index) {
        final teacher = _filteredTeachers[index];
        return _buildTeacherCard(teacher);
      },
    );
  }

  Widget _buildPerformanceTab() {
    // Sort teachers by rating
    final sortedTeachers = List<Map<String, dynamic>>.from(_teachers);
    sortedTeachers.sort((a, b) => ((b['rating'] ?? 0.0) as double)
        .compareTo((a['rating'] ?? 0.0) as double));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedTeachers.length,
      itemBuilder: (context, index) {
        final teacher = sortedTeachers[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surface.withOpacity(0.98)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.4)
                    : Theme.of(context).shadowColor.withOpacity(0.1),
                blurRadius:
                    Theme.of(context).brightness == Brightness.dark ? 25 : 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Rank
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: index < 3
                      ? AppColors.warning
                      : AppColors.backgroundMedium,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: index < 3 ? Colors.white : AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Teacher Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'
                          .trim(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      teacher['specialization'] as String? ?? 'General',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Performance Metrics
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (teacher['rating'] ?? 0.0).toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${teacher['students_count'] ?? 0} students',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Specialization Distribution
          Container(
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
                      : Theme.of(context).shadowColor.withOpacity(0.1),
                  blurRadius:
                      Theme.of(context).brightness == Brightness.dark ? 25 : 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Specialization Distribution',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 16),
                _buildSpecializationDistribution(),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Performance Trends
          Container(
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
                      : Theme.of(context).shadowColor.withOpacity(0.1),
                  blurRadius:
                      Theme.of(context).brightness == Brightness.dark ? 25 : 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Performance Trends',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildPerformanceTrendsChart(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecializationDistribution() {
    final specializationCounts = <String, int>{};
    for (final teacher in _teachers) {
      final specialization = teacher['specialization'] as String? ?? 'General';
      specializationCounts[specialization] =
          (specializationCounts[specialization] ?? 0) + 1;
    }

    return Column(
      children: specializationCounts.entries.map((entry) {
        final specialization = entry.key;
        final count = entry.value;
        final percentage =
            _teachers.isNotEmpty ? (count / _teachers.length * 100).round() : 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getSpecializationColor(specialization),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  specialization,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '$count ($percentage%)',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPerformanceTrendsChart() {
    final performanceData =
        _analytics['performance_trends'] as List<dynamic>? ?? [];

    if (performanceData.isEmpty) {
      return Center(
        child: Text(
          'No performance data available',
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
                  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                  if (value.toInt() < months.length) {
                    return Text(months[value.toInt()],
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
                  return Text(value.toStringAsFixed(1),
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
              spots: performanceData.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(),
                    (entry.value['rating'] ?? 0.0).toDouble());
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

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface.withOpacity(0.98)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.4)
                : Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius:
                Theme.of(context).brightness == Brightness.dark ? 25 : 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.secondary.withOpacity(0.1),
                child: Text(
                  (teacher['first_name'] as String? ?? 'T')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'
                          .trim(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      teacher['email'] as String? ?? '',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                                    teacher['status'] as String? ?? '')
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            teacher['status'] as String? ?? 'Unknown',
                            style: TextStyle(
                              color: _getStatusColor(
                                  teacher['status'] as String? ?? ''),
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
                            color: AppColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            teacher['specialization'] as String? ?? 'General',
                            style: const TextStyle(
                              color: AppColors.secondary,
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
                onSelected: (value) => _handleTeacherAction(value, teacher),
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
                  if (teacher['status'] == 'Active')
                    const PopupMenuItem(
                      value: 'deactivate',
                      child: Row(
                        children: [
                          Icon(Icons.block, size: 18),
                          SizedBox(width: 8),
                          Text('Deactivate'),
                        ],
                      ),
                    ),
                  if (teacher['status'] != 'Active')
                    const PopupMenuItem(
                      value: 'activate',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 18),
                          SizedBox(width: 8),
                          Text('Activate'),
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
          ),

          const SizedBox(height: 16),

          // Performance Metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  icon: Icons.book,
                  label: 'Courses',
                  value: (teacher['courses_count'] ?? 0).toString(),
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricItem(
                  icon: Icons.people,
                  label: 'Students',
                  value: (teacher['students_count'] ?? 0).toString(),
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricItem(
                  icon: Icons.star,
                  label: 'Rating',
                  value: (teacher['rating'] ?? 0.0).toStringAsFixed(1),
                  color: AppColors.warning,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Additional Info
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.phone,
                  label: 'Phone',
                  value: teacher['phone'] as String? ?? 'N/A',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.school,
                  label: 'Qualification',
                  value: teacher['qualification'] as String? ?? 'N/A',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.calendar_today,
                  label: 'Join Date',
                  value: _formatDate(teacher['date_joined']),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
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
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
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
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'inactive':
        return AppColors.textLight;
      default:
        return AppColors.textLight;
    }
  }

  Color _getSpecializationColor(String specialization) {
    switch (specialization.toLowerCase()) {
      case 'computer science':
        return AppColors.primaryLight;
      case 'web development':
        return AppColors.secondary;
      case 'data science':
        return AppColors.success;
      case 'mobile development':
        return AppColors.warning;
      case 'ai & machine learning':
        return AppColors.info;
      default:
        return AppColors.textLight;
    }
  }
}
