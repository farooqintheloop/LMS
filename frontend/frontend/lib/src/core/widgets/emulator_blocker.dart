import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/emulator_detector.dart';
import '../theme/app_colors.dart';

/// Widget that blocks the app if running on emulator/simulator
class EmulatorBlocker extends StatefulWidget {
  final Widget child;

  const EmulatorBlocker({
    super.key,
    required this.child,
  });

  @override
  State<EmulatorBlocker> createState() => _EmulatorBlockerState();
}

class _EmulatorBlockerState extends State<EmulatorBlocker> {
  bool _isChecking = true;
  bool _isEmulator = false;

  @override
  void initState() {
    super.initState();
    _checkEmulator();
  }

  Future<void> _checkEmulator() async {
    final isEmulator = await EmulatorDetector.isEmulator();
    
    if (mounted) {
      setState(() {
        _isEmulator = isEmulator;
        _isChecking = false;
      });

      // If emulator detected, prevent further interaction
      if (_isEmulator) {
        // Exit app after showing message
        Future.delayed(const Duration(seconds: 3), () {
          SystemNavigator.pop();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      // Show loading while checking
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.primaryDark,
          body: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    if (_isEmulator) {
      // Show blocking screen
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.primaryDark,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.block,
                      size: 80,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Emulator Not Allowed',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This application cannot be run on emulators or simulators for security reasons.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please use a physical device to access this application.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'The application will close automatically...',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Not an emulator, show normal app
    return widget.child;
  }
}
