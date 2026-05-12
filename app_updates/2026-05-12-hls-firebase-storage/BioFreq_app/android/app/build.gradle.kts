plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Sin el 'version' y sin el 'apply false'
}

android {
    // Recovered from the salvaged APK manifest.
    namespace = "com.biofreq.oficial"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ⚠️  coreLibraryDesugaringEnabled: NUNCA eliminar.
        //     flutter_local_notifications lo requiere para Android < 26.
        //     Sin esto el build falla con "requires core library desugaring".
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.biofreq.oficial"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Mantener 21 ampl\u00eda soporte para Android 5+ sin tocar la l\u00f3gica principal.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // ⚠️  multiDexEnabled: requerido cuando hay más de 64k métodos (apps grandes)
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ⚠️  desugar_jdk_libs: NUNCA eliminar.
    //     Es la herramienta que permite usar APIs modernas de Java en Android antiguo.
    //     Requerido por flutter_local_notifications (notificaciones push en foreground).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
