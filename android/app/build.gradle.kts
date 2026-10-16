plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // ★ 1016：Firebase（FCM 真推送）
    id("com.google.gms.google-services")
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
    // ═══════════════════════════════════════════════════════════════
    // ★ 1014 签名配置（由你自己控制，代码里不含任何密码）
    //
    // CI 会从 GitHub Secrets 读取以下几项，并生成 keystore 文件：
    //   ANDROID_KEYSTORE_BASE64  —— 你的 .jks base64 编码（必须）
    //   ANDROID_STORE_PASSWORD   —— 密钥库密码（必须）
    //   ANDROID_KEY_ALIAS        —— 别名（必须）
    //   ANDROID_KEY_PASSWORD     —— 密钥密码（不填则同密钥库密码）
    //
    // 本地构建：把 keystore 放到 android/app/keystore/release.jks
    //          并在 android/keystore.properties 里填密码即可。
    //
    // 任一缺失时自动退回 debug 签名，保证构建不中断。
    // ═══════════════════════════════════════════════════════════════
    signingConfigs {
        create("release") {
            // ★ 1014：签名全部通过环境变量传入（CI Secrets / 本地导出），
            //   代码里不含任何密码。
            //   CI 会先准备好 keystore 并设置：
            //     ANDROID_KEYSTORE_PATH / ANDROID_STORE_PASSWORD
            //     ANDROID_KEY_ALIAS     / ANDROID_KEY_PASSWORD
            val ksPath = System.getenv("ANDROID_KEYSTORE_PATH")
            if (ksPath != null) {
                val f = file(ksPath)
                if (f.exists()) {
                    storeFile = f
                    storePassword = System.getenv("ANDROID_STORE_PASSWORD")
                    keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                    keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
                        ?: System.getenv("ANDROID_STORE_PASSWORD")
                }
            }
            // ★ 1015：v1 + v2 + v3 全开
            //   v1(JAR)   —— 兼容 Android 6 及以下的旧机型
            //   v2(APK)   —— Android 7.0+ 整包校验，防篡改
            //   v3(APK)   —— Android 9.0+ 密钥轮换，支持后续换签名
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        release {
            // 有可用签名就用它；否则退回 debug（保证构建不中断）
            signingConfig = if (signingConfigs.getByName("release").storeFile != null) {
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

dependencies {
    // ★ 1015：QQ 登录 SDK（本地 jar，来自腾讯官方）
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar"))))
}
