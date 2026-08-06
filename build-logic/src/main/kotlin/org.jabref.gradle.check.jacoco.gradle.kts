import org.gradle.testing.jacoco.plugins.JacocoPluginExtension
import org.gradle.testing.jacoco.tasks.JacocoReport

plugins {
    id("jacoco")
}

// Version de JaCoCo compatible con JDK 25.
// Ver https://www.jacoco.org/jacoco/trunk/doc/changes.html
configure<JacocoPluginExtension> {
    toolVersion = "0.8.13"
}

tasks.withType<JacocoReport>().configureEach {
    reports {
        xml.required = true
        html.required = true
        csv.required = false
    }
}

// El reporte depende de que los tests hayan corrido.
tasks.named("jacocoTestReport") {
    dependsOn("test")
}
