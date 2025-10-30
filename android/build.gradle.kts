plugins {
    id("com.google.gms.google-services") version "4.4.3" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

//android {
//    ndkVersion = "27.0.12077973"
//    compileSdk 34
//
//    defaultConfig {
//        minSdkVersion 21
//        targetSdkVersion 34
//    }
//    // ... resto de tu configuración
//}


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

buildscript {
    dependencies {
        classpath("com.android.tools.build:gradle:8.7.0")
        classpath("com.google.gms:google-services:4.4.0")
    }
}

