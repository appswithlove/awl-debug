import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.maven.publish)
}

// Bytecode for Java 11: with 17, Kotlin marks sealed types with `PermittedSubclasses`, which the javadoc
// generation of the Android Gradle plugin cannot read in libraries that depend on this one.
java {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

dependencies {
    api(libs.kotlinx.coroutines.core)

    testImplementation(libs.junit)
    testImplementation(libs.kotest.assertions.core)
    testImplementation(libs.kotlinx.coroutines.test)
}

mavenPublishing {
    coordinates(artifactId = "debug-api")
    publishToMavenCentral(automaticRelease = true)
    pom {
        name.set("debug-api")
        description.set("Public API and contracts for the awl-debug Android debug panel")
    }
}
