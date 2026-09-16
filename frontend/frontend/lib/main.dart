import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'src/core/providers/auth_provider.dart';
import 'src/core/providers/theme_provider.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/widgets/secure_screen_wrapper.dart';
import 'src/core/widgets/emulator_blocker.dart';
import 'src/features/auth/screens/login_screen.dart';
import 'src/features/auth/screens/register_screen.dart';
import 'src/features/auth/screens/terms_of_service_screen.dart';
import 'src/features/auth/screens/privacy_policy_screen.dart';
import 'src/features/student/screens/student_dashboard_screen.dart';
import 'src/features/student/screens/course_list_screen.dart';
import 'src/features/student/screens/course_detail_screen.dart';
import 'src/features/student/screens/video_player_screen.dart';
import 'src/features/student/screens/pdf_viewer_screen.dart';
import 'src/features/student/screens/downloaded_videos_screen.dart';
import 'src/features/teacher/screens/teacher_dashboard_screen.dart';
import 'src/features/teacher/screens/teacher_courses_screen.dart';
import 'src/features/teacher/screens/teacher_conversations_screen.dart';
import 'src/features/teacher/screens/teacher_chat_screen.dart';
import 'src/features/teacher/screens/teacher_course_detail_screen.dart';
import 'src/features/student/screens/student_chat_screen.dart';
import 'src/features/admin/screens/admin_dashboard_screen.dart';
import 'src/features/admin/screens/admin_student_management_screen.dart';
import 'src/features/admin/screens/admin_teacher_management_screen.dart';
import 'src/features/admin/screens/admin_course_management_screen.dart';
import 'src/features/admin/screens/admin_lecture_management_screen.dart';
import 'src/features/admin/screens/admin_analytics_screen.dart';
import 'src/features/admin/screens/admin_reports_coming_soon_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: EmulatorBlocker(
        child: LMSApp(),
      ),
    ),
  );
}

class LMSApp extends ConsumerStatefulWidget {
  const LMSApp({super.key});

  @override
  ConsumerState<LMSApp> createState() => _LMSAppState();
}

class _LMSAppState extends ConsumerState<LMSApp> {
  bool _isInitialized = false;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final authState = ref.read(authProvider);
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/terms-of-service' ||
            state.matchedLocation == '/privacy-policy';

        // If user is not authenticated and trying to access protected route
        if (!authState.isAuthenticated && !isAuthRoute) {
          return '/login';
        }

        // If user is authenticated and trying to access auth routes
        if (authState.isAuthenticated && isAuthRoute) {
          // Redirect to appropriate dashboard based on role
          final user = authState.user;
          if (user != null) {
            switch (user['role']) {
              case 'student':
                return '/student/dashboard';
              case 'teacher':
                return '/teacher/dashboard';
              case 'admin':
              case 'super_admin':
                return '/admin/dashboard';
              default:
                return '/student/dashboard';
            }
          }
        }

        return null;
      },
      routes: [
        // Auth Routes
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/terms-of-service',
          builder: (context, state) => const TermsOfServiceScreen(),
        ),
        GoRoute(
          path: '/privacy-policy',
          builder: (context, state) => const PrivacyPolicyScreen(),
        ),

        // Student Routes
        GoRoute(
          path: '/student/dashboard',
          builder: (context, state) => const StudentDashboardScreen(),
        ),
        GoRoute(
          path: '/student/courses',
          builder: (context, state) => const CourseListScreen(),
        ),
        GoRoute(
          path: '/student/course/:courseId',
          builder: (context, state) {
            final courseId = state.pathParameters['courseId']!;
            return CourseDetailScreen(courseSlug: courseId);
          },
        ),

        // Video Player Route
        GoRoute(
          path: '/student/video-player',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            if (extra != null) {
              return VideoPlayerScreen(
                lectureId: extra['lectureId'] ?? '',
                lectureTitle: extra['lectureTitle'] ?? '',
                courseTitle: extra['courseTitle'] ?? '',
                videoUrl: extra['videoUrl'],
                needsStreamingUrl: extra['needsStreamingUrl'] ?? false,
              );
            }
            // Fallback
            return const VideoPlayerScreen(
              lectureId: 'default',
              lectureTitle: 'Default Video',
              courseTitle: 'Default Course',
              videoUrl: '',
            );
          },
        ),

        // PDF Viewer Route
        GoRoute(
          path: '/student/pdf-viewer',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            if (extra != null) {
              return PdfViewerScreen(
                lectureId: extra['lectureId'] ?? '',
                lectureTitle: extra['lectureTitle'] ?? '',
                courseTitle: extra['courseTitle'] ?? '',
                pdfUrl: extra['pdfUrl'] ?? '',
              );
            }
            // Fallback
            return const PdfViewerScreen(
              lectureId: 'default',
              lectureTitle: 'Default PDF',
              courseTitle: 'Default Course',
              pdfUrl: '',
            );
          },
        ),

        // Downloaded Videos Route
        GoRoute(
          path: '/student/downloaded-videos',
          builder: (context, state) => const DownloadedVideosScreen(),
        ),

        // Student Chat Route
        GoRoute(
          path: '/student/chat/:courseId',
          builder: (context, state) {
            final courseId = state.pathParameters['courseId']!;
            final extra = state.extra as Map<String, dynamic>?;
            if (extra != null) {
              return StudentChatScreen(
                courseId: courseId,
                courseTitle: extra['courseTitle'] ?? 'Course',
                instructorName: extra['instructorName'] ?? 'Instructor',
              );
            }
            // Fallback
            return StudentChatScreen(
              courseId: courseId,
              courseTitle: 'Course',
              instructorName: 'Instructor',
            );
          },
        ),

        // Teacher Routes
        GoRoute(
          path: '/teacher/dashboard',
          builder: (context, state) => const TeacherDashboardScreen(),
        ),
        GoRoute(
          path: '/teacher/courses',
          builder: (context, state) => const TeacherCoursesScreen(),
        ),

        // Teacher Course Detail Route
        GoRoute(
          path: '/teacher/course/:courseId',
          builder: (context, state) {
            final courseId = state.pathParameters['courseId']!;
            final extra = state.extra as Map<String, dynamic>?;
            return TeacherCourseDetailScreen(
              courseId: courseId,
              courseData: extra?['courseData'],
            );
          },
        ),

        // Teacher Conversations Route
        GoRoute(
          path: '/teacher/conversations',
          builder: (context, state) => const TeacherConversationsScreen(),
        ),

        // Teacher Chat Route
        GoRoute(
          path: '/teacher/chat/:conversationId',
          builder: (context, state) {
            final conversationId = state.pathParameters['conversationId']!;
            final extra = state.extra as Map<String, dynamic>?;
            if (extra != null) {
              return TeacherChatScreen(
                conversationId: conversationId,
                studentName: extra['studentName'] ?? 'Student',
                courseTitle: extra['courseTitle'] ?? 'Course',
              );
            }
            // Fallback
            return TeacherChatScreen(
              conversationId: conversationId,
              studentName: 'Student',
              courseTitle: 'Course',
            );
          },
        ),

        // Admin Routes
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/students',
          builder: (context, state) => const AdminStudentManagementScreen(),
        ),
        GoRoute(
          path: '/admin/teachers',
          builder: (context, state) => const AdminTeacherManagementScreen(),
        ),
        GoRoute(
          path: '/admin/courses',
          builder: (context, state) => const AdminCourseManagementScreen(),
        ),
        GoRoute(
          path: '/admin/lectures',
          builder: (context, state) => const AdminLectureManagementScreen(),
        ),
        GoRoute(
          path: '/admin/analytics',
          builder: (context, state) => const AdminAnalyticsScreen(),
        ),
        GoRoute(
          path: '/admin/reports',
          builder: (context, state) => const AdminReportsComingSoonScreen(),
        ),

        // Default route
        GoRoute(
          path: '/',
          redirect: (context, state) => '/login',
        ),
      ],
    );
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Check for saved credentials on app startup
    await ref.read(authProvider.notifier).checkSavedCredentials();

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ref.watch(themeModeProvider),
        home: const SplashScreen(),
      );
    }

    return MaterialApp.router(
      title: 'LMS Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,
      builder: (context, child) {
        return SecureScreenWrapper(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler:
                  const TextScaler.linear(1.0), // Prevent text scaling issues
            ),
            child: PopScope(
              canPop: false,
              onPopInvoked: (didPop) {
                if (didPop) return;
                if (_router.canPop()) {
                  _router.pop();
                }
              },
              child: child!,
            ),
          ),
        );
      },
    );
  }
}

// Splash Screen
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();

    // Animation completed - credentials are already checked in main app
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.menu_book,
                              size: 60,
                              color: Theme.of(context).colorScheme.primary,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // App Name
                    Text(
                      'AM LMS',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),

                    // Tagline
                    Text(
                      'Learn. Grow. Succeed.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                    ),

                    const SizedBox(height: 48),

                    // Loading indicator
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
