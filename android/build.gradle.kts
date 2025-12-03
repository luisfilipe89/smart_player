buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
        classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.2")
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

// Fix namespace issue for device_calendar 3.9.0
// Note: The device_calendar build.gradle file has been patched directly in the cache
// to add namespace 'com.builttoroam.devicecalendar'. This patch will persist until
// the package is re-downloaded (flutter pub get --force).
// If the build fails again, re-apply the patch manually or run the patch script.

subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
            compileSdk = 36
            // For other plugins without namespace, try to read from AndroidManifest.xml
            if (project.name != "device_calendar") {
                try {
                    // Store namespace in local variable to avoid smart cast error
                    val currentNamespace: String? = namespace
                    if (currentNamespace == null || currentNamespace.isEmpty()) {
                        val manifestFile = file("src/main/AndroidManifest.xml")
                        if (manifestFile.exists()) {
                            try {
                                val manifestContent = manifestFile.readText()
                                val packageMatch = Regex("package=\"([^\"]+)\"").find(manifestContent)
                                if (packageMatch != null) {
                                    namespace = packageMatch.groupValues[1]
                                }
                            } catch (e: Exception) {
                                // Ignore errors reading manifest
                            }
                        }
                    }
                } catch (e: Exception) {
                    // Ignore errors accessing namespace property
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
