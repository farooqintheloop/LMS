import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Toggle to enable/disable screen security (screenshots + screen recording)
const bool kScreenSecurityEnabled = false;

/// Widget that prevents screenshots and screen recording across the entire app
class SecureScreenWrapper extends StatefulWidget {
  final Widget child;

  const SecureScreenWrapper({
    super.key,
    required this.child,
  });

  @override
  State<SecureScreenWrapper> createState() => _SecureScreenWrapperState();
}

class _SecureScreenWrapperState extends State<SecureScreenWrapper>
    with WidgetsBindingObserver {
  bool _isScreenRecording = false;
  Timer? _recordingCheckTimer;

  @override
  void initState() {
    super.initState();
    if (kScreenSecurityEnabled) {
      WidgetsBinding.instance.addObserver(this);
      _enableSecureMode();
      _startRecordingCheck();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingCheckTimer?.cancel();
    super.dispose();
  }

  /// Enable secure mode to prevent screenshots (Android)
  Future<void> _enableSecureMode() async {
    if (!kScreenSecurityEnabled) return;

    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('com.lms.app/security');
        await platform.invokeMethod('enableSecureMode');
      } on MissingPluginException {
        // Platform channel not set up yet - will be handled by native code
        debugPrint('Secure mode platform channel not available');
      } catch (e) {
        debugPrint('Failed to enable secure mode: $e');
      }
    }
  }

  /// Start periodic check for screen recording (iOS)
  void _startRecordingCheck() {
    if (!kScreenSecurityEnabled) return;

    if (Platform.isIOS) {
      _recordingCheckTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _checkScreenRecording(),
      );
    }
  }

  /// Check if screen is being recorded (iOS)
  /// Note: iOS native code setup is optional. If not configured, this will gracefully fail.
  Future<void> _checkScreenRecording() async {
    if (!kScreenSecurityEnabled) return;

    if (!Platform.isIOS) return;

    try {
      // Use platform channel to check screen recording status
      const platform = MethodChannel('com.lms.app/security');
      final dynamic result = await platform.invokeMethod('isScreenRecording');
      final bool isRecording = result == true;

      if (isRecording != _isScreenRecording) {
        if (mounted) {
          setState(() {
            _isScreenRecording = isRecording;
          });

          if (isRecording) {
            _showRecordingWarning();
          }
        }
      }
    } on MissingPluginException {
      // Platform channel not set up - this is OK, iOS screenshot prevention is limited anyway
      // Stop checking to avoid unnecessary errors
      _recordingCheckTimer?.cancel();
      _recordingCheckTimer = null;
    } catch (e) {
      // Other errors - log but don't break the app
      debugPrint('Screen recording check failed: $e');
    }
  }

  /// Show warning when screen recording is detected
  void _showRecordingWarning() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Screen Recording Detected'),
          ],
        ),
        content: const Text(
          'Screen recording is not allowed in this application. '
          'Please stop recording to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Re-enable secure mode when app comes to foreground
    if (kScreenSecurityEnabled && state == AppLifecycleState.resumed) {
      _enableSecureMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Show overlay if screen recording is detected (iOS)
        if (kScreenSecurityEnabled && _isScreenRecording && Platform.isIOS)
          Container(
            color: Colors.black,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.block,
                    size: 64,
                    color: Colors.red,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Screen Recording Not Allowed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please stop recording to continue',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
