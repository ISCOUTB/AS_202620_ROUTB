allprojects {
    repositories {
        google()
        mavenCentral()
    }

    
}

group = "com.example.frontend_android"
description = "ROUTB Android application"

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

tasks.register<Delete>("clean") {
    description = "Deletes the build directory."
    group = BasePlugin.BUILD_GROUP
    delete(rootProject.layout.buildDirectory)
}
