plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // Flutter Gradle Plugin must be after Android & Kotlin
    id("com.google.gms.google-services") // Google Services for Firebase
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
        versionCode = 1 // Replace `flutter.versionCode` with a manual value
        versionName = "1.0" // Replace `flutter.versionName` with a manual value
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
