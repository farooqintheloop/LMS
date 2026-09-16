import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class AdminStudentManagementScreen extends ConsumerStatefulWidget {
  const AdminStudentManagementScreen({super.key});

  @override
  ConsumerState<AdminStudentManagementScreen> createState() =>
      _AdminStudentManagementScreenState();
}

class _AdminStudentManagementScreenState
    extends ConsumerState<AdminStudentManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  // Real data from API
  List<Map<String, dynamic>> _students = [];
  Map<String, dynamic>? _studentsData;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _recentActivity = [];
  Map<String, dynamic> _analytics = {};

  final List<String> _statusFilters = [
    'All',
    'Active',
    'Inactive',
    'Suspended'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchStudentsData();
  }

  Future<void> _fetchStudentsData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final apiService = ApiService();
      // Fetch all pages (users) and filter role=student
      int page = 1;
      const int limit = 1000;
      final List<dynamic> allUsers = [];
      while (true) {
        final resp = await apiService.getAdminUsers(page: page, limit: limit);
        final List<dynamic> usersPage = (resp['users'] as List<dynamic>? ?? []);
        allUsers.addAll(usersPage);
        final pagination = resp['pagination'] as Map<String, dynamic>?;
        if (pagination == null) break;
        final int total = (pagination['total'] ?? usersPage.length) as int;
        final int fetched = page * limit;
        if (fetched >= total || usersPage.isEmpty) break;
        page += 1;
      }

      // Normalize only students
      final List<Map<String, dynamic>> students = allUsers
          .where((u) => (u['role']?.toString().toLowerCase() == 'student'))
          .map<Map<String, dynamic>>((u) {
        final bool isActive = (u['is_active'] == true);
        final String status = isActive ? 'Active' : 'Inactive';
        final String? dateJoinedStr =
            (u['date_joined'] ?? u['created_at'])?.toString();
        return {
          '_id': u['_id'],
          'email': u['email'],
          'first_name': u['first_name'] ?? '',
          'last_name': u['last_name'] ?? '',
          'status': status,
          'is_active': isActive,
          'date_joined': dateJoinedStr,
          'last_login': u['last_login'],
          'enrolled_courses': u['enrolled_courses'] ?? 0,
          'phone': u['phone'] ?? '',
        };
      }).toList();

      // Compute overview and analytics as before
      final int totalStudents = students.length;
      final int activeStudents =
          students.where((s) => s['is_active'] == true).length;
      final DateTime now = DateTime.now();
      final DateTime monthStart = DateTime(now.year, now.month, 1);
      final DateTime nextMonthStart = DateTime(now.year, now.month + 1, 1);
      bool isInCurrentMonth(String? iso) {
        if (iso == null || iso.isEmpty) return false;
        try {
          final dt = DateTime.parse(iso);
          return !dt.isBefore(monthStart) && dt.isBefore(nextMonthStart);
        } catch (_) {
          return false;
        }
      }

      final int newStudentsThisMonth = students
          .where((s) => isInCurrentMonth(s['date_joined'] as String?))
          .length;

      final List<Map<String, dynamic>> recentActivity = students
          .where((s) => isInCurrentMonth(s['date_joined'] as String?))
          .map((s) => {
                'type': 'student_registered',
                'message':
                    "${(s['first_name'] as String? ?? '')} ${(s['last_name'] as String? ?? '')}"
                            .trim()
                            .isEmpty
                        ? (s['email'] ?? 'New student')
                        : "${s['first_name']} ${s['last_name']}",
                'timestamp': s['date_joined'] ?? '',
              })
          .toList();

      List<Map<String, dynamic>> growthData = [];
      for (int i = 5; i >= 0; i--) {
        final DateTime start = DateTime(now.year, now.month - i, 1);
        final DateTime end = DateTime(now.year, now.month - i + 1, 1);
        int count = students.where((s) {
          final String? dj = s['date_joined'] as String?;
          if (dj == null) return false;
          try {
            final d = DateTime.parse(dj);
            return !d.isBefore(start) && d.isBefore(end);
          } catch (_) {
            return false;
          }
        }).length;
        growthData.add({'count': count});
      }

      if (mounted) {
        setState(() {
          _studentsData = {
            'overview': {
              'total_students': totalStudents,
              'active_students': activeStudents,
              'new_students_this_month': newStudentsThisMonth,
            }
          };
          _students = students;
          _recentActivity = recentActivity;
          _analytics = {
            'growth_data': growthData,
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

  List<Map<String, dynamic>> get _filteredStudents {
    var filtered = _students;

    // Filter by status
    if (_selectedFilter != 'All') {
      filtered = filtered
          .where((student) => student['status'] == _selectedFilter)
          .toList();
    }

    // Filter by search
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered.where((student) {
        final name =
            '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
                .toLowerCase();
        final email = (student['email'] ?? '').toLowerCase();
        return name.contains(searchTerm) || email.contains(searchTerm);
      }).toList();
    }

    return filtered;
  }

  // Removed student action handler per requirement (menus removed)

  String _stringifyObjectId(dynamic id) {
    if (id == null) return '';
    if (id is String) return id;
    if (id is Map && id[r'$oid'] != null) return id[r'$oid'].toString();
    return id.toString();
  }

  Future<void> _confirmAndDeleteStudent(Map<String, dynamic> student) async {
    final studentId = _stringifyObjectId(student['_id']);
    if (studentId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete: missing student id')),
      );
      return;
    }

    final name = ('${student['first_name'] ?? ''} ${student['last_name'] ?? ''}')
        .trim();
    final email = (student['email'] ?? '').toString();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete student?'),
        content: Text(
          'Are you sure you want to delete this student?\n\n'
          '${name.isNotEmpty ? name : email}\n\n'
          'This student will not be able to login again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final apiService = ApiService();
      await apiService.deleteAdminStudent(studentId);

      // Refresh list
      await _fetchStudentsData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete student: $e')),
      );
    }
  }

  Future<void> _showAddStudentDialog() async {
    final fullNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final fatherCtrl = TextEditingController();
    final emergencyCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final cnicCtrl = TextEditingController();

    String? extractReadableError(Object e) {
      final raw = e.toString();
      // Common case: Exception: <message>
      if (raw.startsWith('Exception:')) {
        return raw.replaceFirst('Exception:', '').trim();
      }
      // Fallback
      return raw;
    }

    bool isSubmitting = false;
    String? inlineError;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          Future<void> submit() async {
            final fullName = fullNameCtrl.text.trim();
            final email = emailCtrl.text.trim();
            final password = passwordCtrl.text;
            final confirm = confirmCtrl.text;
            final phone = phoneCtrl.text.trim();
            final father = fatherCtrl.text.trim();
            final emergency = emergencyCtrl.text.trim();
            final address = addressCtrl.text.trim();
            final cnic = cnicCtrl.text.trim();

            setLocalState(() => inlineError = null);

            if (fullName.isEmpty ||
                email.isEmpty ||
                password.isEmpty ||
                confirm.isEmpty ||
                phone.isEmpty ||
                father.isEmpty ||
                emergency.isEmpty ||
                address.isEmpty ||
                cnic.isEmpty) {
              setLocalState(() => inlineError = 'Please fill all fields.');
              return;
            }

            if (password != confirm) {
              setLocalState(() =>
                  inlineError = 'Password and confirm password do not match.');
              return;
            }

            try {
              setLocalState(() => isSubmitting = true);

              final apiService = ApiService();
              await apiService.createStudentProfile(
                fullName: fullName,
                email: email,
                password: password,
                confirmPassword: confirm,
                phoneNumber: phone,
                fatherName: father,
                emergencyPhoneNumber: emergency,
                fullAddress: address,
                cnicNumber: cnic,
              );

              if (!mounted) return;
              Navigator.of(context).pop(); // close only on success
              // Refresh after dialog is closed to avoid framework assertion issues
              Future.microtask(() async {
                if (!mounted) return;
                await _fetchStudentsData();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Student added successfully')),
                );
              });
            } catch (e) {
              final msg = extractReadableError(e) ?? 'Failed to add student.';
              setLocalState(() {
                inlineError = msg;
                isSubmitting = false;
              });
            }
          }

          return AlertDialog(
            title: const Text('Add new student'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (inlineError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.error, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              inlineError!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: fullNameCtrl,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    enabled: !isSubmitting,
                  ),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isSubmitting,
                  ),
                  TextField(
                    controller: passwordCtrl,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    enabled: !isSubmitting,
                  ),
                  TextField(
                    controller: confirmCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Confirm password'),
                    obscureText: true,
                    enabled: !isSubmitting,
                  ),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone number'),
                    keyboardType: TextInputType.phone,
                    enabled: !isSubmitting,
                  ),
                  TextField(
                    controller: fatherCtrl,
                    decoration: const InputDecoration(labelText: "Father's name"),
                    enabled: !isSubmitting,
                  ),
                  TextField(
                    controller: emergencyCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Emergency phone number'),
                    keyboardType: TextInputType.phone,
                    enabled: !isSubmitting,
                  ),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'Full address'),
                    minLines: 1,
                    maxLines: 2,
                    enabled: !isSubmitting,
                  ),
                  TextField(
                    controller: cnicCtrl,
                    decoration: const InputDecoration(labelText: 'CNIC number'),
                    enabled: !isSubmitting,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : submit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    fullNameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmCtrl.dispose();
    phoneCtrl.dispose();
    fatherCtrl.dispose();
    emergencyCtrl.dispose();
    addressCtrl.dispose();
    cnicCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.background.withOpacity(0.92)
            : Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: const Text('Student Management'),
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
              Text('Error loading students: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchStudentsData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.background.withOpacity(0.92)
          : Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Student Management'),
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
            padding:
                const EdgeInsets.all(8), // Reduced padding to prevent overflow
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surface.withOpacity(0.9)
                : AppColors.backgroundDark,
            height: 240,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight,
                        ),
                        child: _buildSimpleStatsCard(
                          title: 'Total Students',
                          value: (_studentsData?['overview']
                                      ?['total_students'] ??
                                  0)
                              .toString(),
                          subtitle: 'All time',
                          icon: Icons.people,
                          color: AppColors.primaryLight,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8), // Reduced spacing to prevent overflow
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight,
                        ),
                        child: _buildSimpleStatsCard(
                          title: 'Active Students',
                          value: (_studentsData?['overview']
                                      ?['active_students'] ??
                                  0)
                              .toString(),
                          subtitle: 'Currently enrolled',
                          icon: Icons.check_circle,
                          color: AppColors.success,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8), // Reduced spacing to prevent overflow
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight,
                        ),
                        child: _buildSimpleStatsCard(
                          title: 'New This Month',
                          value: (_studentsData?['overview']
                                      ?['new_students_this_month'] ??
                                  0)
                              .toString(),
                          subtitle: 'This month',
                          icon: Icons.trending_up,
                          color: AppColors.info,
                        ),
                      );
                    },
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
                    hintText: 'Search students by name or email...',
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

                // Filters and Actions
                Row(
                  children: [
                    // Status Filter
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
                    ElevatedButton.icon(
                      onPressed: _showAddStudentDialog,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Student'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
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
                Tab(text: 'All Students'),
                Tab(text: 'Recent Activity'),
                Tab(text: 'Analytics'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllStudentsTab(),
                _buildRecentActivityTab(),
                _buildAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
        ),
        if (_isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black.withOpacity(0.25),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAllStudentsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) {
        final student = _filteredStudents[index];
        return _buildStudentCard(student);
      },
    );
  }

  Widget _buildRecentActivityTab() {
    final activities = _recentActivity;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getActivityColor(activity['type'] as String? ?? ''),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getActivityIcon(activity['type'] as String? ?? ''),
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity['message'] as String? ?? '',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activity['timestamp'] as String? ?? 'Unknown time',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
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
          // Student Growth Chart
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
                  'Student Growth',
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
                  child: _buildStudentGrowthChart(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Status Distribution
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
                  'Status Distribution',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 16),
                _buildStatusDistribution(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDistribution() {
    final statusCounts = <String, int>{};
    for (final student in _students) {
      final status = student['status'] as String? ?? 'Unknown';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    return Column(
      children: statusCounts.entries.map((entry) {
        final status = entry.key;
        final count = entry.value;
        final percentage =
            _students.isNotEmpty ? (count / _students.length * 100).round() : 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status,
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

  Widget _buildStudentCard(Map<String, dynamic> student) {
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
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 400) {
                // Stack layout for small screens
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              AppColors.primaryLight.withOpacity(0.1),
                          child: Text(
                            (student['first_name'] as String? ?? 'U')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
                                    .trim(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                student['email'] as String? ?? '',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete student',
                          onPressed: () => _confirmAndDeleteStudent(student),
                          icon: const Icon(Icons.delete_outline),
                          color: AppColors.error,
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
                                    student['status'] as String? ?? '')
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            student['status'] as String? ?? 'Unknown',
                            style: TextStyle(
                              color: _getStatusColor(
                                  student['status'] as String? ?? ''),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${student['enrolled_courses'] ?? 0} courses',
                          style: const TextStyle(
                            color: AppColors.textLight,
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
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryLight.withOpacity(0.1),
                      child: Text(
                        (student['first_name'] as String? ?? 'U')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primaryLight,
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
                            '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
                                .trim(),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            student['email'] as String? ?? '',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                          student['status'] as String? ?? '')
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  student['status'] as String? ?? 'Unknown',
                                  style: TextStyle(
                                    color: _getStatusColor(
                                        student['status'] as String? ?? ''),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${student['enrolled_courses'] ?? 0} courses',
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete student',
                      onPressed: () => _confirmAndDeleteStudent(student),
                      icon: const Icon(Icons.delete_outline),
                      color: AppColors.error,
                    ),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 16),

          // Additional Info
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.phone,
                  label: 'Phone',
                  value: student['phone'] as String? ?? 'N/A',
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.calendar_today,
                  label: 'Join Date',
                  value: _formatDate(student['date_joined']),
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.access_time,
                  label: 'Last Seen',
                  value: _formatLastSeen(student['last_login']),
                ),
              ),
            ],
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
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentGrowthChart() {
    final growthData = _analytics['growth_data'] as List<dynamic>? ?? [];

    if (growthData.isEmpty) {
      return Center(
        child: Text(
          'No growth data available',
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
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
              spots: growthData.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(),
                    (entry.value['count'] ?? 0).toDouble());
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

  Color _getActivityColor(String type) {
    switch (type.toLowerCase()) {
      case 'student_registered':
        return AppColors.primaryLight;
      case 'course_enrolled':
        return AppColors.secondary;
      case 'status_changed':
        return AppColors.warning;
      case 'payment_received':
        return AppColors.success;
      default:
        return AppColors.info;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'student_registered':
        return Icons.person_add;
      case 'course_enrolled':
        return Icons.school;
      case 'status_changed':
        return Icons.info;
      case 'payment_received':
        return Icons.payment;
      default:
        return Icons.notifications;
    }
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

  String _formatLastSeen(dynamic lastLogin) {
    if (lastLogin == null) return 'Never';
    try {
      DateTime lastLoginDate;
      if (lastLogin is String) {
        lastLoginDate = DateTime.parse(lastLogin);
      } else {
        lastLoginDate = lastLogin;
      }
      final now = DateTime.now();
      final difference = now.difference(lastLoginDate);

      if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else {
        return '${difference.inMinutes} minutes ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'inactive':
        return AppColors.textLight;
      case 'suspended':
        return AppColors.error;
      default:
        return AppColors.textLight;
    }
  }

  // Simple stats card that won't overflow
  Widget _buildSimpleStatsCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(
          14), // Slightly reduced padding to prevent overflow
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
        crossAxisAlignment: CrossAxisAlignment.center, // Center all content
        mainAxisAlignment: MainAxisAlignment.center, // Center vertically
        mainAxisSize: MainAxisSize.min, // Prevent overflow
        children: [
          // Icon
          Container(
            width: 44, // Slightly smaller to fit better
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22, // Slightly smaller icon
              color: color,
            ),
          ),

          const SizedBox(height: 12), // Reduced spacing

          // Title
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13, // Slightly smaller font to prevent overflow
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center, // Center text
            maxLines: 2, // Allow 2 lines for longer titles
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 10), // Reduced spacing

          // Value
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center, // Center the value
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 28, // Slightly smaller font to prevent overflow
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center, // Center text
              maxLines: 1,
            ),
          ),

          const SizedBox(height: 6), // Reduced spacing

          // Subtitle
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11, // Slightly smaller font to prevent overflow
            ),
            textAlign: TextAlign.center, // Center text
            maxLines: 2, // Allow 2 lines for longer subtitles
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
