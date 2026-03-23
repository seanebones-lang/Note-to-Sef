import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "online.nextelevenstudios.notetoself"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "online.nextelevenstudios.notetoself"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        val keystoreProperties = Properties()
        val keystoreFile = rootProject.file("key.properties")
        if (keystoreFile.exists()) {
            keystoreProperties.load(FileInputStream(keystoreFile))
        }
        create("release") {
            fun expandStorePath(p: String): String {
                val t = p.trim()
                if (t.startsWith("~/")) return System.getProperty("user.home") + t.substring(1)
                if (t == "~") return System.getProperty("user.home")
                return t
            }
            val path = keystoreProperties.getProperty("storeFile")
                ?: System.getenv("ANDROID_KEYSTORE_PATH")
            if (path != null) {
                val expanded = expandStorePath(path)
                storeFile = rootProject.file(expanded)
                storePassword =
                    keystoreProperties.getProperty("storePassword")
                        ?: System.getenv("ANDROID_STORE_PASSWORD") ?: ""
                keyAlias =
                    keystoreProperties.getProperty("keyAlias")
                        ?: System.getenv("ANDROID_KEY_ALIAS") ?: ""
                keyPassword =
                    keystoreProperties.getProperty("keyPassword")
                        ?: System.getenv("ANDROID_KEY_PASSWORD") ?: ""
            }
        }
    }

    buildTypes {
        release {
            val releaseCfg = signingConfigs.getByName("release")
            val sf = releaseCfg.storeFile
            signingConfig =
                if (sf != null && sf.exists()) {
                    releaseCfg
                } else {
                    throw GradleException(
                        "Play Store requires a release-signed App Bundle. " +
                            "Create android/key.properties (copy from key.properties.example) with " +
                            "storeFile, storePassword, keyAlias, keyPassword pointing to your upload keystore. " +
                            "Without it, Gradle was using debug signing (rejected by Google).",
                    )
                }
        }
    }
}

flutter {
    source = "../.."
}
