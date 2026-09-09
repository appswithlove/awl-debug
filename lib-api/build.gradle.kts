import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.maven.publish)
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    api(libs.kotlinx.coroutines.core)

    testImplementation(libs.junit)
    testImplementation(libs.kotest.assertions.core)
}

mavenPublishing {
    coordinates(artifactId = "debug-api")
    publishToMavenCentral(automaticRelease = true)
    pom {
        name.set("debug-api")
        description.set("Public API and contracts for the awl-debug Android debug panel")
    }
}
