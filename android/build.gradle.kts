allprojects {
    // 1109：强制 androidx.core 1.17.x —— 1.19 要求 AGP 9.1，而 AGP 9 会打断
    //   flutter_inappwebview 的构建脚本（proguard-android.txt 已废弃）
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.17.0")
            force("androidx.core:core-ktx:1.17.0")
        }
    }
    repositories {
        google()
        mavenCentral()
        // ★ 1015：本地 jar 仓库（QQ SDK）
        flatDir {
            dirs("app/libs", "libs")
        }
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

