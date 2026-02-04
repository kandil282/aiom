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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
plugins {
    // السطور اللي موجودة سيبها زي ما هي
    id("com.google.gms.google-services") version "4.4.0" apply false
}
subprojects {
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.github.barteksc" && requested.name == "android-pdf-viewer") {
                useVersion("3.2.0-beta.1")
            }
        }
    }
}
