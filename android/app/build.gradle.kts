import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val debugSigningProperties = Properties()
val debugSigningFile = rootProject.file("debug-signing.properties")
val hasTeamDebugSigning = debugSigningFile.exists()
if (hasTeamDebugSigning) {
    debugSigningProperties.load(FileInputStream(debugSigningFile))
}

val releaseSigningProperties = Properties()
val releaseSigningFile = rootProject.file("key.properties")
if (releaseSigningFile.exists()) {
    releaseSigningProperties.load(FileInputStream(releaseSigningFile))
}

val releaseStoreFilePath = releaseSigningProperties.getProperty("storeFile")
    ?.trim()
    ?.takeIf(String::isNotEmpty)
val releaseStoreFile = releaseStoreFilePath?.let(rootProject::file)
val hasReleaseSigning =
    releaseStoreFile != null &&
        releaseStoreFile.exists() &&
        !releaseSigningProperties.getProperty("storePassword").isNullOrBlank() &&
        !releaseSigningProperties.getProperty("keyPassword").isNullOrBlank() &&
        !releaseSigningProperties.getProperty("keyAlias").isNullOrBlank()
val buildingRelease = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (buildingRelease && !hasReleaseSigning) {
    throw GradleException(
            "Missing Android release signing config. " +
            "Copy android/key.properties.example to android/key.properties " +
            "and place android/keystore/upload-keystore.jks locally.",
    )
}

android {
    namespace = "com.xdutreehole.xdu_treehole_web"
    compileSdk = 36

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.xdutreehole.xdu_treehole_web"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasTeamDebugSigning) {
            create("teamDebug") {
                keyAlias = debugSigningProperties["keyAlias"] as String
                keyPassword = debugSigningProperties["keyPassword"] as String
                storeFile = rootProject.file(debugSigningProperties["storeFile"] as String)
                storePassword = debugSigningProperties["storePassword"] as String
            }
        }
        create("release") {
            if (hasReleaseSigning) {
                storeFile = releaseStoreFile
                storePassword = releaseSigningProperties.getProperty("storePassword")
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            if (hasTeamDebugSigning) {
                signingConfig = signingConfigs.getByName("teamDebug")
            }
        }
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
