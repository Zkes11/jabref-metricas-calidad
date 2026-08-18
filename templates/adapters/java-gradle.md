# Adapter: Java + Gradle

> Cómo adoptar el pipeline de calidad en un repo Java/Gradle.
> La API completa está en [CONTRACT.md](../CONTRACT.md); la guía general en [README.md](../README.md).

## 1. Prerrequisitos del repo

- Gradle wrapper (`./gradlew`) commiteado y ejecutable (`chmod +x gradlew` si hace falta).
- Tests que Gradle reporta como JUnit XML: el task `test` lo emite **nativamente**, sin
  configurar nada (JUnit 5, Spock, o cualquier framework que el `test` task instrumente).
- **Repos con JavaFX/GUI**: los tests necesitan display. En CI Linux hay que envolver
  `TEST_CMD` con `xvfb-run` e instalar xvfb antes — documentado como **override**, no es
  el default (ver abajo).

## 2. Bloque ⚙️ CONFIGURÁ — valores para Java/Gradle

Dejá las vars vacías y ya funciona: `setup-defaults.sh` resuelve exactamente estos defaults.

```yaml
ECOSYSTEM: java
BUILD_CMD: ''   # default: ./gradlew assemble --no-daemon
TEST_CMD: ''    # default: ./gradlew test --no-daemon
JUNIT_GLOB: ''  # default: **/build/test-results/test/TEST-*.xml  (estándar de Gradle, multi-módulo)
COVERAGE_CMD: ''        # default: ./gradlew jacocoTestReport
COVERAGE_REPORT: ''     # default: **/build/reports/jacoco/test/jacocoTestReport.xml
```

### Override típico: JavaFX headless (xvfb)

Si tu repo tiene UI (JavaFX), los tests fallan sin display en CI. Override del `TEST_CMD`:

```yaml
TEST_CMD: xvfb-run --auto-servernum ./gradlew test --no-daemon
```

Y un step extra de instalación antes del build. En CircleCI:

```yaml
      - run:
          name: 🖥️ Instalar xvfb (tests con JavaFX)
          command: sudo apt-get update -qq && sudo apt-get install -y xvfb
```

En Azure Pipelines: `sudo apt-get update -qq && sudo apt-get install -y xvfb` como
`script:` antes del build.

## 3. Coverage

Default: `./gradlew jacocoTestReport` — requiere el plugin `jacoco` aplicado en el
build (la mayoría ya lo tiene). El XML queda en
`build/reports/jacoco/test/jacocoTestReport.xml` por módulo (el default de
`COVERAGE_REPORT` ya lo globbea multi-módulo).

Tip: si ya corriste los tests en el mismo paso, `./gradlew jacocoTestReport -x test`
reutiliza los `.exec` existentes sin re-correr los tests.

## 4. Compatibilidad TestRail

Cualquier JUnit XML sirve (el estándar de Gradle ya es el correcto). El `automation_id`
que matchea casos es `classname.name` (FQCN) — ver la guía de setup TestRail del proyecto
para crear el campo custom `automation_id` **antes** de la primera subida.

## 5. Conveniencia local opcional: `just test-report`

NO es requisito del pipeline (el contrato es de env vars, ver CONTRACT.md). Si usás `just`:

```just
# justfile
[unix]
test-report:
    ./gradlew test --no-daemon
```

Mismo XML que el CI, en tu máquina — útil para inspeccionarlo antes de que suba.

## Implementación de referencia

Este adapter describe la configuración que usa el repo de referencia
[Zkes11/jabref-metricas-calidad](https://github.com/Zkes11/jabref-metricas-calidad)
(Java/Gradle multi-módulo con JavaFX): sus configs de CI en la raíz del repo muestran la
evolución natural del template — jobs extra de calidad (checkstyle, SpotBugs, PMD) como
extensión, no parte del núcleo.
