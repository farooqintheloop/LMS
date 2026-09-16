import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primaryLight = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryDarker = Color(0xFF0D47A1);

  // Secondary Colors
  static const Color secondary = Color(0xFF9C27B0);
  static const Color secondaryLight = Color(0xFFBA68C8);
  static const Color secondaryDark = Color(0xFF7B1FA2);

  // Background Colors
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundMedium = Color(0xFFE9ECEF);
  static const Color backgroundDark = Color(0xFF212529);

  // Text Colors
  static const Color textDark = Color(0xFF212529);
  static const Color textMedium = Color(0xFF6C757D);
  static const Color textLight = Color(0xFFADB5BD);

  // Status Colors
  static const Color success = Color(0xFF28A745);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFDC3545);
  static const Color info = Color(0xFF17A2B8);
  static const Color live = Color(0xFFFF5722);

  // Shadow Colors
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowMedium = Color(0x33000000);
  static const Color shadowDark = Color(0x4D000000);

  // Utility Colors
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color transparent = Colors.transparent;

  // Category Colors (for course categories)
  static Color getCategoryColor(int index) {
    final colors = [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFFF44336), // Red
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF795548), // Brown
      const Color(0xFF607D8B), // Blue Grey
    ];
    return colors[index % colors.length];
  }

  // Difficulty Colors
  static Color getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return const Color(0xFF4CAF50); // Green
      case 'intermediate':
        return const Color(0xFFFF9800); // Orange
      case 'advanced':
        return const Color(0xFFF44336); // Red
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  // Rating Colors
  static Color getRatingColor(double rating) {
    if (rating >= 4.5) return const Color(0xFF4CAF50); // Green
    if (rating >= 4.0) return const Color(0xFF8BC34A); // Light Green
    if (rating >= 3.5) return const Color(0xFFFFEB3B); // Yellow
    if (rating >= 3.0) return const Color(0xFFFF9800); // Orange
    return const Color(0xFFF44336); // Red
  }

  // Progress Colors
  static Color getProgressColor(double progress) {
    if (progress >= 0.8) return const Color(0xFF4CAF50); // Green
    if (progress >= 0.6) return const Color(0xFF8BC34A); // Light Green
    if (progress >= 0.4) return const Color(0xFFFFEB3B); // Yellow
    if (progress >= 0.2) return const Color(0xFFFF9800); // Orange
    return const Color(0xFFF44336); // Red
  }

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primaryDark],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryDark],
  );

  // App Background Gradients
  static const LinearGradient appBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF8F9FA),
      Color(0xFFE3F2FD),
      Color(0xFFE1F5FE),
    ],
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1A1A1A),
      Color(0xFF212529),
      Color(0xFF343A40),
    ],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF8F9FA),
    ],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryDark,
      primaryLight,
      secondary,
    ],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, Color(0xFF1E7E34)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warning, Color(0xFFE0A800)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [error, Color(0xFFC82333)],
  );

  // Material Color Swatches
  static const MaterialColor primarySwatch = MaterialColor(
    0xFF2196F3,
    <int, Color>{
      50: Color(0xFFE3F2FD),
      100: Color(0xFFBBDEFB),
      200: Color(0xFF90CAF9),
      300: Color(0xFF64B5F6),
      400: Color(0xFF42A5F5),
      500: Color(0xFF2196F3), // primary
      600: Color(0xFF1E88E5),
      700: Color(0xFF1976D2),
      800: Color(0xFF1565C0),
      900: Color(0xFF0D47A1),
    },
  );

  static const MaterialColor secondarySwatch = MaterialColor(
    0xFF9C27B0,
    <int, Color>{
      50: Color(0xFFF3E5F5),
      100: Color(0xFFE1BEE7),
      200: Color(0xFFCE93D8),
      300: Color(0xFFBA68C8),
      400: Color(0xFFAB47BC),
      500: Color(0xFF9C27B0), // secondary
      600: Color(0xFF8E24AA),
      700: Color(0xFF7B1FA2),
      800: Color(0xFF6A1B9A),
      900: Color(0xFF4A148C),
    },
  );
}
