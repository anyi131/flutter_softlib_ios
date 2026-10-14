plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.soft.anyi"
    compileSdk = 36
//    ndkVersion = flutter.ndkVersion
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
        applicationId = "com.soft.anyi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 只打包 arm64-v8a，大幅减小 APK 体积（现代手机几乎全是 arm64）
        ndk {
            // 只保留 arm64-v8a，减小体积；如需兼容老设备可加 armeabi-v7a
            abiFilters.add("arm64-v8a")
        }
    }

    // ★ 1014 关键修复：release 必须用「固定签名」。
    //   原来用 signingConfigs.debug —— debug 密钥由 CI 每次随机生成，
    //   导致每次构建签名都不同 → 新包无法覆盖安装旧包（用户反馈「更新后覆盖不了」）。
    //   现在：CI 首次构建时生成 keystore 并缓存，之后所有构建复用同一签名。
    signingConfigs {
        create("release") {
            val ksPath = System.getenv("ANDROID_KEYSTORE_PATH") ?: "${rootDir}/app/keystore/anyi-release.jks"
            val ksFile = file(ksPath)
            if (ksFile.exists()) {
                storeFile = ksFile
                storePassword = System.getenv("ANDROID_STORE_PASSWORD") ?: "anyi2026softlib"
                keyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: "anyi"
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD") ?: "anyi2026softlib"
            }
        }
    }

    buildTypes {
        release {
            // 有固定签名就用它；没有才退回 debug（保证首次构建不失败）
            signingConfig = if (file("${rootDir}/app/keystore/anyi-release.jks").exists()
                || System.getenv("ANDROID_KEYSTORE_PATH") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // 加固:R8 代码混淆 + 资源裁剪
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}


flutter {
    source = "../.."
}
