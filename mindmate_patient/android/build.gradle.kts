import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    if (project.name != "app") {
        project.evaluationDependsOn(":app")
    }

    project.afterEvaluate {
        val android = project.extensions.findByName("android")
        if (android is BaseExtension) {
            android.compileSdkVersion(36)
            android.defaultConfig {
                targetSdkVersion(36)
            }
            // Fix: Only set namespace if not already set, to avoid conflicts with modern plugins
            if (android.namespace == null) {
                // Determine a sane namespace for older plugins
                val groupName = project.group.toString()
                android.namespace = if (groupName.isNotEmpty()) groupName else "com.example.${project.name.replace("-", "_")}"
            }
        }
    }

    // Force ALL projects to use a version of androidx.core that won't cause lStar conflicts
    project.configurations.all {
        resolutionStrategy {
            eachDependency {
                if (requested.group == "androidx.core" && (requested.name == "core" || requested.name == "core-ktx")) {
                    useVersion("1.13.1")
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
