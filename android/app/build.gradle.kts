plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.transactionapp.transaction_app"

    // Updated to 36 to satisfy the latest requirements of your added plugins
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Unique Application ID for your Mint Transaction Tracker
        applicationId = "com.transactionapp.transaction_app"

        // minSdk 21 is standard, 24 is recommended for modern background tasks
        minSdk = 24

        // targetSdk 36 ensures full compatibility with 2026 Android standards
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the debug keys so `flutter run --release` works during dev.
            signingConfig = signingConfigs.getByName("debug")

            // Enable ProGuard for smaller, optimized APK
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // Disable minification for faster debug builds
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // NOTE: Removed androidx.window dependencies - they cause Sidecar ClassNotFoundException
    // on Android < 31 devices (Huawei Y5) and trigger massive frame skips.
    // Window layout APIs are only needed for foldable devices (Android 12L+).
}

flutter {
    source = "../.."
}
