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
//   tencent_kit 写死 compileSdkVersion 31，AGP 8.x 要求 >= 34。
//   注意：不能用 afterEvaluate —— 本工程已有 evaluationDependsOn(":app")，
//   子工程在配置阶段就已求值，再注册 afterEvaluate 会报
//   「Cannot run Project.afterEvaluate(Action) when the project is already evaluated」。
//   所以这里直接遍历子工程、在配置阶段立即改。
// ══════════════════════════════════════════════════════════════
subprojects {
    // 立即（配置阶段）修改，不用 afterEvaluate
    try {
        val ext = extensions.findByName("android")
        if (ext != null) {
            val m = ext.javaClass.methods.firstOrNull {
                it.name == "compileSdkVersion" && it.parameterTypes.size == 1
            }
            m?.invoke(ext, 34)
        }
    } catch (_: Throwable) {}
}

// JDK 17 强制（AGP 8.x 要求）—— 这个可以在配置阶段直接挂
allprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
}
