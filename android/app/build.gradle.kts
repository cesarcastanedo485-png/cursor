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
val appGoogleServicesFile = file("${project.projectDir}/google-services.json")
val configuredGoogleServicesPath = (System.getenv("GOOGLE_SERVICES_JSON_PATH") ?: "").trim()
val userProfile = (System.getenv("USERPROFILE") ?: "").trim()
val userProfileOnDriveD = if (userProfile.matches(Regex("^[A-Za-z]:.*"))) {
    "D${userProfile.substring(1)}"
} else {
    ""
}
val userProfileOnDriveE = if (userProfile.matches(Regex("^[A-Za-z]:.*"))) {
    "E${userProfile.substring(1)}"
} else {
    ""
}

val googleServicesCandidates = listOfNotNull(
    configuredGoogleServicesPath.takeIf { it.isNotBlank() },
    "$userProfile/Downloads/google-services.json".takeIf { userProfile.isNotBlank() },
    "$userProfileOnDriveD/Downloads/google-services.json".takeIf { userProfileOnDriveD.isNotBlank() },
    "$userProfileOnDriveE/Downloads/google-services.json".takeIf { userProfileOnDriveE.isNotBlank() },
)

if (!appGoogleServicesFile.exists()) {
    val source = googleServicesCandidates
        .map { file(it) }
        .firstOrNull { it.exists() }
    if (source != null) {
        source.copyTo(appGoogleServicesFile, overwrite = true)
        logger.lifecycle("Copied google-services.json from ${source.absolutePath}")
    }
}

val hasGoogleServicesJson = appGoogleServicesFile.exists()

android {
    namespace = "com.mordechaius.maximus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (and other libs) for Java 8+ APIs on older Android.
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
            signingConfig = if (!useDebugSigningForRelease && keystorePropertiesFile.exists()) {
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
    logger.warn("google-services.json not found. Set GOOGLE_SERVICES_JSON_PATH or place the file in Downloads. Disabling Google Services tasks for this local build.")
    tasks.matching { it.name.contains("GoogleServices", ignoreCase = true) }.configureEach {
        enabled = false
    }
}
