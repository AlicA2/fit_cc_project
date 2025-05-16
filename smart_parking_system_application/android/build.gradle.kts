buildscript {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal() // Ensures plugins can be resolved
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.0.2")  // Make sure version is specified
        classpath("com.google.gms:google-services:4.4.0")  // Ensure this line has a version
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
    }
}

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
