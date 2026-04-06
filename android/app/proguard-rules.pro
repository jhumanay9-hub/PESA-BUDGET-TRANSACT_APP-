# ============================================================================
# PROGUARD RULES FOR PESA BUDGET
# ============================================================================
# This file prevents crashes on older Android devices (especially Huawei)
# by ignoring missing androidx.window.sidecar classes.
# ============================================================================

# -----------------------------------------------------------------------------
# FIX: Ignore androidx.window.sidecar (Folding Phone Libraries)
# -----------------------------------------------------------------------------
# These classes don't exist on Android 9 and older devices.
# Without these rules, the app crashes with NoClassDefFoundError.
# -----------------------------------------------------------------------------

# Keep androidx.window classes but don't fail if missing
-keep class androidx.window.** { *; }
-dontwarn androidx.window.**
-keep class androidx.window.layout.adapter.sidecar.** { *; }
-dontwarn androidx.window.layout.adapter.sidecar.**
-keep class androidx.window.sidecar.** { *; }
-dontwarn androidx.window.sidecar.**

# Ignore missing SidecarInterface
-dontwarn androidx.window.sidecar.SidecarInterface
-dontwarn androidx.window.sidecar.SidecarInterface$SidecarCallback

# Ignore missing DistinctElementSidecarCallback
-dontwarn androidx.window.layout.adapter.sidecar.DistinctElementSidecarCallback
-dontwarn androidx.window.layout.adapter.sidecar.ExtensionInterfaceCompat

# -----------------------------------------------------------------------------
# FLUTTER ESSENTIALS
# -----------------------------------------------------------------------------
# Keep Flutter classes required for the app to run
# -----------------------------------------------------------------------------

-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.app.** { *; }

# Keep FlutterView and related classes
-keep class io.flutter.embedding.android.FlutterView { *; }
-keep class io.flutter.embedding.android.FlutterActivity { *; }
-keep class io.flutter.embedding.android.FlutterFragmentActivity { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# -----------------------------------------------------------------------------
# DART GENERATED CODE
# -----------------------------------------------------------------------------
# Keep Dart generated code and entry points
# -----------------------------------------------------------------------------

-keep class com.transactionapp.transaction_app.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# -----------------------------------------------------------------------------
# KOTLIN STANDARD LIBRARY
# -----------------------------------------------------------------------------
# Keep Kotlin metadata and coroutines
# -----------------------------------------------------------------------------

-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineScope {}
-keepnames class kotlinx.coroutines.internal.ThreadContextElement {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# -----------------------------------------------------------------------------
# SQLITE / ROOM
# -----------------------------------------------------------------------------
# Keep database classes
# -----------------------------------------------------------------------------

-keep class * extends android.database.sqlite.SQLiteOpenHelper { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Entity class *
-keepclassmembers class * {
    @androidx.room.* <fields>;
}

# -----------------------------------------------------------------------------
# PERMISSION HANDLER
# -----------------------------------------------------------------------------
# Keep permission handler classes
# -----------------------------------------------------------------------------

-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# -----------------------------------------------------------------------------
# FLUTTER FOREGROUND TASK
# -----------------------------------------------------------------------------
# Keep foreground service classes
# -----------------------------------------------------------------------------

-keep class com.pravera.flutter_foreground_task.** { *; }
-dontwarn com.pravera.flutter_foreground_task.**

# -----------------------------------------------------------------------------
# DEVICE INFO PLUS
# -----------------------------------------------------------------------------
-keep class com.fluttercommunity.plus.device_info.** { *; }
-dontwarn com.fluttercommunity.plus.device_info.**

# -----------------------------------------------------------------------------
# TELEPHONY (SMS)
# -----------------------------------------------------------------------------
-keep class com.juliushuijjer.telephony.** { *; }
-dontwarn com.juliushuijjer.telephony.**

# -----------------------------------------------------------------------------
# SUPABASE / GOTRUE
# -----------------------------------------------------------------------------
-keep class io.supabase.** { *; }
-keep class io.ktor.** { *; }
-dontwarn io.supabase.**
-dontwarn io.ktor.**

# -----------------------------------------------------------------------------
# OPTIMIZATION FLAGS
# -----------------------------------------------------------------------------
# Enable optimization and set shrink settings
# -----------------------------------------------------------------------------

-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify

# Keep line numbers for debugging
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*

# Keep generic signatures
-keepattributes Signature

# -----------------------------------------------------------------------------
# VERBOSE LOGGING (Uncomment for debugging)
# -----------------------------------------------------------------------------
# -verbose
# -printmapping proguard_mapping.txt
# -printseeds proguard_seeds.txt
# -printusage proguard_usage.txt
