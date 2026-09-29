import com.android.build.api.artifact.ScopedArtifact
import com.android.build.api.variant.LibraryAndroidComponentsExtension
import com.android.build.api.variant.ScopedArtifacts
import kotlinx.validation.api.dump
import kotlinx.validation.api.filterOutNonPublic
import kotlinx.validation.api.loadApiFromJvmClasses
import java.util.jar.JarFile

// Top-level build file where you can add configuration options common to all sub-projects/modules.
buildscript {
    dependencies {
        // Needed at runtime by the validator's API loader used in AndroidApiDumpTask.
        classpath(libs.kotlin.metadata.jvm)
    }
}

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.roborazzi) apply false
    alias(libs.plugins.binary.compatibility.validator)
}

apiValidation {
    // Android libraries use AGP's built-in Kotlin, which the plugin does not detect.
    // They are covered by the tasks registered below instead.
    ignoredProjects += listOf("sample", "lib", "lib-no-op")
}

/** Dumps the public JVM API of an Android library variant with the validator's own dump format. */
abstract class AndroidApiDumpTask : DefaultTask() {
    @get:InputFiles
    abstract val classJars: ListProperty<RegularFile>

    @get:InputFiles
    abstract val classDirs: ListProperty<Directory>

    @get:OutputFile
    abstract val outputFile: RegularFileProperty

    @TaskAction
    fun dumpApi() {
        val classFiles = classDirs.get().flatMap { dir ->
            dir.asFile.walk().filter { it.isFile && isApiClass(it.name) }.map { it.readBytes() }
        } + classJars.get().flatMap { jar ->
            JarFile(jar.asFile).use { jarFile ->
                jarFile.entries().toList()
                    .filter { isApiClass(it.name.substringAfterLast('/')) }
                    .map { jarFile.getInputStream(it).use { stream -> stream.readBytes() } }
            }
        }
        val api = classFiles.asSequence().map { it.inputStream() }.loadApiFromJvmClasses().filterOutNonPublic()
        outputFile.get().asFile.bufferedWriter().use { api.dump(it) }
    }

    // Generated classes (resources, build config, Compose lambda holders) are not part of the API contract.
    private fun isApiClass(fileName: String): Boolean =
        fileName.endsWith(".class") &&
            fileName != "R.class" && !fileName.startsWith("R$") &&
            fileName != "BuildConfig.class" &&
            !fileName.startsWith("ComposableSingletons$")
}

subprojects {
    pluginManager.withPlugin("com.android.library") {
        val moduleName = project.name
        val apiFile = layout.projectDirectory.file("api/$moduleName.api")
        val dumpTask = tasks.register<AndroidApiDumpTask>("dumpReleaseApi") {
            outputFile.set(layout.buildDirectory.file("api/$moduleName.api"))
        }
        extensions.configure<LibraryAndroidComponentsExtension> {
            onVariants(selector().withBuildType("release")) { variant ->
                variant.artifacts.forScope(ScopedArtifacts.Scope.PROJECT)
                    .use(dumpTask)
                    .toGet(ScopedArtifact.CLASSES, AndroidApiDumpTask::classJars, AndroidApiDumpTask::classDirs)
            }
        }
        tasks.register<Copy>("apiDump") {
            description = "Writes the public API of the release variant to api/$moduleName.api."
            from(dumpTask)
            into(layout.projectDirectory.dir("api"))
        }
        val apiCheck = tasks.register("apiCheck") {
            description = "Fails when the public API differs from api/$moduleName.api."
            val generated = dumpTask.flatMap { it.outputFile }
            inputs.file(generated)
            inputs.file(apiFile)
            doLast {
                check(generated.get().asFile.readText() == apiFile.asFile.readText()) {
                    "Public API of $moduleName changed. Run ./gradlew apiDump and review the diff."
                }
            }
        }
        apiCheck.configure { dependsOn(":apiParityCheck") }
        tasks.named("check") { dependsOn(apiCheck) }
    }
}

// debug and debug-no-op are swapped per build type, so their public API must be identical.
tasks.register("apiParityCheck") {
    description = "Fails when lib and lib-no-op API dumps differ."
    val debugApi = layout.projectDirectory.file("lib/api/lib.api")
    val noOpApi = layout.projectDirectory.file("lib-no-op/api/lib-no-op.api")
    inputs.file(debugApi)
    inputs.file(noOpApi)
    doLast {
        check(debugApi.asFile.readText() == noOpApi.asFile.readText()) {
            "lib/api/lib.api and lib-no-op/api/lib-no-op.api differ. Keep the public API of both artifacts identical."
        }
    }
}
