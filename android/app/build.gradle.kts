import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/// Release signing, read from `android/key.properties`.
///
/// That file and the keystore it points at are both ignored by `android/.gitignore`,
/// so the upload key never reaches version control.
///
/// There is deliberately **no fallback**. This build used to sign release with the
/// debug key "so `flutter build apk --release` works out of the box", which means
/// the artifact that would have been uploaded to Play was signed with a key that
/// is public in every Android SDK — anyone could sign an update for the same
/// package. It also produces a bundle Play rejects. A missing keystore now fails
/// the release task with instructions, and debug builds are unaffected.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseSigning) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

android {
    namespace = "com.dhimmah.dhimmah"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications, which uses java.time to work
        // out the next delivery instant on older Android versions.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.dhimmah.dhimmah"
        // 23 is the floor for the secure-storage keystore and for
        // fingerprint authentication through local_auth.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Ship only the two languages Dhimmah has, so the icons and strings the
        // system shows are never drawn from a locale we did not translate.
        resourceConfigurations += listOf("ar", "en")
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // Left unset so the release task itself stops below, rather than
                // producing an unsigned artifact that looks finished.
                null
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // Google Play's in-app updates. The per-feature artifact, not the old
    // monolithic `com.google.android.play:core`, which was split up and no
    // longer receives fixes. This is the only route allowed to update an app on
    // a modern Android device, and it needs no permission: the Play Store app
    // does the downloading and the installing, and decides for itself whether
    // the user's connection allows it.
    implementation("com.google.android.play:app-update:2.1.0")
}

flutter {
    source = "../.."
}

/// Refuses to build a release artifact without a signing key.
///
/// Scoped to the release tasks so `flutter test`, `flutter run` and debug builds
/// keep working on a machine that has no keystore — which is every machine except
/// the release engineer's.
gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any { task ->
        task.name == "bundleRelease" || task.name == "assembleRelease" ||
            task.name == "packageReleaseBundle"
    }
    if (releaseRequested && !hasReleaseSigning) {
        throw GradleException(
            "Release signing is not configured.\n" +
                "Create android/key.properties with storeFile, storePassword, " +
                "keyAlias and keyPassword, then build again. " +
                "See README.md, 'Publishing'."
        )
    }
}
