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
subprojects {
    val setupNamespace: (Project) -> Unit = { p ->
        if (p.hasProperty("android")) {
            val android = p.extensions.getByName("android") as com.android.build.gradle.BaseExtension

            // 1. Target the telephony package specifically
            if (p.name == "telephony") {
                android.namespace = "com.shounakmulay.telephony"
            }
            // 2. Safety net for any other legacy plugins missing a namespace
            else if (android.namespace == null) {
                android.namespace = "com.mint.transaction_app.${p.name.replace("-", "_")}"
            }
        }
    }

    // If already evaluated, run immediately. If not, wait for afterEvaluate.
    if (project.state.executed) {
        setupNamespace(project)
    } else {
        afterEvaluate { setupNamespace(project) }
    }
}
