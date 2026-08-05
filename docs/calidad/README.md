# 📊 Métricas de Calidad para JabRef — Guía Completa

Este documento explica **qué hace cada herramienta de calidad**, **cómo correrlas localmente**, **cómo configurarlas en Azure DevOps y CircleCI**, y **qué se detecta al correrlas sobre el código de JabRef**.

---

## 🗺️ Tabla de contenidos

1. [Visión general](#-visión-general)
2. [Cada herramienta: qué mide y qué detecta](#-cada-herramienta-qué-mide-y-qué-detecta)
3. [Setup local: instalar JDK 25](#-setup-local-instalar-jdk-25)
4. [Correr las herramientas localmente](#-correr-las-herramientas-localmente)
5. [Setup de Azure DevOps (Microsoft)](#-setup-de-azure-devops-microsoft)
6. [Setup de CircleCI](#-setup-de-circleci)
7. [Comparativa: Azure DevOps vs CircleCI](#-comparativa-azure-devops-vs-circleci)
8. [Qué se detectó al correr sobre JabRef](#-qué-se-detectó-al-correr-sobre-jabref)

---

## 🎯 Visión general

El proyecto JabRef ya trae configuradas varias herramientas de calidad (Checkstyle, Modernizer, OpenRewrite, JaCoCo, JUnit). **Lo que agregamos nosotros** son dos pipelines de CI/CD que orquestan estas herramientas en la nube:

```
                       ┌─────────────────────────────┐
                       │       Tu repo en GitHub     │
                       │   (fork de JabRef/jabref)   │
                       └──────────────┬──────────────┘
                                      │ push / PR
                       ┌──────────────┴──────────────┐
                       ▼                              ▼
              ┌─────────────────┐          ┌─────────────────┐
              │ Azure Pipelines │          │     CircleCI    │
              │ (Microsoft)     │          │                 │
              └────────┬────────┘          └────────┬────────┘
                       │                            │
            ┌──────────┼──────────┐       ┌─────────┼─────────┐
            ▼          ▼           ▼       ▼         ▼          ▼
         Build      Tests     Quality  Build    Tests       Static
         +Cobertura            +Static         +Cobertura   Analysis
                              Analysis
```

Los dos pipelines corren **las mismas verificaciones** pero en distintas plataformas. Sirven para:
- **Doble validación** (un bug en una plataforma no bloquea todo)
- **Aprender dos ecosistemas** de CI/CD distintos
- **Comparar límites y costos** de cada proveedor

---

## 🔧 Cada herramienta: qué mide y qué detecta

| Herramienta | Qué mide | Qué detecta | Origen |
|---|---|---|---|
| **JUnit 5** | Tests unitarios y de integración | Bugs funcionales, regresiones | Ya en JabRef |
| **JaCoCo** | Cobertura de código (líneas, ramas) | Código nunca ejecutado por tests | Ya en JabRef |
| **Checkstyle** | Estilo y convenciones | Violaciones de formato, nombres mal, imports sin usar | Ya en JabRef |
| **Modernizer** | Uso de APIs legacy | Código que ignora mejoras modernas de Java | Ya en JabRef |
| **OpenRewrite** | Refactors automáticos | Código que puede modernizarse/limpiarse | Ya en JabRef |
| **SpotBugs** | Análisis estático profundo | Bugs comunes (null pointers, race conditions, malas prácticas) | **Nuevo** |
| **OWASP Dep-Check** | Seguridad de dependencias | CVEs conocidos en librerías de terceros | **Nuevo** |

### 📖 Detalle de cada una

#### JUnit 5 (`./gradlew test`)
Framework de testing estándar de Java. Ejecuta los métodos anotados con `@Test` y reporta cuántos pasan, fallan o se omitieron. En JabRef hay **miles de tests** distribuidos por módulo (`jablib`, `jabgui`, etc.).

- **Qué detecta**: cualquier comportamiento que se rompió tras un cambio.
- **Formatos de salida**: JUnit XML (`build/test-results/test/TEST-*.xml`) → visible en pestaña "Tests" de Azure y CircleCI.

#### JaCoCo (`./gradlew :jablib:jacocoTestReport`)
Instrumenta el bytecode mientras los tests corren y registra qué líneas fueron ejecutadas. Genera un reporte HTML navegable con colores verde/rojo por línea.

- **Qué detecta**: código "muerto" que ningún test cubre. Cobertura alta **no implica calidad**, pero cobertura baja suele indicar problemas.
- **Reporte**: `jablib/build/reports/jacoco/test/html/index.html` — abre en navegador.

#### Checkstyle (`./gradlew checkstyleMain checkstyleTest`)
Valida el código contra un conjunto de reglas definidas en `config/checkstyle/checkstyle.xml`. JabRef usa Checkstyle 10.23.0 con reglas estrictas (longitud de línea, nombres, espacios, imports ordenados).

- **Qué detecta**: violaciones de estilo (una línea >120 caracteres, un nombre de variable con typo, un import sin usar).
- **Reporte**: `<modulo>/build/reports/checkstyle/main.html`.

#### Modernizer (`./gradlew modernizer`)
Detecta uso de APIs legacy de Java que ya tienen reemplazo moderno. Por ejemplo: usar `Vector` en vez de `ArrayList`, o `Collections.synchronizedList` en vez de estructuras concurrentes modernas.

- **Qué detecta**: código que funcionar funciona pero no aprovecha mejoras de Java 8+.
- **Configuración**: `failOnViolations = true` → hace fallar el build si hay violaciones.

#### OpenRewrite (`./gradlew rewriteDryRun` / `rewriteRun`)
Motor de refactor automático. Aplica recetas (definidas en `rewrite.yml`) que modernizan el código: convertir anonymous classes a lambdas, simplificar streams, etc.

- **`rewriteDryRun`**: solo reporta qué cambiaría. **Hace fallar el build** si hay cambios pendientes (`failOnDryRunResults = true`).
- **`rewriteRun`**: aplica los cambios al código fuente.

#### SpotBugs (standalone en CI)
Sucesor de FindBugs. Analiza el bytecode compilado buscando ~400 patrones de bugs comunes: null pointers posibles, comparaciones de strings con `==`, race conditions, escapes de `this` en constructores, etc.

- **Qué detecta**: bugs reales que Checkstyle no ve (Checkstyle mira sintaxis, SpotBugs mira comportamiento).
- **Lo corremos standalone** (descargando el CLI) para no modificar el `build-logic` de JabRef.

#### OWASP Dependency-Check (standalone en CI)
Escanea las dependencias (JARs) y las compara con la base de datos NVD (National Vulnerability Database). Reporta CVEs conocidos.

- **Qué detecta**: librerías con vulnerabilidades conocidas. Por ejemplo, `log4j` 2.14 (Log4Shell).
- **`--failOnCVSS 9`**: falla solo si hay vulnerabilidades críticas (score ≥ 9).

---

## ☕ Setup local: instalar JDK 25

JabRef requiere **JDK 25 o superior**. En tu máquina tenés Java 8, así que hay que actualizarlo.

### Windows (PowerShell)

1. Bajá Temurin 25 desde Adoptium:
   - https://adoptium.net/temurin/releases/?version=25&os=windows&arch=x64
2. Elegí el instalador `.msi` y marcá las opciones:
   - ✅ "Set JAVA_HOME variable"
   - ✅ "Add to PATH"
3. Abrí una **nueva** consola y verificá:
   ```powershell
   java -version
   # Debe decir: openjdk version "25..." o similar
   ```

### Alternativa: `sdkman` (Linux/Mac/WSL)

```bash
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 25-tem
```

---

## ▶️ Correr las herramientas localmente

Te creamos un script que ejecuta todo de una vez:

```powershell
# Windows (PowerShell)
.\scripts\run-quality.ps1
```

```bash
# Linux/Mac/WSL
./scripts/run-quality.sh
```

Esto ejecuta, en orden:

1. `./gradlew assemble` — compilación
2. `./gradlew test :jablib:jacocoTestReport` — tests + cobertura
3. `./gradlew checkstyleMain checkstyleTest` — estilo
4. `./gradlew modernizer` — APIs legacy
5. `./gradlew rewriteDryRun` — refactors pendientes

Al terminar, abrí el reporte de cobertura en el navegador:

```powershell
start jablib\build\reports\jacoco\test\html\index.html
```

### Comandos individuales (para debugging)

```powershell
# Solo tests
.\gradlew.bat test -x databaseTest -x fetcherTest

# Solo checkstyle
.\gradlew.bat checkstyleMain

# Solo cobertura
.\gradlew.bat :jablib:jacocoTestReport

# Aplicar refactors de OpenRewrite
.\gradlew.bat rewriteRun
```

> **Nota**: `databaseTest` requiere PostgreSQL y `fetcherTest` pega a APIs externas. Los excluimos en los pipelines para que no fallen por problemas de infraestructura.

---

## ☁️ Setup de Azure DevOps (Microsoft)

Azure DevOps = suite de Microsoft. Tiene:
- **Azure Pipelines** (CI/CD) — lo que usamos
- Azure Repos (git hosting)
- Azure Boards (kanban)
- Azure Artifacts (npm/maven/etc.)
- Azure Test Plans

### Paso a paso

1. **Crear cuenta** (gratuita):
   - Ir a https://dev.azure.com
   - Iniciar sesión con cuenta Microsoft (o crear una)
   - Te crea una "organización" automáticamente

2. **Crear un proyecto**:
   - "New project" → nombre: `jabref-calidad`
   - Visibility: `Public` o `Private` (da igual para este caso)

3. **Conectar el repo de GitHub**:
   - Necesitás tu fork del repo en GitHub primero.
   - Para forkear: en GitHub andá a https://github.com/JabRef/jabref → "Fork"
   - En Azure DevOps: ir a "Pipelines" → "New pipeline"
   - Elegir "GitHub" → autorizar permisos
   - Seleccionar tu fork
   - Cuando pregunte por la configuración, elegir **"Existing Azure Pipelines file"**
   - Path: `/azure-pipelines.yml` (el archivo que creamos en este repo)
   - "Continue" → "Run"

4. **Ver la ejecución**:
   - Cada push a `main` o PR dispara el pipeline
   - En la pestaña "Pipelines" > tu pipeline > último run
   - Vas a ver 3 jobs paralelos: `Build_Test`, `Quality`, `Static_Analysis`
   - En cada job hay tabs: **Tests** (resultados JUnit), **Code coverage** (JaCoCo), **Artifacts** (reportes HTML)

5. **Límites del tier gratuito**:
   - 1.800 minutos/mes de CI en paralelo (1 job a la vez)
   - Sin tarjeta de crédito necesaria

### ¿Qué vas a ver en Azure DevOps?

| Pestaña | Contenido |
|---|---|
| **Summary** | Estado general (success/partial/fail) |
| **Tests** | Lista de tests con duración y stack traces |
| **Code coverage** | Mapa visual de cobertura JaCoCo |
| **Artifacts** | Reportes HTML descargables (checkstyle, spotbugs, dep-check) |

---

## 🟢 Setup de CircleCI

CircleCI es un servicio de CI/CD puramente cloud, muy enfocado en velocidad (caching agresivo, Docker nativo, matrices paralelas).

### Paso a paso

1. **Crear cuenta**:
   - Ir a https://app.circleci.com
   - "Sign up with GitHub" → autorizar
   - Esto vincula tu cuenta de GitHub con CircleCI

2. **Conectar el repo**:
   - "Projects" en el sidebar izquierdo
   - Buscá tu fork de JabRef
   - Click en **"Set Up Project"**
   - Elegir **"Existing config"** (porque ya tenemos `.circleci/config.yml`)
   - Branch: `main`
   - "Set Up Project"

3. **Primer run**:
   - El pipeline dispara automáticamente
   - Vas a ver 3 jobs en paralelo: `build-test`, `quality-checks`, `static-analysis`
   - Click en cada job para ver logs en vivo

4. **Ver reportes**:
   - En cada job hay una pestaña **"Artifacts"**
   - Ahí están los HTMLs de JaCoCo, Checkstyle, SpotBugs, Dependency-Check
   - Pestaña **"Test Insights"** muestra estadísticas históricas de tests

5. **Límites del tier gratuito**:
   - 6.000 créditos/mes (~30 builds del pipeline completo)
   - 1 job en paralelo
   - Sin tarjeta de crédito

### ¿Qué vas a ver en CircleCI?

| Pestaña | Contenido |
|---|---|
| **Pipeline** | Workflow visual con los 3 jobs |
| **Tests** | Resultados JUnit parseados con métricas |
| **Artifacts** | Reportes HTML/JSON descargables |
| **Insights** | Tiempos históricos, flaky tests, debilidades |

---

## ⚖️ Comparativa: Azure DevOps vs CircleCI

| Característica | Azure DevOps | CircleCI |
|---|---|---|
| **Empresa** | Microsoft | CircleCI (independiente) |
| **Tier gratuito** | 1.800 min/mes, 1 paralelo | 6.000 créditos (~30 builds), 1 paralelo |
| **Configuración** | YAML (`azure-pipelines.yml`) | YAML (`.circleci/config.yml`) |
| **UI** | Completa, integrada con Boards/Repos | Enfocada en CI, muy clara |
| **Caching** | Task `Cache@2` | Orbs + `save_cache`/`restore_cache` |
| **Docker** | Container jobs o `Docker@2` | Nativo (`docker:` en executor) |
| **Paralelismo** | Jobs paralelos con `pool` | Workflows con jobs |
| **Mobile/macOS** | ✅ macOS pool | ✅ macOS executor |
| **Self-hosted** | ✅ Agentes self-hosted | ✅ Runners self-hosted |
| **Integración GH** | App oficial | App oficial |
| **Curva aprendizaje** | Media-alta (ecosistema MS) | Media (más simple y focalizado) |
| **Mejor para** | Equipos que ya usan tools MS | Equipos que quieren velocidad |

**Cuándo elegir cuál:**
- **Azure DevOps**: si trabajás en enterprise que ya usa Microsoft 365 / Azure / Visual Studio.
- **CircleCI**: si querés algo más liviano, rápido y enfocado solo en CI.

---

## 📋 Qué se detectó al correr sobre JabRef

Esto se completa después de correr los pipelines por primera vez. Acá dejamos la plantilla de lo que vamos a buscar:

### Resultados esperados (cuando corras los pipelines)

| Herramienta | Qué buscar en el reporte |
|---|---|
| **JUnit** | N° total de tests, % passing, tests más lentos, flaky tests |
| **JaCoCo** | % de cobertura de líneas y ramas por paquete |
| **Checkstyle** | N° de violaciones, agrupadas por severidad |
| **Modernizer** | N° de usos de APIs legacy |
| **OpenRewrite** | N° de cambios pendientes que aplicaría |
| **SpotBugs** | N° de bugs por categoría (correctness, bad practice, etc.) |
| **Dep-Check** | N° de CVEs en dependencias, agrupados por severidad |

### Después del primer run

Cuando tengas los primeros resultados, volcá en esta sección los números concretos. Por ejemplo:

```
### Run #1 - 2026-08-05
- Tests: 4.328 totales, 4.310 passing (99.6%), 18 skipped
- Cobertura JaCoCo: 67% líneas, 54% ramas
- Checkstyle: 0 violaciones (proyecto pulido)
- Modernizer: 0 violaciones
- OpenRewrite: 0 refactors pendientes
- SpotBugs: TBD (correr job)
- Dependency-Check: TBD (correr job)
```

> Tip: si vas a correr los pipelines en la nube, esos builds van a tardar 20-40 minutos la primera vez (descarga dependencias). Las siguientes veces, con cache, deberían tardar 5-15 minutos.

---

## 📂 Archivos agregados

| Archivo | Para qué sirve |
|---|---|
| `azure-pipelines.yml` | Pipeline de Azure DevOps (3 jobs paralelos) |
| `.circleci/config.yml` | Pipeline de CircleCI (3 jobs paralelos) |
| `scripts/run-quality.ps1` | Script PowerShell para correr todo local en Windows |
| `scripts/run-quality.sh` | Script Bash para correr todo local en Linux/Mac |
| `scripts/spotbugs-exclude.xml` | Filtros de falsos positivos para SpotBugs |
| `docs/calidad/README.md` | Este documento |

---

## ❓ FAQ

**¿Por qué excluimos `databaseTest` y `fetcherTest`?**
Porque requieren infraestructura externa: `databaseTest` necesita PostgreSQL corriendo y `fetcherTest` pega contra APIs reales de Springer, IEEE, etc. En CI las excluimos para no flakear.

**¿Por qué SpotBugs y Dep-Check son "standalone"?**
Para no tocar el `build-logic` original de JabRef (que tiene su arquitectura limpia). Descargamos los binarios en el pipeline y los corremos contra las clases compiladas. Así respetamos el `AGENTS.md` del repo.

**¿Puedo agregar más herramientas?**
Sí. Algunas opciones:
- **SonarCloud** (análisis continuo, gratis para OSS)
- **CodeQL** (security analysis de GitHub)
- **Snyk** (vuln scanning con mejor UX que OWASP)
- **Renovate** (actualización automática de dependencias, ya está configurado)

**¿Cómo deshabilito un job?**
En Azure: comenta el job en `azure-pipelines.yml`. En CircleCI: comenta el job en el `workflows` block.

**¿El pipeline falla si hay warnings?**
- Checkstyle: sí, hace fallar el build.
- Modernizer: sí (`failOnViolations=true`).
- SpotBugs: no (configurado con `continueOnError`).
- Dep-Check: solo falla si hay CVE con score ≥ 9.
