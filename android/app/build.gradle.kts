import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is read from `android/key.properties` when that file exists.
// The file is intentionally kept out of version control; see key.properties.example.
// The parser tolerates a UTF-8 byte order mark, because editors on Windows
// add one when the file is saved.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    val raw = FileInputStream(keystorePropertiesFile).use { stream ->
        stream.readBytes().toString(Charsets.UTF_8)
    }
    keystoreProperties.load(
        raw.removePrefix("\uFEFF").reader(),
    )
}
val hasReleaseKeystore = keystoreProperties.containsKey("storeFile")

android {
    namespace = "ir.logiclab.logic_lab"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "ir.logiclab.logic_lab"
        // Iranian app stores require a stable application id. Change it only
        // before the first published release.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resourceConfigurations += listOf("fa", "en")
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storePassword = keystoreProperties.getProperty("storePassword")
                // The path may point at the app module or at the android root
                // (the CI restores the keystore next to key.properties).
                val storePath = keystoreProperties.getProperty("storeFile")
                storeFile = file(storePath).takeIf { it.exists() }
                    ?: rootProject.file(storePath)
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Falls back to the debug key so that `flutter build apk
                // --release` still works in development. Configure
                // android/key.properties before publishing to a store.
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }

    packaging {
        resources {
            excludes += setOf("META-INF/*.version", "META-INF/DEPENDENCIES")
        }
    }
}

flutter {
    source = "../.."
}
