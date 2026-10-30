group = "io.proximi.flutter_proximiio"
version = "6.0.0-beta.6"

buildscript {
    val kotlinVersion = "2.4.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

// The Proximi.io SDK is published to its own Maven repository (public reads, no credentials).
// Apps that declare repositories in settings.gradle(.kts) with
// RepositoriesMode.FAIL_ON_PROJECT_REPOS must add this repository there themselves.
rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
        maven("https://maven.eu.proximi.fi/releases/")
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "io.proximi.flutter_proximiio"

    // The SDK's AndroidX and OkHttp dependencies require compiling against API 37.
    compileSdk = 37

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 26
    }

    testOptions {
        unitTests {
            isReturnDefaultValues = true
            all {
                it.useJUnitPlatform()
                it.outputs.upToDateWhen { false }
                it.testLogging {
                    events("passed", "skipped", "failed", "standardError")
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Pinned exactly: each flutter_proximiio release is built and tested against one SDK release.
    implementation("io.proximi.sdk:proximiio:6.0.0-beta.36")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")

    // The JUnit 5 variant by name: built-in Kotlin does not pick it from useJUnitPlatform().
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit5")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.11.0")
}
