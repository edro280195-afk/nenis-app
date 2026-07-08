import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

fun signingValue(propertyName: String, environmentName: String): String? {
    return keystoreProperties.getProperty(propertyName)
        ?.takeIf(String::isNotBlank)
        ?: System.getenv(environmentName)?.takeIf(String::isNotBlank)
}

val releaseStoreFile = signingValue("storeFile", "NENIS_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "NENIS_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "NENIS_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "NENIS_KEY_PASSWORD")
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    FileInputStream(localPropertiesFile).use(localProperties::load)
}

fun localValue(environmentName: String, vararg propertyNames: String): String {
    return propertyNames.firstNotNullOfOrNull { propertyName ->
        localProperties.getProperty(propertyName)?.takeIf(String::isNotBlank)
    }
        ?.takeIf(String::isNotBlank)
        ?: System.getenv(environmentName)?.takeIf(String::isNotBlank)
        ?: ""
}

val googleMapsApiKey = localValue(
    "GOOGLE_MAPS_API_KEY",
    "googleMapsApiKey",
    "MAPS_API_KEY",
)
val hasReleaseSigning = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }
val isReleaseTask = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (isReleaseTask && !hasReleaseSigning) {
    throw GradleException(
        "Falta la firma de release. Configura android/key.properties " +
            "o las variables NENIS_KEYSTORE_* antes de generar una versión publicable.",
    )
}

android {
    namespace = "com.nenisapp.nenis_app"
    // compileSdk 36: requerido por plugins recientes (app_links,
    // flutter_facebook_auth, flutter_secure_storage, google_maps_flutter_android,
    // shared_preferences_android, sqflite_android, url_launcher_android).
    // No sube targetSdk (comportamiento runtime) ni minSdk (dispositivos).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requerido por flutter_local_notifications (notificaciones push en
        // foreground).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Identificador definitivo de Android. También está registrado en Facebook Login.
        applicationId = "com.nenisapp.nenis_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
