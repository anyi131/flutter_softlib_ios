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
        // 用反射设置 compileSdk，避免依赖 AGP 类型（kts 下类型不可见）
        try {
            val ext = extensions.findByName("android")
            if (ext != null) {
                val m = ext.javaClass.methods.firstOrNull {
                    it.name == "compileSdkVersion" && it.parameterTypes.size == 1
                }
                m?.invoke(ext, 34)
            }
        } catch (_: Throwable) {}
        // 强制 JDK 17（AGP 8.x 要求）
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
    }
}
