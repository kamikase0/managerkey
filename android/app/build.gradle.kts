plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.manager_key"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.manager_key"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
//        manifestPlaceholders["MAPS_API_KEY"] = project.properties["MAPS_API_KEY"] ?: ""
    }

    lint {
        disable += "MissingTranslation"
        disable += "ExtraTranslation"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Importación BOM para que todas las dependencias usen versiones compatibles
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.8.0")

    // SDKs específicos de Firebase
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
}

apply(plugin = "com.google.gms.google-services")
