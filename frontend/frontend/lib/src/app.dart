import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/config/app_router.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/logger.dart';

class LMSApp extends ConsumerWidget {
  const LMSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // Listen to auth state changes for logging
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.status != next.status) {
        AppLogger.info('Auth state changed: ${next.status}');
      }
    });

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,

      // Theme Configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // Locale Configuration
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('es', 'ES'),
        Locale('fr', 'FR'),
        Locale('hi', 'IN'),
      ],

      // Router Configuration
      routerConfig: ref.watch(routerProvider),

      // Builder for global configuration
      builder: (context, child) {
        return MediaQuery(
          // Ensure text scale factor doesn't exceed reasonable limits
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(MediaQuery.of(
              context,
            ).textScaleFactor.clamp(0.8, 1.4)),
          ),
          child: PopScope(
            canPop: false,
            onPopInvoked: (didPop) {
              if (didPop) return;
              final router = ref.read(routerProvider);
              if (router.canPop()) {
                router.pop();
              }
            },
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
