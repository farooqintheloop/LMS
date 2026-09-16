import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String _baseUrl =
      'https://lms-api-production.muheet228.workers.dev/api';
  static const _storage = FlutterSecureStorage();

  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptors for authentication
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Do not attach token for auth endpoints or public student profile endpoints
        final isAuthEndpoint = options.path.startsWith('/auth/');
        final isPublicStudentEndpoint =
            options.path.contains('/admin/create-student-profile') ||
                options.path.contains('/admin/get-student-profile');

        // Debug logging
        print('[API Interceptor] Path: ${options.path}');
        print('[API Interceptor] Is Auth Endpoint: $isAuthEndpoint');
        print(
            '[API Interceptor] Is Public Student Endpoint: $isPublicStudentEndpoint');

        // Explicitly remove Authorization header for public endpoints
        if (isAuthEndpoint || isPublicStudentEndpoint) {
          options.headers.remove('Authorization');
          print(
              '[API Interceptor] Removed Authorization header for public endpoint');
        } else {
          final token = await _storage.read(key: 'access_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final reqPath = error.requestOptions.path;
        final isAuthEndpoint = reqPath.startsWith('/auth/');
        final isPublicStudentEndpoint =
            reqPath.contains('/admin/create-student-profile') ||
                reqPath.contains('/admin/get-student-profile');

        // Never try to refresh for auth endpoints or public student endpoints to avoid loops
        if (!isAuthEndpoint &&
            !isPublicStudentEndpoint &&
            error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _storage.read(key: 'access_token');
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(error.requestOptions);
            handler.resolve(response);
            return;
          } else {
            // If refresh failed, clear tokens
            await logout();
          }
        }
        handler.next(error);
      },
    ));
  }

  // Authentication Methods
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String confirmPassword,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
      });

      // Handle the response format from the new backend
      final data = response.data;
      if (data['success'] == true) {
        return {
          'message': data['message'] ?? 'Registration successful',
          'user': data['user'],
          'tokens': data['tokens'] ?? {}, // May not be present in registration
        };
      } else {
        throw Exception(data['message'] ?? 'Registration failed');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Create student profile with full details (for student registration)
  Future<Map<String, dynamic>> createStudentProfile({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
    required String phoneNumber,
    required String fatherName,
    required String emergencyPhoneNumber,
    required String fullAddress,
    required String cnicNumber,
    String? studentPhotoPath, // Optional photo file path
  }) async {
    try {
      // Build form data
      final formDataMap = <String, dynamic>{
        'full_name': fullName,
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
        'phone_number': phoneNumber,
        'father_name': fatherName,
        'emergency_phone_number': emergencyPhoneNumber,
        'full_address': fullAddress,
        'cnic_number': cnicNumber,
      };

      // Add photo file if provided
      if (studentPhotoPath != null && studentPhotoPath.isNotEmpty) {
        formDataMap['student_photo'] = await MultipartFile.fromFile(
          studentPhotoPath,
          filename: studentPhotoPath.split('/').last,
        );
      }

      final formData = FormData.fromMap(formDataMap);

      // Note: This endpoint does NOT require authentication (public registration)
      // Create a temporary Dio instance without interceptors to avoid auth issues
      final publicDio = Dio(BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          // DO NOT set Content-Type - Dio will set it automatically with boundary for FormData
          // DO NOT include Authorization header
        },
      ));

      // Ensure no interceptors are added
      publicDio.interceptors.clear();

      // Explicitly ensure no Authorization header
      print(
          '[STUDENT_REGISTRATION] Making request to: $_baseUrl/admin/create-student-profile');
      print(
          '[STUDENT_REGISTRATION] Headers before request: ${publicDio.options.headers}');

      final response = await publicDio.post(
        '/admin/create-student-profile',
        data: formData,
        options: Options(
          headers: {
            // Explicitly do NOT include Authorization
            // Let Dio set Content-Type automatically for FormData
          },
          validateStatus: (status) =>
              status! < 500, // Accept all status codes < 500
        ),
      );

      print('[STUDENT_REGISTRATION] Response status: ${response.statusCode}');
      print('[STUDENT_REGISTRATION] Response data: ${response.data}');

      final data = response.data;

      // Check for error in response
      if (response.statusCode != 201 && response.statusCode != 200) {
        print(
            '[STUDENT_REGISTRATION] Error response: Status ${response.statusCode}, Data: $data');
        throw Exception(data['error'] ??
            data['message'] ??
            'Student profile creation failed');
      }

      if (data['success'] == true) {
        return {
          'message': data['message'] ?? 'Student profile created successfully',
          'student': data['student'],
        };
      } else {
        throw Exception(data['error'] ??
            data['message'] ??
            'Student profile creation failed');
      }
    } on DioException catch (e) {
      print('[STUDENT_REGISTRATION] DioException: ${e.message}');
      print('[STUDENT_REGISTRATION] Response: ${e.response?.data}');
      print('[STUDENT_REGISTRATION] Status Code: ${e.response?.statusCode}');
      print('[STUDENT_REGISTRATION] Headers: ${e.response?.headers}');
      throw _handleDioError(e);
    } catch (e) {
      print('[STUDENT_REGISTRATION] General Exception: $e');
      rethrow;
    }
  }

  // Get student profile by email
  Future<Map<String, dynamic>> getStudentProfile({
    required String email,
  }) async {
    try {
      // Create a temporary Dio instance without interceptors for public endpoint
      final publicDio = Dio(BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
        },
      ));

      final encodedEmail = Uri.encodeComponent(email);
      final response = await publicDio.get(
        '/admin/get-student-profile?email=$encodedEmail',
      );

      final data = response.data;
      if (data['success'] == true) {
        return {
          'student': data['student'],
        };
      } else {
        throw Exception(data['error'] ?? 'Failed to get student profile');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    bool rememberMe = false,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
        'remember_me': rememberMe,
        'device_info': deviceInfo,
      });

      // Handle the response format from the new backend
      final data = response.data;
      if (data['success'] == true) {
        // Store token securely if available
        if (data['token'] != null) {
          await _storage.write(
            key: 'access_token',
            value: data['token'],
          );
        }

        // Store refresh token if available (for remember me)
        if (data['refresh_token'] != null) {
          await _storage.write(
            key: 'refresh_token',
            value: data['refresh_token'],
          );
        }

        // Store remember me preference
        await _storage.write(
          key: 'remember_me',
          value: rememberMe.toString(),
        );

        // Store user credentials for auto-login if remember me is enabled
        if (rememberMe) {
          print('[API] Remember me enabled, storing credentials...');
          await _storage.write(
            key: 'saved_email',
            value: email,
          );
          await _storage.write(
            key: 'saved_password',
            value: password,
          );
          print('[API] Credentials stored successfully');
        } else {
          print('[API] Remember me disabled, clearing saved credentials...');
          // Clear saved credentials if remember me is disabled
          await _storage.delete(key: 'saved_email');
          await _storage.delete(key: 'saved_password');
        }

        return {
          'message': data['message'] ?? 'Login successful',
          'user': data['user'],
          'token': data['token'],
          'refresh_token': data['refresh_token'],
          'expires_in': data['expires_in'],
        };
      } else {
        throw Exception(data['message'] ?? 'Login failed');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await _dio.get('/auth/dashboard');
      final data = response.data;

      // Handle the response format from the new backend
      if (data['success'] == true || data['dashboard_type'] != null) {
        return {
          'dashboard_type': data['dashboard_type'] ?? 'student',
          'user': data['user'],
          'stats': data['stats'] ?? {},
          'recent_activities': data['recent_activities'] ?? [],
          'upcoming_classes': data['upcoming_classes'] ?? [],
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to get dashboard data');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) {
        throw Exception('No refresh token available');
      }

      final response = await _dio.post('/auth/refresh-token', data: {
        'refresh': refreshToken,
      });

      final data = response.data;

      // Handle the response format from the new backend
      if (data['success'] == true) {
        // Update stored tokens
        if (data['token'] != null) {
          await _storage.write(
            key: 'access_token',
            value: data['token'],
          );
        }

        if (data['refresh_token'] != null) {
          await _storage.write(
            key: 'refresh_token',
            value: data['refresh_token'],
          );
        }

        return {
          'message': data['message'] ?? 'Token refreshed successfully',
          'token': data['token'],
          'refresh_token': data['refresh_token'],
          'expires_in': data['expires_in'],
        };
      } else {
        throw Exception(data['message'] ?? 'Token refresh failed');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Check if user has saved credentials for auto-login
  Future<Map<String, dynamic>?> getSavedCredentials() async {
    try {
      final rememberMe = await _storage.read(key: 'remember_me');
      print('[API] Remember me flag: $rememberMe');
      if (rememberMe != 'true') {
        print('[API] Remember me is not enabled');
        return null;
      }

      final email = await _storage.read(key: 'saved_email');
      final password = await _storage.read(key: 'saved_password');
      print('[API] Saved email: ${email != null ? 'present' : 'null'}');
      print('[API] Saved password: ${password != null ? 'present' : 'null'}');

      if (email != null && password != null) {
        print('[API] Returning saved credentials');
        return {
          'email': email,
          'password': password,
        };
      }
      print('[API] No saved credentials found');
      return null;
    } catch (e) {
      print('[API] Error getting saved credentials: $e');
      return null;
    }
  }

  /// Clear all saved credentials and tokens
  Future<void> clearAllCredentials() async {
    try {
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
      await _storage.delete(key: 'remember_me');
      await _storage.delete(key: 'saved_email');
      await _storage.delete(key: 'saved_password');
    } catch (e) {
      // Ignore errors when clearing storage
    }
  }

  /// Check if user has a valid token
  Future<bool> hasValidToken() async {
    try {
      final token = await _storage.read(key: 'access_token');
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> checkPasswordStrength(String password) async {
    try {
      final response =
          await _dio.post('/api/auth/check-password-strength', data: {
        'password': password,
      });

      final data = response.data;

      // Handle the response format from the new backend
      if (data['success'] == true || data['strength'] != null) {
        return {
          'strength': data['strength'] ?? 0,
          'errors': data['feedback'] ?? [],
          'is_valid': (data['strength'] ?? 0) >= 4, // Minimum strength of 4/5
          'feedback': data['feedback'] ?? [],
        };
      } else {
        throw Exception(data['message'] ?? 'Password strength check failed');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Student Methods
  Future<Map<String, dynamic>> getStudentDashboard() async {
    try {
      final response = await _dio.get('/courses/student/dashboard');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<List<dynamic>> getStudentCourses() async {
    try {
      // Backend provides enrolled courses at /api/courses/student/enrolled
      final response = await _dio.get('/courses/student/enrolled');
      return response.data['courses'] ?? [];
    } on DioException catch (e) {
      // Handle authentication errors specifically
      if (e.response?.statusCode == 401) {
        // Try to refresh token
        try {
          await _refreshToken();
          // Retry the request with new token
          final retryResponse = await _dio.get('/courses/student/enrolled');
          return retryResponse.data['courses'] ?? [];
        } catch (refreshError) {
          throw 'Authentication failed. Please login again.';
        }
      }
      // Handle server errors (like MongoDB connection issues)
      if (e.response?.statusCode == 500) {
        throw 'Server temporarily unavailable. Please try again later.';
      }
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getStudentCourseDetail(String courseId) async {
    try {
      print('Looking for course with ID: $courseId');

      // First try to get course details from enrolled courses
      try {
        final enrolledResponse = await _dio.get('/courses/student/enrolled');
        final enrolledCourses = enrolledResponse.data['courses'] ?? [];
        print('Found ${enrolledCourses.length} enrolled courses');

        // Debug: Print all enrolled course IDs
        for (var course in enrolledCourses) {
          print(
              'Enrolled course - _id: ${course['_id']}, id: ${course['id']}, slug: ${course['slug']}');
        }

        final enrolledCourse = enrolledCourses.firstWhere(
          (c) =>
              c['_id'] == courseId ||
              c['id'] == courseId ||
              c['slug'] == courseId,
          orElse: () => null,
        );

        if (enrolledCourse != null) {
          print('Found course in enrolled courses');
          return {
            'success': true,
            'course': enrolledCourse,
            'progress': {
              'completed_lectures': enrolledCourse['completed_lectures'] ?? 0,
              'total_lectures': enrolledCourse['total_lectures'] ?? 0,
              'progress_percentage': enrolledCourse['progress'] ?? 0.0
            }
          };
        }
      } catch (e) {
        // If enrolled courses endpoint fails, continue to general courses
        print('Failed to get enrolled course: $e');
      }

      // If not found in enrolled courses, try general courses endpoint
      print('Trying general courses endpoint');
      final response = await _dio.get('/courses');
      final courses = response.data['courses'] ?? [];
      print('Found ${courses.length} general courses');

      // Debug: Print all general course IDs
      for (var course in courses) {
        print(
            'General course - _id: ${course['_id']}, id: ${course['id']}, slug: ${course['slug']}');
      }

      final course = courses.firstWhere(
        (c) =>
            c['_id'] == courseId ||
            c['id'] == courseId ||
            c['slug'] == courseId,
        orElse: () => null,
      );

      if (course == null) {
        print('Course not found in any endpoint');
        throw Exception('Course not found');
      }

      print('Found course in general courses');
      return {
        'success': true,
        'course': course,
        'progress': {
          'completed_lectures': 0,
          'total_lectures': 0,
          'progress_percentage': 0.0
        }
      };
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getStudentLectureDetail(
    String courseSlug,
    String lectureId,
  ) async {
    try {
      final response = await _dio.get(
        '/courses/student/courses/$courseSlug/lectures/$lectureId/',
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> markLectureComplete(
    String courseSlug,
    String lectureId,
  ) async {
    try {
      final response = await _dio.post(
        '/courses/student/courses/$courseSlug/lectures/$lectureId/complete/',
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<List<dynamic>> getStudentLiveClasses() async {
    try {
      final response = await _dio.get('/live-classes');
      return response.data['classes'] ?? [];
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getStudentProgress() async {
    try {
      final response = await _dio.get('/user/progress');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // User session tracking
  Future<void> startUserSession() async {
    try {
      await _dio.post('/user/sessions/start');
    } on DioException catch (e) {
      // Don't block login on session tracking errors
      _handleDioError(e);
    }
  }

  Future<void> endUserSession() async {
    try {
      await _dio.post('/user/sessions/end');
    } on DioException catch (e) {
      // Ignore errors on logout
      _handleDioError(e);
    }
  }

  // Update study hours goal
  Future<Map<String, dynamic>> updateHoursGoal(double hours) async {
    try {
      final response = await _dio.put(
        '/user/progress/hours-goal',
        data: {'hours': hours},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Mark a specific course item (video, resource, task) as complete for the current student
  Future<Map<String, dynamic>> completeCourseItem({
    required String courseId,
    required String itemType, // 'video', 'resource', or 'task'
    required String itemId,
  }) async {
    try {
      final response = await _dio.post(
        '/courses/student/progress/complete',
        data: {
          'course_id': courseId,
          'item_type': itemType,
          'item_id': itemId,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Get all completed items for a specific course for the current student
  Future<List<dynamic>> getCompletedCourseItems({
    required String courseId,
  }) async {
    try {
      final response = await _dio.get(
        '/courses/student/progress/items',
        queryParameters: {
          'course_id': courseId,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['items'] ?? [];
      }
      return [];
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Course Discovery Methods
  Future<List<dynamic>> getAvailableCourses() async {
    try {
      // Use the general courses endpoint to get all available courses
      final response = await _dio.get('/courses');
      return response.data['courses'] ?? [];
    } on DioException catch (e) {
      // Handle authentication errors specifically
      if (e.response?.statusCode == 401) {
        // Try to refresh token
        try {
          await _refreshToken();
          // Retry the request with new token
          final retryResponse = await _dio.get('/courses');
          return retryResponse.data['courses'] ?? [];
        } catch (refreshError) {
          throw 'Authentication failed. Please login again.';
        }
      }
      throw _handleDioError(e);
    }
  }

  Future<List<dynamic>> getFeaturedCourses() async {
    try {
      // Use the general courses endpoint and filter for featured courses
      final response = await _dio.get('/courses');
      final allCourses = response.data['courses'] ?? [];
      // Filter for featured courses (you can add a featured field to courses later)
      return allCourses.take(6).toList(); // Show first 6 as featured
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<List<dynamic>> getPopularCourses() async {
    try {
      // Use the general courses endpoint and filter for popular courses
      final response = await _dio.get('/courses');
      final allCourses = response.data['courses'] ?? [];
      // Filter for popular courses (you can add a popular field to courses later)
      return allCourses.skip(6).take(6).toList(); // Show next 6 as popular
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Streaming Methods
  Future<Map<String, dynamic>> getStreamingUrl(String lectureId) async {
    try {
      // Use longer timeouts for streaming requests
      final response = await _dio.get(
        '/streaming/$lectureId',
        options: Options(
          receiveTimeout: const Duration(minutes: 2),
          sendTimeout: const Duration(minutes: 2),
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> refreshStreamingUrl(String lectureId) async {
    try {
      // Use longer timeouts for streaming requests
      final response = await _dio.get(
        '/streaming/$lectureId/refresh',
        options: Options(
          receiveTimeout: const Duration(minutes: 2),
          sendTimeout: const Duration(minutes: 2),
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> enrollInCourse(String courseId) async {
    try {
      final response = await _dio.post('/courses/student/enroll', data: {
        'course_id': courseId,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> unenrollFromCourse(String courseId) async {
    try {
      final response = await _dio.post('/courses/student/unenroll', data: {
        'course_id': courseId,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Course Reviews
  Future<List<dynamic>> getCourseReviews(String courseSlug) async {
    try {
      final response = await _dio.get('/courses/reviews-mongo/$courseSlug/');
      return response.data['reviews'] ?? [];
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> addCourseReview(
    String courseSlug, {
    required int rating,
    required String comment,
  }) async {
    try {
      final response =
          await _dio.post('/courses/add-review/$courseSlug/', data: {
        'rating': rating,
        'comment': comment,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Course Materials & Announcements

  Future<List<dynamic>> getCourseAnnouncements(String courseSlug) async {
    try {
      final response =
          await _dio.get('/courses/announcements-mongo/$courseSlug/');
      return response.data['announcements'] ?? [];
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Teacher Methods
  Future<Map<String, dynamic>> getTeacherDashboard() async {
    try {
      final response = await _dio.get('/courses/teacher/dashboard');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<List<dynamic>> getTeacherCourses() async {
    try {
      final response = await _dio.get('/courses/teacher/courses');
      return response.data['courses'] ?? [];
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> createTeacherCourse(
      Map<String, dynamic> courseData) async {
    try {
      final response =
          await _dio.post('/courses/teacher/create', data: courseData);
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> updateTeacherCourse(
      String courseId, Map<String, dynamic> courseData) async {
    try {
      final response = await _dio.put('/courses/teacher/courses/$courseId',
          data: courseData);
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> deleteTeacherCourse(String courseId) async {
    try {
      final response = await _dio.delete('/courses/teacher/courses/$courseId');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Teacher Analytics
  Future<Map<String, dynamic>> getTeacherAnalytics({String? courseId}) async {
    try {
      final queryParams = courseId != null ? '?course_id=$courseId' : '';
      final response = await _dio.get('/courses/teacher/analytics$queryParams');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Teacher Students
  Future<Map<String, dynamic>> getTeacherStudents({String? courseId}) async {
    try {
      final queryParams = courseId != null ? '?course_id=$courseId' : '';
      final response = await _dio.get('/courses/teacher/students$queryParams');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Teacher Assignments
  Future<Map<String, dynamic>> getTeacherAssignments({String? courseId}) async {
    try {
      final queryParams = courseId != null ? '?course_id=$courseId' : '';
      final response =
          await _dio.get('/courses/teacher/assignments$queryParams');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> createTeacherAssignment({
    required String courseId,
    required String title,
    String? description,
    String? dueDate,
    int points = 0,
    File? file,
  }) async {
    try {
      if (file != null) {
        // Use FormData for file upload
        final formData = FormData.fromMap({
          'course_id': courseId,
          'title': title,
          'description': description ?? '',
          'due_date': dueDate ?? '',
          'points': points,
          'file': await MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last,
          ),
        });

        final response = await _dio.post(
          '/courses/teacher/assignments',
          data: formData,
        );
        return response.data;
      } else {
        // Regular JSON request without file
        final response = await _dio.post('/courses/teacher/assignments', data: {
          'course_id': courseId,
          'title': title,
          'description': description ?? '',
          'due_date': dueDate ?? '',
          'points': points,
        });
        return response.data;
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Get course by ID
  Future<Map<String, dynamic>> getCourseById(String courseId) async {
    try {
      final response = await _dio.get('/courses/$courseId');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Chat/Messaging Methods
  // Student Chat Methods
  Future<List<dynamic>> getStudentConversations() async {
    try {
      final response = await _dio.get('/chat/student/conversations');
      return response.data['conversations'] ?? [];
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getStudentConversation(String courseId) async {
    try {
      // Ensure we have a token before making the request
      final token = await _storage.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token required');
      }

      // Make the request with explicit authorization header
      final response = await _dio.get(
        '/chat/student/conversation/$courseId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> sendStudentMessage({
    required String courseId,
    required String message,
    String messageType = 'text',
  }) async {
    try {
      // Ensure we have a token before making the request
      final token = await _storage.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token required');
      }

      // Make the request with explicit authorization header
      final response = await _dio.post(
        '/chat/student/send-message',
        data: {
          'course_id': courseId,
          'message': message,
          'message_type': messageType,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Teacher Chat Methods
  Future<List<dynamic>> getTeacherConversations() async {
    try {
      final response = await _dio.get('/chat/teacher/conversations');
      return response.data['conversations'] ?? [];
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getTeacherConversation(
      String conversationId) async {
    try {
      final response =
          await _dio.get('/chat/teacher/conversation/$conversationId');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> sendTeacherMessage({
    required String conversationId,
    required String message,
    String messageType = 'text',
  }) async {
    try {
      final response = await _dio.post('/chat/teacher/send-message', data: {
        'conversation_id': conversationId,
        'message': message,
        'message_type': messageType,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Admin Methods
  Future<Map<String, dynamic>> getAdminDashboard() async {
    try {
      final response = await _dio.get('/admin/dashboard');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getAdminStudents() async {
    try {
      final response = await _dio.get('/admin/users');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getAdminTeachers() async {
    try {
      final response = await _dio.get('/admin/users');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // New: generic admin users fetch with pagination and optional role filter
  Future<Map<String, dynamic>> getAdminUsers({
    int page = 1,
    int limit = 100,
    String? role,
  }) async {
    try {
      final response = await _dio.get(
        '/admin/users',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (role != null) 'role': role,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getAdminCourses() async {
    try {
      final response = await _dio.get('/admin/courses');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getAdminLectures() async {
    try {
      final response = await _dio.get('/admin/lectures');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getAvailableTeachers() async {
    try {
      final response = await _dio.get('/admin/instructors');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getAdminAnalytics() async {
    try {
      final response = await _dio.get('/admin/analytics');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Admin User Management
  Future<Map<String, dynamic>> updateUserStatus(
      String userId, bool isActive) async {
    try {
      final response = await _dio.put('/admin/users/$userId/status', data: {
        'is_active': isActive,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Admin Course Management
  Future<Map<String, dynamic>> deleteAdminCourse(String courseId) async {
    try {
      final response = await _dio.delete('/admin/courses/$courseId');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Admin Student Management
  Future<Map<String, dynamic>> deleteAdminStudent(String studentId) async {
    try {
      final response = await _dio.delete('/admin/delete-student/$studentId');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> createCourse(
      Map<String, dynamic> courseData) async {
    try {
      final response = await _dio.post('/admin/courses', data: courseData);
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> updateCourse(
      String courseId, Map<String, dynamic> courseData) async {
    try {
      final response =
          await _dio.put('/admin/courses/$courseId', data: courseData);
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Upload lecture content
  Future<Map<String, dynamic>> uploadLecture({
    required String courseId,
    required String title,
    required String description,
    required String fileUrl,
    required String contentType,
  }) async {
    try {
      final response = await _dio
          .post('/courses/admin/courses/$courseId/lectures/upload/', data: {
        'title': title,
        'description': description,
        'file_url': fileUrl,
        'content_type': contentType,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Course materials
  Future<Map<String, dynamic>> getCourseMaterials(String courseId) async {
    try {
      final response = await _dio.get('/courses/$courseId/materials');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Get student assignments for a course
  Future<Map<String, dynamic>> getStudentAssignments({String? courseId}) async {
    try {
      final queryParams = courseId != null ? '?course_id=$courseId' : '';
      final response = await _dio.get('/courses/student/assignments$queryParams');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Get course lectures for students
  Future<Map<String, dynamic>> getCourseLectures(String courseId) async {
    try {
      final response = await _dio.get('/courses/$courseId/lectures');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Get specific lecture details
  Future<Map<String, dynamic>> getLectureDetail(String lectureId) async {
    try {
      final response = await _dio.get('/lectures/$lectureId');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // File upload for lecture materials
  Future<Map<String, dynamic>> uploadLectureFile({
    required String filePath,
    required String courseId,
    required String lectureId,
    required String fileType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
        'course_id': courseId,
        'lecture_id': lectureId,
        'file_type': fileType,
      });

      final response = await _dio.post(
        '/admin/upload',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Chunked upload method for large files
  Future<Map<String, dynamic>> uploadChunk(FormData formData) async {
    try {
      // ULTRA VERBOSE DEBUGGING - Print all fields being sent
      print('[CHUNK UPLOAD DEBUG] === STARTING CHUNK UPLOAD ===');
      print('[CHUNK UPLOAD DEBUG] FormData fields:');

      // Print all fields in the form data for debugging
      (formData.fields).forEach((field) {
        print('[CHUNK UPLOAD DEBUG] Field: ${field.key} = ${field.value}');
      });

      // Print the files in the form data
      (formData.files).forEach((file) {
        print(
            '[CHUNK UPLOAD DEBUG] File: ${file.key}, filename: ${file.value.filename}, contentType: ${file.value.contentType}');
      });

      // Get the token
      final token = await _storage.read(key: 'access_token');
      print('[CHUNK UPLOAD DEBUG] Token available: ${token != null}');
      if (token != null) {
        print(
            '[CHUNK UPLOAD DEBUG] Token (first 20 chars): ${token.length > 20 ? token.substring(0, 20) : token}');
      } else {
        print('[CHUNK UPLOAD DEBUG] Token: NULL TOKEN');
      }

      // Print the base URL for debugging
      print('[CHUNK UPLOAD DEBUG] Base URL: ${_dio.options.baseUrl}');
      print(
          '[CHUNK UPLOAD DEBUG] Full URL: ${_dio.options.baseUrl}/api/admin/upload-chunk');

      // IMPORTANT: Try both with and without the Cloudflare Workers URL
      // The error might be that we're trying to go through Cloudflare instead of directly to Vultr
      final directVultrUrl = 'https://api.amlms.com/api/admin/upload-chunk';
      print('[CHUNK UPLOAD DEBUG] Trying direct Vultr URL: $directVultrUrl');

      try {
        // First try direct to Vultr (bypassing Cloudflare Workers)
        final directResponse = await Dio().post(
          directVultrUrl,
          data: formData,
          options: Options(
            headers: {
              'Authorization': token != null ? 'Bearer $token' : '',
              'x-debug-source': 'flutter-direct-vultr',
            },
            receiveTimeout: Duration(minutes: 5),
            sendTimeout: Duration(minutes: 5),
          ),
        );

        print(
            '[CHUNK UPLOAD SUCCESS] Direct to Vultr response: ${directResponse.statusCode}');
        print(
            '[CHUNK UPLOAD SUCCESS] Direct to Vultr data: ${directResponse.data}');

        return directResponse.data;
      } catch (directError) {
        print('[CHUNK UPLOAD ERROR] Direct to Vultr failed: $directError');

        // If direct approach fails, fall back to the normal route through Cloudflare
        print(
            '[CHUNK UPLOAD DEBUG] Falling back to normal route through Cloudflare Workers');

        final response = await _dio.post(
          '/api/admin/upload-chunk',
          data: formData,
          options: Options(
            headers: {
              'Authorization': token != null ? 'Bearer $token' : '',
              'x-debug-source': 'flutter-via-cloudflare',
            },
            receiveTimeout: Duration(minutes: 5),
            sendTimeout: Duration(minutes: 5),
          ),
        );

        print(
            '[CHUNK UPLOAD SUCCESS] Cloudflare response status: ${response.statusCode}');
        print(
            '[CHUNK UPLOAD SUCCESS] Cloudflare response data: ${response.data}');

        return response.data;
      }
    } on DioException catch (e) {
      print('[CHUNK UPLOAD ERROR] === UPLOAD ERROR DETAILS ===');
      print('[CHUNK UPLOAD ERROR] Error message: ${e.message}');
      print('[CHUNK UPLOAD ERROR] Request URL: ${e.requestOptions.uri}');
      print('[CHUNK UPLOAD ERROR] Request method: ${e.requestOptions.method}');
      print(
          '[CHUNK UPLOAD ERROR] Request headers: ${e.requestOptions.headers}');

      if (e.response != null) {
        print(
            '[CHUNK UPLOAD ERROR] Response status: ${e.response?.statusCode}');
        print('[CHUNK UPLOAD ERROR] Response data: ${e.response?.data}');
        print('[CHUNK UPLOAD ERROR] Response headers: ${e.response?.headers}');
      } else {
        print(
            '[CHUNK UPLOAD ERROR] No response received (connection error or timeout)');
      }

      throw _handleDioError(e);
    } catch (e) {
      print('[CHUNK UPLOAD ERROR] Unexpected error: $e');
      throw Exception('Unexpected error during upload: $e');
    }
  }

  // Get upload progress
  Future<Map<String, dynamic>> getUploadProgress(String sessionId) async {
    try {
      final response = await _dio.get('/api/admin/upload-progress/$sessionId');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Utility Methods
  Future<void> logout({String? deviceId}) async {
    try {
      // Call logout endpoint to remove device registration
      if (deviceId != null) {
        try {
          await _dio.post('/auth/logout', data: {
            'device_id': deviceId,
          });
        } catch (e) {
          // Continue with logout even if API call fails
          debugPrint('Logout API call failed: $e');
        }
      }
    } catch (e) {
      // Continue with logout even if device info retrieval fails
      debugPrint('Failed to get device info for logout: $e');
    }

    // Clear stored tokens
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<bool> _refreshToken() async {
    try {
      await refreshToken();
      return true;
    } catch (e) {
      return false;
    }
  }

  String _handleDioError(DioException error) {
    if (error.response?.data != null) {
      final data = error.response!.data;
      if (data is Map<String, dynamic>) {
        if (data['error'] != null) {
          return data['error'];
        }
        if (data['detail'] != null) {
          return data['detail'];
        }
        if (data['message'] != null) {
          return data['message'];
        }
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.sendTimeout:
        return 'Request timeout. Please try again.';
      case DioExceptionType.receiveTimeout:
        return 'Response timeout. Please try again.';
      case DioExceptionType.badResponse:
        return 'Server error. Please try again later.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}

// Singleton instance
final apiService = ApiService();
