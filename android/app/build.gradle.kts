import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePropertiesFile = rootProject.file("key.properties")
val releaseKeystoreProperties = Properties()
if (releaseKeystorePropertiesFile.exists()) {
    releaseKeystorePropertiesFile.inputStream().use(releaseKeystoreProperties::load)
}
val hasReleaseSigning = releaseKeystorePropertiesFile.exists() &&
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .all(releaseKeystoreProperties::containsKey)

android {
    namespace = "com.umkmku.umkm_manager"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.umkmku.umkm_manager"
        // image_picker 1.2.x membutuhkan Android API 24 atau lebih baru.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = releaseKeystoreProperties.getProperty("keyAlias")
                keyPassword = releaseKeystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(releaseKeystoreProperties.getProperty("storeFile"))
                storePassword = releaseKeystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Never fall back to the debug key. A missing real keystore keeps
            // release artifacts unsigned and is rejected by the verification task.
            signingConfig = if (hasReleaseSigning) signingConfigs.getByName("release") else null
            // Release-only shrinking: Flutter/Android dependency consumer rules
            // are retained, while unused Android bytecode and resources are removed.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

tasks.register("verifyReleaseSigning") {
    group = "verification"
    description = "Fails release packaging when android/key.properties is absent."
    doLast {
        check(hasReleaseSigning) {
            "Release signing is not configured. Create android/key.properties locally; never commit it or the keystore."
        }
    }
}

tasks.configureEach {
    // Flutter creates Play Store bundles with bundleRelease, not packageRelease.
    // Guard every common release artifact so an unsigned build can never be
    // mistaken for a publishable one.
    if (
        (name.startsWith("package") ||
            name.startsWith("bundle") ||
            name.startsWith("assemble")) && name.endsWith("Release")
    ) {
        dependsOn("verifyReleaseSigning")
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
