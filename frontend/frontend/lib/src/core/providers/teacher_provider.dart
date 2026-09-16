import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

/// Teacher dashboard state
class TeacherDashboardState {
  final bool isLoading;
  final Map<String, dynamic>? dashboardData;
  final String? error;

  const TeacherDashboardState({
    this.isLoading = false,
    this.dashboardData,
    this.error,
  });

  TeacherDashboardState copyWith({
    bool? isLoading,
    Map<String, dynamic>? dashboardData,
    String? error,
  }) {
    return TeacherDashboardState(
      isLoading: isLoading ?? this.isLoading,
      dashboardData: dashboardData ?? this.dashboardData,
      error: error ?? this.error,
    );
  }
}

/// Teacher courses state
class TeacherCoursesState {
  final bool isLoading;
  final List<dynamic> courses;
  final String? error;

  const TeacherCoursesState({
    this.isLoading = false,
    this.courses = const [],
    this.error,
  });

  TeacherCoursesState copyWith({
    bool? isLoading,
    List<dynamic>? courses,
    String? error,
  }) {
    return TeacherCoursesState(
      isLoading: isLoading ?? this.isLoading,
      courses: courses ?? this.courses,
      error: error ?? this.error,
    );
  }
}

/// Teacher dashboard provider
class TeacherDashboardNotifier extends StateNotifier<TeacherDashboardState> {
  TeacherDashboardNotifier() : super(const TeacherDashboardState());

  /// Load teacher dashboard
  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final dashboardData = await apiService.getTeacherDashboard();
      state = state.copyWith(
        isLoading: false,
        dashboardData: dashboardData,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Teacher courses provider
class TeacherCoursesNotifier extends StateNotifier<TeacherCoursesState> {
  TeacherCoursesNotifier() : super(const TeacherCoursesState());

  /// Load teacher courses
  Future<void> loadCourses() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final courses = await apiService.getTeacherCourses();
      state = state.copyWith(
        isLoading: false,
        courses: courses,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Create new course
  Future<void> createCourse(Map<String, dynamic> courseData) async {
    try {
      await apiService.createTeacherCourse(courseData);
      // Reload courses after creation
      await loadCourses();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Update course
  Future<void> updateCourse(
      String courseId, Map<String, dynamic> courseData) async {
    try {
      await apiService.updateTeacherCourse(courseId, courseData);
      // Reload courses after update
      await loadCourses();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Delete course
  Future<void> deleteCourse(String courseId) async {
    try {
      await apiService.deleteTeacherCourse(courseId);
      // Reload courses after deletion
      await loadCourses();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Teacher dashboard provider
final teacherDashboardProvider =
    StateNotifierProvider<TeacherDashboardNotifier, TeacherDashboardState>(
        (ref) {
  return TeacherDashboardNotifier();
});

/// Teacher courses provider
final teacherCoursesProvider =
    StateNotifierProvider<TeacherCoursesNotifier, TeacherCoursesState>((ref) {
  return TeacherCoursesNotifier();
});
