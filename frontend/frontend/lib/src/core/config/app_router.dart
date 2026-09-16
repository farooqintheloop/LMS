import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/dashboard/presentation/pages/student_dashboard_page.dart';
import '../../features/student/screens/course_detail_screen.dart';
import '../../features/student/screens/video_player_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // If user is not authenticated and trying to access protected routes
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // If user is authenticated and trying to access auth routes
      if (isAuthenticated && isAuthRoute) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Authentication Routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),

      // Protected Routes
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const StudentDashboardPage(),
        redirect: (context, state) {
          // Additional protection for dashboard
          final container = ProviderScope.containerOf(context);
          final authState = container.read(authProvider);
          if (!authState.isAuthenticated) {
            return '/login';
          }
          return null;
        },
      ),

      // Student Routes
      GoRoute(
        path: '/courses',
        name: 'courses',
        builder: (context, state) => const StudentDashboardPage(),
        redirect: (context, state) {
          final container = ProviderScope.containerOf(context);
          final authState = container.read(authProvider);
          if (!authState.isAuthenticated) {
            return '/login';
          }
          return null;
        },
      ),

      GoRoute(
        path: '/live-classes',
        name: 'live-classes',
        builder: (context, state) => const StudentDashboardPage(),
        redirect: (context, state) {
          final container = ProviderScope.containerOf(context);
          final authState = container.read(authProvider);
          if (!authState.isAuthenticated) {
            return '/login';
          }
          return null;
        },
      ),

      GoRoute(
        path: '/progress',
        name: 'progress',
        builder: (context, state) => const StudentDashboardPage(),
        redirect: (context, state) {
          final container = ProviderScope.containerOf(context);
          final authState = container.read(authProvider);
          if (!authState.isAuthenticated) {
            return '/login';
          }
          return null;
        },
      ),

      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const StudentDashboardPage(),
        redirect: (context, state) {
          final container = ProviderScope.containerOf(context);
          final authState = container.read(authProvider);
          if (!authState.isAuthenticated) {
            return '/login';
          }
          return null;
        },
      ),

      // Course Detail Route
      GoRoute(
        path: '/student/course/:slug',
        name: 'course-detail',
        builder: (context, state) =>
            CourseDetailScreen(courseSlug: state.pathParameters['slug']!),
      ),

      // Video Player Route
      GoRoute(
        path: '/student/video-player',
        name: 'video-player',
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
          // Fallback to a default video player
          return const VideoPlayerScreen(
            lectureId: 'default',
            lectureTitle: 'Default Lecture',
            courseTitle: 'Default Course',
            videoUrl: 'https://www.youtube.com/watch?v=kBV8gPVZNEE',
          );
        },
      ),

      // Catch all route
      GoRoute(
        path: '/:pathMatch(.*)*',
        name: 'not-found',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Page Not Found',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'The page you are looking for does not exist.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Go Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'An error occurred while loading the page.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
