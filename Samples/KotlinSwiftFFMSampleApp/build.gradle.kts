//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import utilities.javaLibraryPaths
import utilities.registerJextractTask

plugins {
    id("build-logic.java-application-conventions")
    kotlin("jvm") version "2.3.10"
}

group = "org.swift.swiftkit"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(25))
    }
}

kotlin {
    jvmToolchain(25)
}

val jextract = registerJextractTask()

// Add the generated Kotlin sources from jextract-swift
sourceSets {
    main {
        java {
            srcDir(jextract)
        }
    }
}

tasks.build {
    dependsOn(jextract)
}

registerCleanSwift()

dependencies {
    implementation(projects.swiftKitCore)
    implementation(projects.swiftKitFFM)
}

application {
    mainClass = "com.example.kotlin.HelloKotlin2SwiftKt"

    applicationDefaultJvmArgs = listOf(
        "--enable-native-access=ALL-UNNAMED",
        "-Djava.library.path=" + (javaLibraryPaths(rootDir) + javaLibraryPaths(project.projectDir)).joinToString(":"),
        "-Djextract.trace.downcalls=true",
        "-ea"
    )
}
