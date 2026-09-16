import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

/// Student dashboard state
class StudentDashboardState {
  final bool isLoading;
  final Map<String, dynamic>? dashboardData;
  final List<dynamic> courses;
  final List<dynamic> liveClasses;
  final Map<String, dynamic>? progress;
  final String? error;

  const StudentDashboardState({
    this.isLoading = false,
    this.dashboardData,
    this.courses = const [],
    this.liveClasses = const [],
    this.progress,
    this.error,
  });

  StudentDashboardState copyWith({
    bool? isLoading,
    Map<String, dynamic>? dashboardData,
    List<dynamic>? courses,
    List<dynamic>? liveClasses,
    Map<String, dynamic>? progress,
    String? error,
  }) {
    return StudentDashboardState(
      isLoading: isLoading ?? this.isLoading,
      dashboardData: dashboardData ?? this.dashboardData,
      courses: courses ?? this.courses,
      liveClasses: liveClasses ?? this.liveClasses,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}

/// Student courses state
class StudentCoursesState {
  final bool isLoading;
  final List<dynamic> enrolledCourses;
  final List<dynamic> availableCourses;
  final List<dynamic> featuredCourses;
  final List<dynamic> popularCourses;
  final String? error;

  const StudentCoursesState({
    this.isLoading = false,
    this.enrolledCourses = const [],
    this.availableCourses = const [],
    this.featuredCourses = const [],
    this.popularCourses = const [],
    this.error,
  });

  StudentCoursesState copyWith({
    bool? isLoading,
    List<dynamic>? enrolledCourses,
    List<dynamic>? availableCourses,
    List<dynamic>? featuredCourses,
    List<dynamic>? popularCourses,
    String? error,
  }) {
    return StudentCoursesState(
      isLoading: isLoading ?? this.isLoading,
      enrolledCourses: enrolledCourses ?? this.enrolledCourses,
      availableCourses: availableCourses ?? this.availableCourses,
      featuredCourses: featuredCourses ?? this.featuredCourses,
      popularCourses: popularCourses ?? this.popularCourses,
      error: error ?? this.error,
    );
  }
}

/// Student provider
class StudentNotifier extends StateNotifier<StudentDashboardState> {
  StudentNotifier() : super(const StudentDashboardState());

  /// Load student dashboard
  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final dashboardData = await apiService.getStudentDashboard();
      final courses = await apiService.getStudentCourses();
      final liveClasses = await apiService.getStudentLiveClasses();
      final progress = await apiService.getStudentProgress();

      state = state.copyWith(
        isLoading: false,
        dashboardData: dashboardData,
        courses: courses,
        liveClasses: liveClasses,
        progress: progress,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load student courses
  Future<void> loadCourses() async {
    try {
      final courses = await apiService.getStudentCourses();
      state = state.copyWith(courses: courses);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Load live classes
  Future<void> loadLiveClasses() async {
    try {
      final liveClasses = await apiService.getStudentLiveClasses();
      state = state.copyWith(liveClasses: liveClasses);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Load progress
  Future<void> loadProgress() async {
    try {
      final progress = await apiService.getStudentProgress();
      state = state.copyWith(progress: progress);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Mark lecture as complete
  Future<void> markLectureComplete(String courseSlug, String lectureId) async {
    try {
      await apiService.markLectureComplete(courseSlug, lectureId);
      // Reload progress after marking complete
      await loadProgress();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Student courses provider
class StudentCoursesNotifier extends StateNotifier<StudentCoursesState> {
  StudentCoursesNotifier() : super(const StudentCoursesState());

  /// Load enrolled courses
  Future<void> loadEnrolledCourses() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final courses = await apiService.getStudentCourses();
      state = state.copyWith(
        isLoading: false,
        enrolledCourses: courses,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load available courses
  Future<void> loadAvailableCourses() async {
    try {
      final courses = await apiService.getAvailableCourses();
      state = state.copyWith(availableCourses: courses);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Load featured courses
  Future<void> loadFeaturedCourses() async {
    try {
      final courses = await apiService.getFeaturedCourses();
      state = state.copyWith(featuredCourses: courses);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Load popular courses
  Future<void> loadPopularCourses() async {
    try {
      final courses = await apiService.getPopularCourses();
      state = state.copyWith(popularCourses: courses);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Enroll in course
  Future<void> enrollInCourse(String courseId) async {
    try {
      await apiService.enrollInCourse(courseId);
      // Reload enrolled courses after enrollment
      await loadEnrolledCourses();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Unenroll from course
  Future<void> unenrollFromCourse(String courseId) async {
    try {
      await apiService.unenrollFromCourse(courseId);
      // Reload enrolled courses after unenrollment
      await loadEnrolledCourses();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Get course detail
  Future<Map<String, dynamic>> getCourseDetail(String courseId) async {
    try {
      // Use the course slug to get course detail from the API
      final courseDetail = await apiService.getStudentCourseDetail(courseId);
      return courseDetail;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Get course materials
  Future<Map<String, dynamic>> getCourseMaterials(String courseSlug) async {
    try {
      final apiService = ApiService();
      return await apiService.getCourseMaterials(courseSlug);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Get course lectures
  Future<Map<String, dynamic>> getCourseLectures(String courseId) async {
    try {
      final apiService = ApiService();
      return await apiService.getCourseLectures(courseId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Get lecture detail
  Future<Map<String, dynamic>> getLectureDetail(String lectureId) async {
    try {
      final apiService = ApiService();
      return await apiService.getLectureDetail(lectureId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Student dashboard provider
final studentDashboardProvider =
    StateNotifierProvider<StudentNotifier, StudentDashboardState>((ref) {
  return StudentNotifier();
});

/// Student courses provider
final studentCoursesProvider =
    StateNotifierProvider<StudentCoursesNotifier, StudentCoursesState>((ref) {
  return StudentCoursesNotifier();
});
