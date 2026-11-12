import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// -----------------------------------------------------------------------------
// Keystore Credentials Resolution (TODO-35)
// Resolves credentials from local untracked key.properties or CI/CD environment variables
// -----------------------------------------------------------------------------
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { stream ->
        keystoreProperties.load(stream)
    }
}

/**
 * Resolves a signing property by checking key.properties first, then Gradle
 * configuration-cache compatible environment variables, then System.getenv.
 */
fun getSigningProperty(propKey: String, envVar: String): String? {
    return keystoreProperties.getProperty(propKey)?.takeIf { it.isNotBlank() }
        ?: providers.environmentVariable(envVar).orNull?.takeIf { it.isNotBlank() }
        ?: System.getenv(envVar)?.takeIf { it.isNotBlank() }
}

android {
    namespace = "com.example.reciept_logging"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion


    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "org.effoc.sancfund"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("staging") {
            val stagingKeystore = file("staging.keystore")
            if (stagingKeystore.exists()) {
                storeFile = stagingKeystore
                storePassword = "sancfundstaging"
                keyAlias = "staging"
                keyPassword = "sancfundstaging"
            } else {
                initWith(getByName("debug"))
            }
        }

        create("release") {
            val storeFilePath = getSigningProperty("storeFile", "ANDROID_STORE_FILE")
            val storePass = getSigningProperty("storePassword", "ANDROID_STORE_PASSWORD")
            val keyAl = getSigningProperty("keyAlias", "ANDROID_KEY_ALIAS")
            val keyPass = getSigningProperty("keyPassword", "ANDROID_KEY_PASSWORD")

            if (!storeFilePath.isNullOrBlank() && !storePass.isNullOrBlank() &&
                !keyAl.isNullOrBlank() && !keyPass.isNullOrBlank()) {

                val rawFile = File(storeFilePath)
                val resolvedFile = when {
                    rawFile.isAbsolute -> rawFile
                    file(storeFilePath).exists() -> file(storeFilePath)
                    rootProject.file(storeFilePath).exists() -> rootProject.file(storeFilePath)
                    else -> file(storeFilePath)
                }

                if (resolvedFile.exists()) {
                    storeFile = resolvedFile
                    storePassword = storePass
                    keyAlias = keyAl
                    keyPassword = keyPass
                } else {
                    logger.warn("[TODO-35] Release keystore file configured but not found at: ${resolvedFile.absolutePath}")
                }
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("staging")
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            val releaseSigning = signingConfigs.getByName("release")
            if (releaseSigning.storeFile != null && releaseSigning.storeFile!!.exists()) {
                signingConfig = releaseSigning
            } else {
                logger.warn("[TODO-35] Release signing credentials not detected. Release builds will fail signing validation unless provided via key.properties or CI environment variables.")
                signingConfig = releaseSigning
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

