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

// bluetooth_print_plus (2.4.6) trae hardcodeado compileSdkVersion 31 en su
// propio build.gradle, insuficiente para sus dependencias androidx.window
// (piden 34+). Forzamos el compileSdk del proyecto raíz en todos los
// módulos Android de plugins, sin tocar el plugin en el pub-cache.
subprojects {
    val forceCompileSdk: () -> Unit = {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.let { it.compileSdk = 36 }
    }
    if (state.executed) forceCompileSdk() else afterEvaluate { forceCompileSdk() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
