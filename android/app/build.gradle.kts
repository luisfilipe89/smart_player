plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.example.sportappdenbosch"
    // Use compileSdk 36 as required by plugins (plugins require SDK 36)
    compileSdk = 36
    // Use highest NDK version required by plugins (backward compatible)
    // integration_test requires 28.2.13676358, which is backward compatible with all other plugins
    ndkVersion = "28.2.13676358"

    compileOptions {
        // Use Java 17 to eliminate Java 8 toolchain warnings
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
    // NDK version will be automatically managed by Flutter
    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.sportappdenbosch"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        // Use Flutter-managed targetSdk for consistency with Flutter tooling
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        debug {
            // Disable native symbol stripping in debug to avoid strip task failures
            ndk.debugSymbolLevel = "none"
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    // Use legacy JNI packaging to stabilize native libs handling on some environments
    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    // Suppress deprecation warnings from dependencies
    lint {
        checkReleaseBuilds = false
        checkDependencies = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Import the Firebase BoM - requested when creating a new project in Firebase 
    implementation(platform("com.google.firebase:firebase-bom:34.3.0"))
    implementation("androidx.multidex:multidex:2.0.1")
}
