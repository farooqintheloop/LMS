import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/device_info_service.dart';

/// Authentication state
class AuthState {
  final bool isAuthenticated;
  final String? token;
  final Map<String, dynamic>? user;
  final String status;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.token,
    this.user,
    this.status = 'initial',
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? token,
    Map<String, dynamic>? user,
    String? status,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      user: user ?? this.user,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

/// Authentication provider
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  /// Register user
  Future<void> register({
    required String email,
    required String password,
    required String confirmPassword,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    state = state.copyWith(status: 'loading');

    try {
      final response = await apiService.register(
        email: email,
        password: password,
        confirmPassword: confirmPassword,
        firstName: firstName,
        lastName: lastName,
        role: role,
      );

      // Check if registration was successful
      if (response['message'] != null &&
          response['message'].toString().contains('successful')) {
        // Registration successful, now login
        await login(email, password);
      } else {
        throw Exception(
            response['message'] ?? response['error'] ?? 'Registration failed');
      }
    } catch (e) {
      state = state.copyWith(status: 'error', error: e.toString());
    }
  }

  /// Login user
  Future<void> login(String email, String password,
      {bool rememberMe = false}) async {
    state = state.copyWith(status: 'loading');

    try {
      // Get device information
      final deviceInfo = await DeviceInfoService.getDeviceInfo();

      final response = await apiService.login(
        email: email,
        password: password,
        rememberMe: rememberMe,
        deviceInfo: deviceInfo,
      );

      // Extract user data from response
      final userData = response['user'] ?? {};
      final token = response['token'] ?? '';

      state = state.copyWith(
        isAuthenticated: true,
        token: token,
        user: {
          'id': userData['id'] ?? '',
          'email': userData['email'] ?? email,
          'firstName': userData['first_name'] ?? userData['firstName'] ?? '',
          'lastName': userData['last_name'] ?? userData['lastName'] ?? '',
          'role': userData['role'] ?? 'student',
          'name':
              '${userData['first_name'] ?? userData['firstName'] ?? ''} ${userData['last_name'] ?? userData['lastName'] ?? ''}'
                  .trim(),
        },
        status: 'authenticated',
        error: null,
      );

      // Start a new learning session for this login (manual or remember-me)
      try {
        await apiService.startUserSession();
      } catch (_) {
        // Ignore session tracking errors
      }
    } catch (e) {
      // Check if it's a device limit error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('device limit') ||
          errorString.contains('maximum device') ||
          errorString.contains('device_limit_reached') ||
          errorString.contains('device_type_limit_reached') ||
          errorString.contains('cannot login on additional')) {
        // Use the error message from backend (it's more specific)
        state = state.copyWith(
          status: 'error',
          error: e.toString().replaceAll('Exception: ', ''),
        );
      } else {
        state = state.copyWith(status: 'error', error: e.toString());
      }
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      // End current learning session on logout
      try {
        await apiService.endUserSession();
      } catch (_) {
        // Ignore session tracking errors
      }

      // Get device ID for logout
      String? deviceId;
      try {
        final deviceInfo = await DeviceInfoService.getDeviceInfo();
        deviceId = deviceInfo['device_id'] as String?;
      } catch (_) {
        // Ignore device info errors
      }

      await apiService.logout(deviceId: deviceId);
    } catch (e) {
      // Continue with logout even if API call fails
    }

    // Clear all stored credentials and tokens
    await apiService.clearAllCredentials();

    state = const AuthState(status: 'unauthenticated');
  }

  /// Check authentication status
  Future<void> checkAuthStatus() async {
    try {
      final response = await apiService.getDashboard();

      if (response['user'] != null) {
        final userData = response['user'];
        state = state.copyWith(
          isAuthenticated: true,
          user: {
            'id': userData['id'] ?? '',
            'email': userData['email'] ?? '',
            'firstName': userData['first_name'] ?? userData['firstName'] ?? '',
            'lastName': userData['last_name'] ?? userData['lastName'] ?? '',
            'role': userData['role'] ?? 'student',
            'name':
                '${userData['first_name'] ?? userData['firstName'] ?? ''} ${userData['last_name'] ?? userData['lastName'] ?? ''}'
                    .trim(),
          },
          status: 'authenticated',
        );

        // Treat this as a fresh login for session tracking when token auto-validates
        try {
          await apiService.startUserSession();
        } catch (_) {
          // Ignore session tracking errors
        }
      } else {
        state = state.copyWith(status: 'unauthenticated');
      }
    } catch (e) {
      state = state.copyWith(status: 'unauthenticated');
    }
  }

  /// Check for saved credentials and auto-login
  Future<void> checkSavedCredentials() async {
    try {
      print('[AUTH] Checking saved credentials...');
      final savedCredentials = await apiService.getSavedCredentials();
      if (savedCredentials != null) {
        print('[AUTH] Found saved credentials, auto-logging in...');
        // Auto-login with saved credentials
        await login(savedCredentials['email'], savedCredentials['password'],
            rememberMe: true);
      } else {
        print('[AUTH] No saved credentials found, checking for valid token...');
        // Check if we have a valid token
        final hasToken = await apiService.hasValidToken();
        if (hasToken) {
          print('[AUTH] Valid token found, checking auth status...');
          // Try to refresh token or check auth status
          await checkAuthStatus();
        } else {
          print('[AUTH] No valid token, setting unauthenticated...');
          state = state.copyWith(status: 'unauthenticated');
        }
      }
    } catch (e) {
      print('[AUTH] Error checking saved credentials: $e');
      state = state.copyWith(status: 'unauthenticated');
    }
  }

  /// Refresh token
  Future<void> refreshToken() async {
    try {
      final response = await apiService.refreshToken();
      if (response['access'] != null || response['tokens']?['access'] != null) {
        state = state.copyWith(
            token: response['access'] ?? response['tokens']?['access']);
      }
    } catch (e) {
      // If refresh fails, logout user
      await logout();
    }
  }

  /// Check password strength
  Future<Map<String, dynamic>> checkPasswordStrength(String password) async {
    try {
      return await apiService.checkPasswordStrength(password);
    } catch (e) {
      return {
        'strength': 'weak',
        'feedback': 'Unable to check password strength',
        'is_valid': false,
        'errors': ['Unable to check password strength'],
      };
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
