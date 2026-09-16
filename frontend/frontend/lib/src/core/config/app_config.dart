import 'package:package_info_plus/package_info_plus.dart';

class AppConfig {
  AppConfig._();

  // App Information
  static const String appName = 'AM LMS';
  static const String appDescription = 'Advanced Learning Management System';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';

  // API Configuration
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://lms-api.muheet228.workers.dev/api',
  );

  static const String webSocketUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://lms-api.muheet228.workers.dev/ws',
  );

  // Environment
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
  static bool get isStaging => environment == 'staging';

  // API Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Video Configuration
  static const Duration videoSeekInterval = Duration(seconds: 10);
  static const Duration videoProgressUpdateInterval = Duration(seconds: 5);
  static const int videoQualityOptions = 4; // 360p, 480p, 720p, 1080p
  static const Duration videoBufferDuration = Duration(seconds: 5);

  // Notification Configuration
  static const String fcmVapidKey = String.fromEnvironment('FCM_VAPID_KEY');
  static const Duration notificationRefreshInterval = Duration(minutes: 5);

  // Cache Configuration
  static const Duration cacheValidityDuration = Duration(hours: 24);
  static const int maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const Duration imageCacheDuration = Duration(days: 7);

  // Security Configuration
  static const Duration tokenRefreshThreshold = Duration(minutes: 5);
  static const int maxLoginAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);

  // Feature Flags
  static const bool enableBiometricAuth = true;
  static const bool enableOfflineMode = true;
  static const bool enableVideoDownload = true;
  static const bool enableLiveStreaming = true;
  static const bool enablePushNotifications = true;
  static const bool enableAnalytics = true;

  // File Upload Configuration
  static const int maxFileSize = 50 * 1024 * 1024; // 50MB
  static const List<String> allowedFileTypes = [
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', // Images
    'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', // Documents
    'mp4', 'mov', 'avi', 'mkv', 'webm', // Videos
    'mp3', 'wav', 'aac', 'ogg', // Audio
    'zip', 'rar', '7z', // Archives
  ];

  // UI Configuration
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration splashScreenDuration = Duration(seconds: 3);
  static const double borderRadius = 8.0;
  static const double cardElevation = 2.0;

  // Course Configuration
  static const int maxCourseNameLength = 100;
  static const int maxCourseDescriptionLength = 1000;
  static const int maxReviewLength = 500;

  // Live Class Configuration
  static const Duration liveClassJoinBuffer = Duration(minutes: 15);
  static const Duration liveClassReminderTime = Duration(minutes: 10);

  // Error Messages
  static const String networkErrorMessage =
      'Network connection error. Please check your internet connection.';
  static const String serverErrorMessage =
      'Server error. Please try again later.';
  static const String unauthorizedErrorMessage =
      'Session expired. Please login again.';
  static const String notFoundErrorMessage = 'Requested resource not found.';
  static const String validationErrorMessage =
      'Please check your input and try again.';

  // Success Messages
  static const String loginSuccessMessage = 'Login successful!';
  static const String logoutSuccessMessage = 'Logged out successfully!';
  static const String registrationSuccessMessage = 'Registration successful!';
  static const String profileUpdateSuccessMessage =
      'Profile updated successfully!';
  static const String passwordChangeSuccessMessage =
      'Password changed successfully!';

  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String biometricKey = 'biometric_enabled';
  static const String notificationKey = 'notification_enabled';
  static const String downloadQualityKey = 'download_quality';
  static const String streamingQualityKey = 'streaming_quality';

  // Hive Box Names
  static const String authBoxName = 'auth_box';
  static const String cacheBoxName = 'cache_box';
  static const String settingsBoxName = 'settings_box';
  static const String downloadBoxName = 'download_box';
  static const String progressBoxName = 'progress_box';

  // Analytics Events
  static const String loginEvent = 'login';
  static const String logoutEvent = 'logout';
  static const String courseViewEvent = 'course_view';
  static const String lectureViewEvent = 'lecture_view';
  static const String videoPlayEvent = 'video_play';
  static const String videoPauseEvent = 'video_pause';
  static const String videoCompleteEvent = 'video_complete';
  static const String downloadEvent = 'download';
  static const String searchEvent = 'search';

  // Social Media Links
  static const String websiteUrl = 'https://lms.example.com';
  static const String supportEmail = 'support@lms.example.com';
  static const String privacyPolicyUrl = 'https://lms.example.com/privacy';
  static const String termsOfServiceUrl = 'https://lms.example.com/terms';
  static const String facebookUrl = 'https://facebook.com/lms';
  static const String twitterUrl = 'https://twitter.com/lms';
  static const String linkedinUrl = 'https://linkedin.com/company/lms';

  // Runtime configuration
  static late PackageInfo _packageInfo;
  static late String _deviceId;
  static late String _platform;

  static PackageInfo get packageInfo => _packageInfo;
  static String get deviceId => _deviceId;
  static String get platform => _platform;

  /// Initialize app configuration
  static Future<void> initialize() async {
    _packageInfo = await PackageInfo.fromPlatform();

    // Set device info
    await _initializeDeviceInfo();
  }

  static Future<void> _initializeDeviceInfo() async {
    try {
      final deviceInfo = await _getDeviceInfo();
      _deviceId = deviceInfo['deviceId'] ?? 'unknown';
      _platform = deviceInfo['platform'] ?? 'unknown';
    } catch (e) {
      _deviceId = 'unknown';
      _platform = 'unknown';
    }
  }

  static Future<Map<String, String>> _getDeviceInfo() async {
    // This would typically use device_info_plus package
    // For now, returning mock data
    return {'deviceId': 'mock_device_id', 'platform': 'flutter'};
  }

  /// Get API headers
  static Map<String, String> get apiHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': '$appName/$appVersion',
        'X-Platform': platform,
        'X-Device-ID': deviceId,
        'X-App-Version': appVersion,
      };

  /// Check if feature is enabled
  static bool isFeatureEnabled(String feature) {
    switch (feature) {
      case 'biometric_auth':
        return enableBiometricAuth;
      case 'offline_mode':
        return enableOfflineMode;
      case 'video_download':
        return enableVideoDownload;
      case 'live_streaming':
        return enableLiveStreaming;
      case 'push_notifications':
        return enablePushNotifications;
      case 'analytics':
        return enableAnalytics;
      default:
        return false;
    }
  }

  /// Get environment-specific configuration
  static T getEnvironmentConfig<T>(T development, T staging, T production) {
    switch (environment) {
      case 'development':
        return development;
      case 'staging':
        return staging;
      case 'production':
        return production;
      default:
        return development;
    }
  }
}
