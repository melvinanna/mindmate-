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
    val block = Action<Project> {
        if (hasProperty("android") && name == "perfect_volume_control") {
            val android = extensions.getByName("android") as com.android.build.gradle.BaseExtension
            if (android.namespace == null) {
                android.namespace = "com.perfect_volume_control"
            }
        }
    }
    if (state.executed) {
        block.execute(this)
    } else {
        afterEvaluate(block)
    }
}
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
