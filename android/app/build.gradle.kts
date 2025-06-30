// Add these imports at the top of your file
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.complaints.app"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.complaints.app"
        minSdk = 23
        targetSdk = 33
        versionCode = 1
        versionName = "1.0"
        manifestPlaceholders["MAPS_API_KEY"] = getApiKey()
    }

    buildTypes {
        release {
            isMinifyEnabled = false 
            isShrinkResources = false 
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug") 
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.7.1")) 
    implementation("com.google.firebase:firebase-auth") 
}

// Modified to use the imported classes
fun getApiKey(): String {
    val properties = Properties()
    properties.load(FileInputStream(project.rootProject.file("local.properties")))
    return properties.getProperty("MAPS_API_KEY", "")
}