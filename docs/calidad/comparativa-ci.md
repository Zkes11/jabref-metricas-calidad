# ⚖️ Comparativa de plataformas CI: CircleCI vs Azure Pipelines vs GitHub Actions vs GitLab CI

Este documento compara las 4 plataformas de CI/CD SaaS más usadas, desde la perspectiva de **este proyecto**: un fork de JabRef (Java 25, Gradle multi-módulo) cuyo objetivo es correr **métricas de calidad** (tests + cobertura + análisis estático) y subirlas a TestRail. Jenkins aparece al final solo como referencia self-hosted.

> ⚠️ **AVISO — leelo antes de usar la tabla**: los datos de este documento fueron **verificados contra la documentación oficial de cada plataforma en agosto de 2026**. Precios, límites gratuitos y features de los CIs **cambian seguido** (CircleCI retiró su parsing de cobertura built-in entre 2025 y 2026, por ejemplo). **Verificá al momento de decidir** — los links oficiales están al pie de cada dato.

---

## 📊 La tabla grande

| Dimensión | CircleCI | Azure Pipelines | GitHub Actions | GitLab CI |
|---|---|---|---|---|
| **1. Ingesta de JUnit XML** | ✅ Nativo: `store_test_results` | ✅ Nativo: `PublishTestResults@2` | ❌ Sin soporte nativo — actions de terceros (`mikepenz/action-junit-report@v6`) | ✅ Nativo: `artifacts:reports:junit` |
| **2. UI de reportes de tests** | Tests tab + **Test Insights** (flaky, más fallan, más lentos) | Tests tab + analytics con **historia de runs** (la más rica) | Check run + **anotaciones en la línea exacta del PR**; sin historia/flaky analytics | Tests tab + resumen en MR con **diff de fallos nuevos vs existentes** |
| **3. Reportes HTML como artifacts** | ✅ Artifacts (ver/descargar) | ✅ Artifacts (navegar/descargar) | ⚠️ Descarga solamente (no se renderizan in-place) | ✅ Artifacts (navegar) |
| **4. Visualización de cobertura** | ➖ Built-in retirado → artifacts + orb de Codecov | ✅ **Code Coverage tab nativa** (JaCoCo) + diff de cobertura en PRs | ➖ Sin UI nativa (Codecov / actions de comentario) | ✅ Regex % + **anotaciones línea a línea en el diff del MR** (la mejor UX nativa) |
| **5. Mecanismos de reutilización** | **Orbs** (registry con semver / URL / inline) + commands + matrix | Templates YAML + variable groups | **Reusable workflows** (`workflow_call` cross-repo) + composite actions | `include:` (deep merge) + `extends` + components |
| **6. Manejo de secrets** | Env vars de proyecto + **Contexts** (org) | Secret vars + **variable groups** + Azure Key Vault | Secrets repo/org/**environment** + `GITHUB_TOKEN` efímero | Variables masked project/group/instance |
| **7. Tier gratuito (repos PRIVADOS)** | **30.000 créditos/mes** (~3.000 min en clase medium) + **30 jobs concurrentes** | **1.800 min/mes** + cap de **60 min por job** (1 job concurrente) | **2.000 min/mes** + 500 MB de artifacts (20 concurrentes) | **400 min/mes** (1 concurrente) — el más chico |
| **8. Soporte JDK 25** | ✅ Imagen Docker `cimg/openjdk:25.0` (sin fricción) | ⚠️ `ubuntu-latest` no trae JDK 25 → descarga manual de Temurin | ✅ `setup-java` con `temurin` `'25'` (documentado) | ✅ Docker-first: cualquier imagen (`cimg/openjdk`, Temurin) |

Celdas cortas a propósito — el porqué de cada fila va abajo.

---

## 🔍 Cada dimensión explicada

### 1. Ingesta de JUnit XML

Es **la** pregunta base de un proyecto de métricas: ¿la plataforma lee los XML que Gradle escribe en `build/test-results/test/TEST-*.xml` sin trabajo extra? CircleCI (`store_test_results: path:`), Azure (`PublishTestResults@2` con `testResultsFormat: 'JUnit'`) y GitLab (`artifacts:reports:junit:`) lo hacen nativamente. GitHub Actions **no tiene ingesta nativa de JUnit** (verificado agosto 2026): el estándar de la comunidad es el action de terceros `mikepenz/action-junit-report@v6`, que crea un check run en el PR y anota los fallos inline.

### 2. UI de reportes de tests

Las tres opciones nativas son buenas pero con fortalezas distintas: CircleCI suma **Test Insights** (detección de flaky tests, ranking de los que más fallan y de los más lentos — estadísticas genuinamente útiles para un proyecto de métricas); Azure tiene la **UI más rica** (outcome por test, duración, mensaje de error y stack trace completos, historia de runs); GitLab brilla en el **MR**: un panel que compara source vs target branch y separa fallos *nuevos* de *existentes*, con hint de flakiness ("falló N veces en el default branch en los últimos 14 días"). GitHub Actions compensa con lo que ningún otro hace tan bien: **anotar el fallo en la línea exacta del archivo** dentro del PR — ideal para quien revisa el código, pero sin historia ni analytics de flakiness.

### 3. Reportes HTML como artifacts

Todos los CIs dejan subir archivos (JaCoCo, Checkstyle, SpotBugs, Dep-Check en HTML), pero no todos los tratan igual: CircleCI y GitLab permiten verlos/navegarlos desde la UI; Azure los lista en un árbol navegable y descargable; GitHub Actions los sirve **solo como descarga** (decisión de seguridad: los sirve como attachments, no renderiza HTML arbitrario). Nuestro pipeline sube los 5 tipos de reporte como artifacts en los tres CIs vivos.

### 4. Visualización de cobertura

Acá hay una sorpresa reciente: **CircleCI retiró su parsing de cobertura built-in** (el feature de settings que leía lcov/info desapareció de la docs actuales). La guía oficial de hoy es: guardar los HTML/XML como artifacts y/o sumar **Codecov** (orb oficial). Azure tiene la mejor historia nativa sin terceros: `PublishCodeCoverageResults@2` consume el summary XML de JaCoCo, renderiza la **pestaña Code Coverage**, genera el HTML él mismo y calcula **diff de cobertura en PRs** (con el requisito de `pathToSources` que ya descubrimos en este repo). GitLab tiene la mejor UX *dentro del MR*: anotaciones de cobertura línea a línea directamente en el diff. GitHub Actions no tiene UI nativa — Codecov o actions de comentario.

### 5. Mecanismos de reutilización

Para "un pipeline genérico que otro repo adopta", cada plataforma ofrece su mecanismo: CircleCI tiene **orbs** en tres sabores (registry con versionado semántico, **URL orbs** — un YAML crudo en una HTTPS URL, cero overhead de publicación — e inline); Azure tiene **templates** YAML con parámetros (poderosos pero más toscos de escribir, y cross-org significa referenciar una URL cruda de GitHub); GitHub Actions tiene el mecanismo más frictionless de la industria: **reusable workflows** (`on: workflow_call`) — el repo consumidor escribe ~5 líneas (`uses: org/repo/.github/workflows/quality.yml@v1`) y el versionado por git tags viene gratis; GitLab tiene `include:` con deep merge y los más nuevos **CI/CD components**, muy fuertes *dentro de una misma instancia* de GitLab pero débiles cross-forge (`include:project` no sale de tu instancia). Nota: este proyecto eligió **templates copy-paste** como mecanismo — el detalle está en el [ADR-0070](../decisions/0070-testrail-pipeline-generico.md) y en [`templates/README.md`](../../templates/README.md).

### 6. Manejo de secrets

Los cuatro manejan secrets correctamente; la diferencia es el alcance y los extras. CircleCI: env vars de proyecto + **Contexts** (grupos compartidos a nivel organización). Azure: variables secretas del pipeline + **variable groups** (biblioteca compartida entre pipelines) con opción de respaldarlas en **Azure Key Vault** — la historia enterprise más fuerte. GitHub Actions: secrets a nivel repo/org/**environment** (los environments con required reviewers son una feature gratuita ideal para proteger credenciales de TestRail) + el `GITHUB_TOKEN` efímero con `permissions:` granulares. GitLab: variables masked+protected a nivel proyecto/grupo/instancia.

### 7. Tier gratuito en repos PRIVADOS

El punto que más duele cuando el repo es privado (como este fork):

- **CircleCI**: 30.000 créditos/mes ≈ **3.000 minutos** en la clase `medium` (10 créditos/min) — el mayor presupuesto práctico — y **30 jobs concurrentes** (nuestros 3 jobs corren en paralelo de una).
- **Azure Pipelines**: 1 job gratuito = **1.800 min/mes** con **cap de 60 minutos POR JOB** — un run completo de tests de JabRef se acerca a ese cap, por eso el pipeline está partido en 3 jobs y no hay que consolidarlos nunca. Requiere vincular una suscripción de Azure para billing.
- **GitHub Actions**: **2.000 min/mes** + 500 MB de artifacts. En repos **públicos los runners estándar son ilimitados y gratis** — el punto decisivo si el fork se hiciera público algún día.
- **GitLab CI**: **400 min/mes** — por lejos el más chico; un build+test completo de JabRef lo agota en 2-3 pipelines.

Ojo con Azure en público: los **public projects de Azure DevOps se están retirando** (convierten a privados en 2027) — no construyas sobre CI gratis pública ahí.

### 8. Soporte JDK 25

JabRef exige JDK 25, y no todas las plataformas lo sirven fácil: CircleCI es el camino más corto — la imagen Docker `cimg/openjdk:25.0` existe verificada (amd64 + arm64) y nuestro `.circleci/config.yml` ya la usa; GitHub Actions es el segundo más fácil (`actions/setup-java` con `distribution: temurin, java-version: '25'`, documentado y cacheable); GitLab es Docker-first, así que cualquier imagen con JDK 25 sirve; Azure es el más friccional — `ubuntu-latest` **no** trae JDK 25, y nuestro pipeline lo resuelve descargando Temurin 25 vía la API de Adoptium (~30-60 s por job; cacheable si llega a molestar).

### 🏗️ Y Jenkins (referencia self-hosted)

Jenkins es la opción **self-hosted**: gratis e ilimitado en minutos (corre en tu hardware), con el JUnit plugin original (reportes por build + **gráficos de tendencia histórica**) y el plugin JaCoCo con umbrales de pass/fail. El costo real es de **mantenimiento** (upgrades, drift de plugins, seguridad) y tiene un gotcha clásico: el sandbox CSP de Jenkins **rompe los charts de los HTML reports** publicados con HTML Publisher (JaCoCo incluido) hasta que un admin relaja la política. Para un proyecto de curso sin infraestructura propia, no compite contra los SaaS — pero es la respuesta correcta cuando "sin límite de minutos" es el requisito.

---

## ⚠️ Alcance de este documento

**GitHub Actions y GitLab CI están acá SOLO como comparación y documentación** — este proyecto **NO los implementa**. El límite es deliberado: el fork no debe tocar `.github/` (política del repo upstream) y GitLab no está en el stack. La única implementación viva de este proyecto son **CircleCI** (`.circleci/config.yml`) y **Azure Pipelines** (`azure-pipelines.yml`).

---

## 🏆 Veredicto para ESTE proyecto

### CircleCI como PRIMARIO

- **JDK 25 sin fricción**: la imagen `cimg/openjdk:25.0` ya está en uso — cero pasos extra por job.
- **30 jobs concurrentes gratuitos**: los 3 jobs del pipeline (`build_test` / `quality` / `static_analysis`) corren en paralelo real.
- El mayor presupuesto práctico del tier privado: ~3.000 min medium/mes ≈ **15-20 pipelines completos por mes**.
- **Tests tab + Test Insights**: flaky tests, ranking de fallos y de lentitud — estadísticas que alimentan justo lo que un proyecto de métricas quiere mostrar.
- Única deuda: la cobertura porcentual en UI ya no es nativa (feature retirado) → los HTML de JaCoCo viven como artifacts; si algún día se quiere el % en UI, re-agregar el orb de Codecov.

### Azure Pipelines como SECUNDARIO

- **La mejor UI de reporting nativa del mercado** (Tests tab + Code Coverage tab + diff de cobertura en PRs): ideal para "lucir" las métricas sin servicios de terceros.
- Respetando sus dos límites duros: **cap de 60 min por job** (mantener el split en 3 jobs — jamás consolidar build+test+análisis en uno) y **1.800 min/mes** con 1 job concurrente.
- El costo de la descarga manual de Temurin (~30-60 s/job) es aceptable.

### ¿Cuándo convendría otra?

- **GitHub Actions** si (a) el fork se hiciera **público** → minutos ilimitados gratis, o (b) importaran las **anotaciones en la línea exacta del PR** al revisar código. Sería ~1 día de trabajo (`setup-java` + mikepenz report + upload-artifact).
- **GitLab CI** solo si el proyecto llegara a vivir en GitLab — con 400 min/mes no alcanza para el ritmo de este repo.

---

## 📚 Fuentes

Datos verificados contra documentación oficial el **17 de agosto de 2026**:

- CircleCI: [Collect test data](https://circleci.com/docs/guides/test/collect-test-data/) · [Code coverage (guía actual)](https://circleci.com/docs/guides/test/code-coverage/) · [Orbs](https://circleci.com/docs/orbs/use/orb-intro/) · [Pricing](https://circleci.com/pricing/) · [cimg/openjdk tags](https://hub.docker.com/r/cimg/openjdk/tags)
- Azure Pipelines: [PublishTestResults@2](https://learn.microsoft.com/en-us/azure/devops/pipelines/tasks/reference/publish-test-results-v2) · [PublishCodeCoverageResults@2](https://learn.microsoft.com/en-us/azure/devops/pipelines/tasks/reference/publish-code-coverage-results-v2) · [Parallel jobs / free tier](https://learn.microsoft.com/en-us/azure/devops/pipelines/licensing/concurrent-jobs)
- GitHub Actions: [Reusable workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows) · [Billing](https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions) · [mikepenz/action-junit-report](https://github.com/mikepenz/action-junit-report) · [setup-java avanzado](https://github.com/actions/setup-java/blob/main/docs/advanced-usage.md)
- GitLab CI: [Unit test reports](https://docs.gitlab.com/ee/ci/testing/unit_test_reports.html) · [Code coverage](https://docs.gitlab.com/ee/ci/testing/code_coverage.html) · [include](https://docs.gitlab.com/ee/ci/yaml/includes.html) · [Compute minutes](https://docs.gitlab.com/ee/ci/pipelines/compute_minutes.html)
- Jenkins: [JUnit plugin](https://github.com/jenkinsci/junit-plugin)

> ⚠️ Recordatorio final: precios y features cambian seguido — **verificá al momento de decidir**.
