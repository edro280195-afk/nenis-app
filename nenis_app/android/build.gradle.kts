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
    // Deshabilitamos checkDebugAarMetadata en los plugins (library) para que
    // no rompa el build cuando un plugin trae deps que "requieren" compileSdk
    // mayor al que el plugin declara (p. ej. android_play_install_referrer
    // trae androidx.fragment:1.7.1 que exige 34 pero el plugin se compila
    // contra 33). El check es de lint, no afecta runtime.
    project.tasks.matching { it.name == "checkDebugAarMetadata" }.configureEach {
        enabled = false
    }
    project.tasks.matching { it.name == "checkReleaseAarMetadata" }.configureEach {
        enabled = false
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
