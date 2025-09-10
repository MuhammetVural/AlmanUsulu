import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = project.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val _storePath = keystoreProperties["storeFile"] as String?
val _storePass = keystoreProperties["storePassword"] as String?
val _alias     = keystoreProperties["keyAlias"] as String?
val _keyPass   = keystoreProperties["keyPassword"] as String?
require(!_storePath.isNullOrBlank()) { "key.properties: storeFile is missing/blank" }
require(!_storePass.isNullOrBlank()) { "key.properties: storePassword is missing/blank" }
require(!_alias.isNullOrBlank())     { "key.properties: keyAlias is missing/blank" }
require(!_keyPass.isNullOrBlank())   { "key.properties: keyPassword is missing/blank" }

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    signingConfigs {
        create("release") {
            val storePath = _storePath
            storeFile = file(storePath)
            storePassword = _storePass
            keyAlias = _alias
            keyPassword = _keyPass
        }
    }
    namespace = "com.vural.almanusulu"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.vural.almanusulu"
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
