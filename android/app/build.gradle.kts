import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signature de release, lue dans android/key.properties (clés storeFile,
// storePassword, keyAlias, keyPassword ; storeFile relatif à android/app).
// Ce fichier et le keystore sont exclus du dépôt par android/.gitignore : une
// clé de signature versionnée serait irrécupérable une fois publiée. Sans le
// fichier (poste de développement, intégration continue sans secret), la
// release est signée avec la clé de debug : la compilation reste vérifiable,
// l'artefact n'est simplement pas publiable.
val keyProperties = Properties().apply {
    val fichier = rootProject.file("key.properties")
    if (fichier.exists()) fichier.inputStream().use { load(it) }
}
val signatureRelease = keyProperties.getProperty("storeFile") != null

android {
    namespace = "com.uniflow.kernelforge"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Exigé par `flutter_local_notifications` : le greffon utilise les API
        // de date/heure de Java 8 (`java.time`), absentes des anciens Android.
        // Sans cette ligne, la compilation échoue sur
        // « requires core library desugaring to be enabled ».
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Doit correspondre au nom de paquet déclaré dans la plateforme
        // Flutter de la console Appwrite : c'est cette chaîne que le serveur
        // compare pour autoriser l'application.
        applicationId = "com.uniflow.kernelforge"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signatureRelease) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (signatureRelease) "release" else "debug")
            // R8 : réduction et obscurcissement du code Java/Kotlin des greffons,
            // suppression des ressources non référencées. Le code Dart est
            // compilé à part (AOT) et n'est pas concerné. Les règles propres à
            // l'application sont dans proguard-rules.pro ; les ressources
            // désignées depuis Dart, invisibles à l'analyse, sont listées dans
            // res/raw/keep.xml.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Bibliothèque de « desugaring » : fournit à Android 7 et antérieur les
    // classes `java.time` que `flutter_local_notifications` attend.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
