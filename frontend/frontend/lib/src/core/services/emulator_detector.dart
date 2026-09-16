import 'dart:io';
import 'package:flutter/services.dart';

/// Service to detect if the app is running on an emulator/simulator
class EmulatorDetector {
  static const MethodChannel _channel = MethodChannel('com.lms.app/security');

  /// Check if running on emulator (Android) or simulator (iOS)
  static Future<bool> isEmulator() async {
    try {
      if (Platform.isAndroid) {
        // Use native Android detection
        final bool result = await _channel.invokeMethod('isEmulator') ?? false;
        return result;
      } else if (Platform.isIOS) {
        // Try native iOS detection first
        try {
          final bool result = await _channel.invokeMethod('isEmulator') ?? false;
          return result;
        } on MissingPluginException {
          // Fallback to environment variable check
          return _isIOSSimulator();
        }
      }
      return false;
    } on MissingPluginException {
      // If platform channel not available, use fallback detection
      return _fallbackDetection();
    } catch (e) {
      // On error, assume not emulator to avoid blocking real devices
      return false;
    }
  }

  /// iOS Simulator detection
  static bool _isIOSSimulator() {
    // Check for simulator-specific environment variables
    // This is a basic check - more sophisticated detection can be added
    try {
      // On iOS simulator, certain system properties are different
      // We can check for simulator-specific identifiers
      return Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
          Platform.environment.containsKey('SIMULATOR_ROOT') ||
          Platform.environment.containsKey('SIMULATOR_UDID');
    } catch (e) {
      return false;
    }
  }

  /// Fallback detection when platform channel is not available
  static bool _fallbackDetection() {
    if (Platform.isAndroid) {
      // Basic Android emulator detection
      // This is less reliable but better than nothing
      final model = Platform.environment['ANDROID_MODEL'] ?? '';
      final manufacturer = Platform.environment['ANDROID_MANUFACTURER'] ?? '';
      
      return model.toLowerCase().contains('sdk') ||
          model.toLowerCase().contains('emulator') ||
          manufacturer.toLowerCase().contains('genymotion') ||
          model.toLowerCase().contains('google_sdk');
    }
    return false;
  }
}
