import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

var dartEnvironmentVariables = mutableMapOf("publish" to false)

if (project.hasProperty("dart-defines")) {
    dartEnvironmentVariables.putAll(
            (project.property("dart-defines") as String).split(',').associate { entry ->
                val pair = String(Base64.getDecoder().decode(entry)).split('=')
                pair.first() to (pair.last() == "true")
            }
    )
}

android {
    namespace = "com.nebula.clashmi"
    compileSdkVersion = "android-35"
    buildToolsVersion = "35.0.0"
    ndkVersion = "27.0.12077973" // flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }

    defaultConfig {
        applicationId = "com.nebula.clashmi"
        minSdk = 22
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        val keystore = rootProject.file("./key.properties")
        val prop = Properties().apply { keystore.inputStream().use(this::load) }
        named("debug") { ndk { abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64", "x86") } }
        named("profile") {
            signingConfig =
                    signingConfigs.create("profile") {
                        storeFile = rootProject.file(prop.getProperty("storeFile.release"))
                        storePassword = prop.getProperty("storePassword.release")
                        keyAlias = prop.getProperty("keyAlias.release")
                        keyPassword = prop.getProperty("keyPassword.release")
                    }
            ndk { abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64", "x86") }
        }
        named("release") {
            signingConfig =
                    signingConfigs.create("release") {
                        storeFile = rootProject.file(prop.getProperty("storeFile.release"))
                        storePassword = prop.getProperty("storePassword.release")
                        keyAlias = prop.getProperty("keyAlias.release")
                        keyPassword = prop.getProperty("keyPassword.release")
                    }
            ndk {
                abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
                // debugSymbolLevel = 'FULL'
            }
        }
    }
    splits {
        abi {
            isEnable = true
            isUniversalApk = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }
}

flutter { source = "../.." }

dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3") }
