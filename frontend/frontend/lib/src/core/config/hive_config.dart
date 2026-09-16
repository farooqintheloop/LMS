import 'package:hive_flutter/hive_flutter.dart';
import 'app_config.dart';

class HiveConfig {
  HiveConfig._();

  /// Initialize Hive database
  static Future<void> init() async {
    // Register adapters here if needed
    // Example: Hive.registerAdapter(UserAdapter());

    // Open boxes
    await _openBoxes();
  }

  /// Open all required Hive boxes
  static Future<void> _openBoxes() async {
    try {
      await Hive.openBox(AppConfig.authBoxName);
      await Hive.openBox(AppConfig.cacheBoxName);
      await Hive.openBox(AppConfig.settingsBoxName);
      await Hive.openBox(AppConfig.downloadBoxName);
      await Hive.openBox(AppConfig.progressBoxName);
    } catch (e) {
      throw Exception('Failed to open Hive boxes: $e');
    }
  }

  /// Get a specific box
  static Box getBox(String boxName) {
    return Hive.box(boxName);
  }

  /// Close all boxes
  static Future<void> closeAll() async {
    await Hive.close();
  }
}
