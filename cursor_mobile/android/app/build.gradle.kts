import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = file("${project.projectDir.parent}/key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// When keystore password is wrong, add useDebugSigningForRelease=true to android/local.properties
// to build release APK with debug signing (local testing only; CI uses secrets).
val localPropertiesFile = file("${project.projectDir.parent}/local.properties")
val localProperties = Properties()
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}
val useDebugSigningForRelease = localProperties.getProperty("useDebugSigningForRelease", "false") == "true"

// CI / distribution: pass -PrequireReleaseSigning=true so release builds refuse debug signing.
// Mixing debug-signed and upload-key-signed APKs forces "uninstall old app first" on Android.
val requireReleaseSigning =
    (project.findProperty("requireReleaseSigning")?.toString() ?: "").equals("true", ignoreCase = true)
val hasGoogleServicesJson = file("${project.projectDir}/google-services.json").exists()

android {
    namespace = "com.mordechaius.maximus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (and other deps) for Java 8+ APIs on older minSdk.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"].toString()
                keyPassword = keystoreProperties["keyPassword"].toString()
                storeFile = file("${project.projectDir.parent}/${keystoreProperties["storeFile"]}")
                storePassword = keystoreProperties["storePassword"].toString()
            }
        }
    }

    defaultConfig {
        applicationId = "com.mordechaius.maximus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase Messaging requires minSdk 21+. Override if Flutter default is lower.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            val useUploadKey = !useDebugSigningForRelease && keystorePropertiesFile.exists()
            if (requireReleaseSigning && !useUploadKey) {
                throw org.gradle.api.GradleException(
                    "Release build requires the upload keystore (-PrequireReleaseSigning=true) but key.properties / keystore is missing. " +
                        "Android upgrades only work in place when every release uses the same signing key. " +
                        "Configure android/key.properties locally, or ANDROID_KEYSTORE_* secrets in GitHub Actions. " +
                        "Local-only: set useDebugSigningForRelease=true in android/local.properties (not for phone installs you plan to upgrade)."
                )
            }
            signingConfig = if (useUploadKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

if (!hasGoogleServicesJson) {
    logger.warn("google-services.json not found. Disabling Google Services Gradle tasks for this local build.")
    tasks.matching { it.name.contains("GoogleServices", ignoreCase = true) }.configureEach {
        enabled = false
    }
}
