import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Global build directory setup
val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // Ensure the app is evaluated before its plugins
    if (project.name != "app") {
        project.evaluationDependsOn(":app")
    }

    // THE FIX: Robust injection for LStar and SDK requirements
    afterEvaluate {
        val android = project.extensions.findByName("android")
        if (android is BaseExtension) {
            // 1. Force SDK 36 for all plugins. 
            // This is the specific fix for 'resource android:attr/lStar not found'
            android.compileSdkVersion(36)
            
            android.defaultConfig {
                if (targetSdkVersion == null) {
                    targetSdkVersion(36)
                }
            }

            // 2. Inject Namespace if missing (Required for AGP 8.0+)
            if (android.namespace == null) {
                val groupName = project.group.toString()
                android.namespace = if (groupName.isNotEmpty()) {
                    groupName
                } else {
                    "com.example.${project.name.replace("-", "_")}"
                }
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