plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.reciept_logging"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion


    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.reciept_logging"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

tasks.register("adbReverse") {
    description = "Automatically reverses backend ports 8085 and 8000 via ADB to connected devices"
    doLast {
        try {
            val adb = android.adbExecutable.absolutePath
            exec {
                commandLine(adb, "reverse", "tcp:8085", "tcp:8085")
                isIgnoreExitValue = true
            }
            exec {
                commandLine(adb, "reverse", "tcp:8000", "tcp:8000")
                isIgnoreExitValue = true
            }
        } catch (_: Exception) {
            // Gracefully ignore if ADB is unavailable or offline
        }
    }
}

afterEvaluate {
    tasks.findByName("assembleDebug")?.dependsOn("adbReverse")
    tasks.findByName("installDebug")?.dependsOn("adbReverse")
}

