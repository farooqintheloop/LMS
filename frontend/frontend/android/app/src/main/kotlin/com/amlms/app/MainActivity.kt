package com.amlms.app

import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val SCREEN_SECURITY_ENABLED = false
    private val CHANNEL = "com.lms.app/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecureMode" -> {
                    enableSecureMode()
                    result.success(true)
                }
                "isEmulator" -> {
                    result.success(isEmulator())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Enable secure mode on app start (controlled by flag)
        enableSecureMode()
    }

    private fun enableSecureMode() {
        if (!SCREEN_SECURITY_ENABLED) {
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE
            )
        }
    }

    private fun isEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")
                || "google_sdk" == Build.PRODUCT
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu")
                || Build.FINGERPRINT.contains("test-keys")
                || checkFiles()
                || checkProps())
    }

    private fun checkFiles(): Boolean {
        val emulatorFiles = arrayOf(
            "/system/lib/libc_malloc_debug_qemu.so",
            "/sys/qemu_trace",
            "/system/bin/qemu-props"
        )
        for (file in emulatorFiles) {
            if (File(file).exists()) {
                return true
            }
        }
        return false
    }

    private fun checkProps(): Boolean {
        val props = mapOf(
            "ro.kernel.qemu" to "1",
            "ro.hardware" to "goldfish",
            "ro.hardware" to "ranchu"
        )
        for ((key, value) in props) {
            try {
                val process = Runtime.getRuntime().exec("getprop $key")
                val reader = process.inputStream.bufferedReader()
                val line = reader.readLine()
                if (line == value) {
                    return true
                }
            } catch (e: Exception) {
                // Ignore
            }
        }
        return false
    }
}
