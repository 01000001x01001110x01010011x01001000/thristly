// File: android/app/build.gradle.kts
// Gradle Kotlin DSL for the Android app module.
// Comments added to explain common configuration points.

plugins {
    // Applies the Android application plugin (for APK/AAB builds).
    id("com.android.application")
    // Kotlin Android support.
    id("kotlin-android")
    // Flutter Gradle plugin to integrate Flutter tooling.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Application namespace (should match package name in AndroidManifest/Flutter config).
    namespace = "com.example.thristly"   // match your package

    // Use the compile SDK version provided by the Flutter tooling.
    compileSdk = flutter.compileSdkVersion
    // NDK version used for native builds; typically provided by Flutter.
    ndkVersion = flutter.ndkVersion       // OK to leave; no plugin needs a newer NDK now

    defaultConfig {
        // The application id shown on the Play Store / installed device.
        applicationId = "com.example.thristly"
        // Minimum Android SDK your app supports.
        minSdk = 23
        // Target SDK and version info provided by Flutter build configuration.
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        // Debug build: no code shrinking/obfuscation, faster builds.
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        // Release build: configure minification/shrinking/proguard here if needed.
        release {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // Java compatibility levels for compile and target (Java 17 here).
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    // Kotlin JVM target for Kotlin compilation (matches Java version above).
    kotlinOptions { jvmTarget = "17" }
}

// Flutter-specific configuration: points to the Flutter module/root of the project.
flutter {
    source = "../.."
}
