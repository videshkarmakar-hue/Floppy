import java.io.FileInputStream
import java.util.Properties
import com.android.build.gradle.internal.api.ApkVariantOutputImpl

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.videshkarmakar.floppy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "com.videshkarmakar.floppy"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        androidResources {
            localeFilters.addAll(listOf("en"))
        }
    }

    buildTypes {
        // Sign debug builds with the project keystore when one is configured, so
        // builds from CI keep a stable signature and the in-app updater can
        // install each new APK over the previous one.
        debug {
            signingConfig = signingConfigs.getByName(
                if (keystorePropertiesFile.exists()) "release" else "debug"
            )
        }
        release {
            // Without key.properties (local builds) sign with the debug keystore,
            // which is the same key the currently installed debug build uses, so
            // the APK installs as an update instead of failing on a key mismatch.
            signingConfig = signingConfigs.getByName(
                if (keystorePropertiesFile.exists()) "release" else "debug"
            )
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            ndk {
                debugSymbolLevel = "none"
            }
        }
    }

    packaging {
        jniLibs.useLegacyPackaging = false
    }

    // flutter_avif_web and media_kit bundle browser-only artifacts (.wasm / hls.js)
    // that are never loaded on Android, where the native libraries are used instead.
    // Strip them from Flutter's staged assets so every APK ships ~3 MB less.
    val webOnlyFlutterAssets = listOf(
        "packages/flutter_avif_web/web/avif_encoder_bg.wasm",
        "packages/flutter_avif_web/web/avif_decoder.wasm",
        "packages/media_kit/assets/web/hls1.4.10.js",
    )
    tasks.matching { it.name.startsWith("copyFlutterAssets") }.configureEach {
        val taskName = name
        val stagedAssets = layout.buildDirectory
            .dir("intermediates/assets/${taskName.removePrefix("copyFlutterAssets").replaceFirstChar { it.lowercase() }}/$taskName/flutter_assets")
        doLast {
            webOnlyFlutterAssets.forEach { relativePath ->
                val asset = stagedAssets.get().file(relativePath).asFile
                if (asset.exists() && asset.delete()) {
                    logger.lifecycle("Stripped web-only Flutter asset: $relativePath")
                }
            }
        }
    }
}

flutter {
    source = "../.."
}

// ABI split version code scheme required for F-Droid ABI split support
val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abiVersionCode = abiCodes[output.filters.find { it.filterType == "ABI" }?.identifier]
        if (abiVersionCode != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride = variant.versionCode * 10 + abiVersionCode
        }
    }
}

dependencies {
    implementation("dev.rikka.shizuku:api:13.1.5")
    implementation("dev.rikka.shizuku:provider:13.1.5")
}
