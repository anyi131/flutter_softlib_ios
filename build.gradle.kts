allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// ══════════════════════════════════════════════════════════════
// ★ 1015：兼容老插件（tencent_kit）
//   tencent_kit 6.2.0 的 build.gradle 里写死 compileSdkVersion 31，
//   而 AGP 8.x 要求 compileSdk >= 34，否则构建直接失败。
//   这里在主工程统一覆盖所有子工程的 compileSdk / minSdk。
// ══════════════════════════════════════════════════════════════
subprojects {
    afterEvaluate {
        val ext = extensions.findByName("android")
        if (ext != null) {
            try {
                val android = ext as com.android.build.gradle.BaseExtension
                if (android.compileSdkVersion == null ||
                    (android.compileSdkVersion?.removePrefix("android-")?.toIntOrNull() ?: 0) < 34) {
                    android.compileSdkVersion(34)
                }
            } catch (_: Throwable) {
                // 非 Android 子工程，忽略
            }
        }
        // 强制 JDK 17（AGP 8.x 要求）
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
    }
}
