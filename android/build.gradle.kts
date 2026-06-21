allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val configureAndroidSDK = { proj: Project ->
        if (proj.plugins.hasPlugin("com.android.library")) {
            proj.configure<com.android.build.api.dsl.LibraryExtension> {
                compileSdk = 36
            }
        }
    }
    if (state.executed) {
        configureAndroidSDK(this)
    } else {
        afterEvaluate {
            configureAndroidSDK(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
