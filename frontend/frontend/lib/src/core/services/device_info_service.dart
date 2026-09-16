import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Service to get device information for device tracking
class DeviceInfoService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Get comprehensive device information
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final info = await _getAndroidDeviceInfo();
        info['device_type'] = 'mobile'; // Android is always mobile
        return info;
      } else if (Platform.isIOS) {
        final info = await _getIOSDeviceInfo();
        info['device_type'] = 'mobile'; // iOS is always mobile
        return info;
      } else {
        final info = _getDefaultDeviceInfo();
        // Desktop platforms (Windows, Linux, macOS)
        info['device_type'] = 'desktop';
        return info;
      }
    } catch (e) {
      final info = _getDefaultDeviceInfo();
      info['device_type'] = 'unknown';
      return info;
    }
  }

  /// Get Android device information
  static Future<Map<String, dynamic>> _getAndroidDeviceInfo() async {
    final androidInfo = await _deviceInfo.androidInfo;
    final packageInfo = await PackageInfo.fromPlatform();

    return {
      'device_id': androidInfo.id, // Android ID (unique per device)
      'device_name': androidInfo.device,
      'device_model': androidInfo.model,
      'manufacturer': androidInfo.manufacturer,
      'brand': androidInfo.brand,
      'product': androidInfo.product,
      'hardware': androidInfo.hardware,
      'android_version': androidInfo.version.release,
      'sdk_version': androidInfo.version.sdkInt.toString(),
      'platform': 'android',
      'app_version': packageInfo.version,
      'app_build': packageInfo.buildNumber,
      'fingerprint': androidInfo.fingerprint,
    };
  }

  /// Get iOS device information
  static Future<Map<String, dynamic>> _getIOSDeviceInfo() async {
    final iosInfo = await _deviceInfo.iosInfo;
    final packageInfo = await PackageInfo.fromPlatform();

    return {
      'device_id': iosInfo.identifierForVendor ?? 'unknown',
      'device_name': iosInfo.name,
      'device_model': iosInfo.model,
      'system_name': iosInfo.systemName,
      'system_version': iosInfo.systemVersion,
      'platform': 'ios',
      'app_version': packageInfo.version,
      'app_build': packageInfo.buildNumber,
      'is_physical_device': iosInfo.isPhysicalDevice,
    };
  }

  /// Get default device info (fallback)
  static Map<String, dynamic> _getDefaultDeviceInfo() {
    return {
      'device_id': 'unknown',
      'device_name': 'Unknown Device',
      'platform': Platform.operatingSystem,
    };
  }

  /// Generate a unique device fingerprint
  static Future<String> getDeviceFingerprint() async {
    final deviceInfo = await getDeviceInfo();
    
    // Create a unique fingerprint from device characteristics
    final parts = [
      deviceInfo['device_id'] ?? 'unknown',
      deviceInfo['device_model'] ?? 'unknown',
      deviceInfo['manufacturer'] ?? deviceInfo['system_name'] ?? 'unknown',
      deviceInfo['platform'] ?? 'unknown',
    ];
    
    return parts.join('|');
  }
}
