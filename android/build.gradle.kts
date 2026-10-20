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
    ignoredProjects += listOf("example", "debug", "debug-no-op")
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

// Real and no-op artifacts are swapped per build type, so their public API must be identical.
val noOpPairs = listOf("debug" to "debug-no-op")

tasks.register("apiParityCheck") {
    description = "Fails when the API dumps of a real artifact and its no-op variant differ."
    val dumps = noOpPairs.map { (real, noOp) ->
        layout.projectDirectory.file("$real/api/$real.api") to layout.projectDirectory.file("$noOp/api/$noOp.api")
    }
    dumps.forEach { (real, noOp) ->
        inputs.file(real)
        inputs.file(noOp)
    }
    doLast {
        dumps.forEach { (real, noOp) ->
            check(real.asFile.readText() == noOp.asFile.readText()) {
                "${real.asFile.path} and ${noOp.asFile.path} differ. Keep the public API of both artifacts identical."
            }
        }
    }
}

// Libraries compile against the lowest supported OkHttp. `-PokhttpVersion=<v>` runs the build and
// tests against another version, for example the one an app resolves to.
providers.gradleProperty("okhttpVersion").orNull?.let { okhttpVersion ->
    subprojects {
        configurations.configureEach {
            resolutionStrategy.eachDependency {
                if (requested.group == "com.squareup.okhttp3") useVersion(okhttpVersion)
            }
        }
    }
}
