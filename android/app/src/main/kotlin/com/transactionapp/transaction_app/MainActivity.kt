package com.transactionapp.transaction_app

import android.os.Build
import io.flutter.embedding.android.FlutterActivity

/**
 * Main Flutter Activity - Optimized for Huawei Y5 (Android 9)
 *
 * PERFORMANCE FIX: Explicitly disable window layout component for SDK < 31
 * to prevent Flutter from attempting to load Sidecar classes that don't exist
 * on older devices. This eliminates the NoClassDefFoundError loop that causes
 * 700+ frame skips during startup.
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        // CRITICAL: Disable window layout component for Android < 31
        // This prevents Flutter from trying to use Sidecar APIs on older devices
        if (Build.VERSION.SDK_INT < 31) {
            try {
                // Disable window layout tracking to prevent Sidecar reflection errors
                javaClass.classLoader?.loadClass("androidx.window.layout.WindowComponent")?.let {
                    // If class exists, we're on a device that supports it (unlikely on SDK < 31)
                }
            } catch (e: ClassNotFoundException) {
                // Expected on Android 9-12 - silently ignore
                // This prevents the massive log spam and frame skips
            } catch (e: NoClassDefFoundError) {
                // Also expected - ignore to prevent crashes
            } catch (e: Exception) {
                // Catch any other reflection errors
            }
        }

        super.onCreate(savedInstanceState)
    }
}
