# 👀 Guía de lectura de resultados: ¿dónde miro qué?

La pregunta que responde esta guía es la más común cinco minutos después de pushear: **"acabo de pushear — ¿dónde miro qué?"** Este proyecto tiene tres lugares donde aterrizan resultados, y cada uno responde preguntas distintas:

- **CircleCI** → muestra **ESTE build** (efímero, por-push)
- **Azure Pipelines** → muestra **ESTE build** (efímero, por-push) — con la mejor UI de reporting
- **TestRail** → acumula **TODOS los builds** (persistente, con historia)

**Ninguno reemplaza al otro.** Los CIs te dicen "¿qué pasó hoy?"; TestRail te dice "¿cómo viene evolucionando este test?". Si te quedás con una sola idea de esta guía, que sea esa.

---

## 🟢 CircleCI — el build de hoy

Cada push dispara un pipeline con 3 jobs; el que importa para resultados de tests es `build_test`. Ahí tenés tres vistas:

- **Pestaña Tests** (del job): qué pasó en ESTE build — pass/fail/skip **por test**, con duraciones. Es la vista "cirujano": test exacto, mensaje de error, tiempo que llevó.
- **Test Insights** (a nivel de proyecto): estadísticas dentro del propio CircleCI — **flaky tests** (fallan a veces), los que más fallan, **los más lentos**, duración histórica por test. Es lo más parecido a "analytics" que un CI te da nativo.
- **Artifacts**: los reportes HTML (JaCoCo, Checkstyle, SpotBugs, Dep-Check) de ese build, para abrir o descargar.

El límite de CircleCI para nuestra pregunta: **cada build es su propia burbuja**. La historia profunda de un test ("¿este test viene fallando hace 3 builds?") no es su fuerte — para eso está TestRail.

## 🔵 Azure Pipelines — el build de hoy, con la mejor vitrina

Azure corre los mismos 3 jobs (`Build_Test`, `Quality`, `Static_Analysis`) y aporta:

- **Pestaña Tests** (del job `Build_Test`): lo publica `PublishTestResults@2` — outcome por test, duración, **mensaje de error y stack trace completos** (el mapeo JUnit XML → UI es el más detallado del mercado).
- **Pestaña Code coverage**: JaCoCo renderizado nativo, **con diff de cobertura en PRs** — sin servicios de terceros.
- **Artifacts**: los mismos reportes HTML, navegables y descargables.

Misma limitación que CircleCI: es la foto del build actual, no la película.

## ⚠️ EL CAVEAT de Azure: verde ≠ todo pasó

Antes de leer cualquier job de Azure en este repo, grabate esto:

> **Un job VERDE puede tener tests fallidos.** Es semántica **intencional**, no un bug: los steps de tests y JaCoCo usan `continueOnError: true`, y `PublishTestResults@2` tiene `failTaskOnFailedTests: false`. La postura es "siempre recolectar reportes": aunque los tests fallen, el pipeline junta los XML, la cobertura y los artifacts para que puedas inspeccionarlos.

Cómo no leerlo mal: el semáforo del job dice **"el pipeline recolectó todo lo que tenía que recolectar"**, no "todos los tests pasaron". Los fallos reales se ven en:

1. la **pestaña Tests** del build (cada test con su stack trace), y
2. **TestRail** (el resultado del caso queda en Failed).

Más detalle en la FAQ del [README](README.md) ("¿Por qué el pipeline de Azure se ve verde…?") y en los comentarios `⚠️ SEMÁNTICA INTENCIONAL` del propio [`azure-pipelines.yml`](../../azure-pipelines.yml).

## 🧷🚀 TestRail — el acumulado

TestRail es la capa que **ningún CI da**: la historia. Los conceptos para leerlo:

- **Run** = una subida. Cada build que sube resultados crea un run **cerrado** (inmutable, estado Completed). El título identifica el origen — el script lo arma según el CI que lo disparó:
  - `CircleCI #<N> (<rama>) — <fecha>`
  - `Azure Pipelines #<N> (<rama>) — <fecha>`
- **Casos** = la definición de cada test. Se auto-crean (o matchean) por `automation_id` = `classname.name` — el nombre completo del test en Java (ej: `org.jabref.logic.util.BuildInfoTest.testBuildInfo`). El caso es duradero; los runs le van adjuntando resultados.
- **Historia de resultados por caso** = la killer feature. "¿Este test viene fallando hace 3 builds?" se responde abriendo el **caso** en TestRail y mirando su historia de resultados — algo que ningún CI de este proyecto te muestra.
- **Estados**: Passed / Failed / Blocked / **Retest**. Aclaración del mapeo default de trcli: los tests **skipped llegan como Retest** (no como "no corrido") — detalle documentado en la [guía de setup, §5(a)](testrail-setup-circleci.md), con la receta para cambiarlo si molesta. Los IDs internos: 1=Passed, 4=Retest, 5=Failed.

**Cómo leer un run paso a paso:**

1. Abrí TestRail → **Test Runs & Results** — vas a ver la lista de runs, mezclados los de CircleCI y Azure (se distinguen por el título).
2. Abrí el run del build que te interesa — el título te dice CI, número de build, rama y fecha.
3. Adentro, los resultados agrupados en **secciones por clase de test** (las secciones se crean desde el FQCN de cada suite de tests).
4. Abrí cualquier resultado: un fallo lleva el **mensaje y stack trace como comentario** del resultado — misma info que la pestaña Tests del CI, pero acumulada.

---

## 🗺️ Tabla "¿Dónde miro qué?"

| Pregunta | Dónde mirar |
|---|---|
| ¿Pasó el build? | El semáforo del CI (⚠️ con el caveat de Azure: verde no garantiza tests verdes) |
| ¿Por qué falló ESTE test? | Pestaña Tests del build (CircleCI o Azure), o el resultado del caso en TestRail — ambos con stack trace |
| ¿Cómo evoluciona este test en el tiempo? | **TestRail**: abrí el caso y mirá su historia de resultados |
| ¿Es flaky este test? | CircleCI **Test Insights** / historia de resultados del caso en TestRail (verás Passed y Failed alternados) |
| ¿Cuál es la cobertura? | Pestaña **Code coverage** de Azure / artifacts JaCoCo de cualquiera de los dos CIs |
| ¿El estado general de la calidad? | Reports de TestRail (pass rate, hotspots de fallo) + el [resumen ejecutivo](resumen-ejecutivo.md) del proyecto |

---

## 🔀 Por qué ambos CIs apuntan al mismo proyecto TestRail

Cada CI aporta runs **distinguibles por título** (`CircleCI #…` vs `Azure Pipelines #…`), así el mismo proyecto TestRail acumula la historia de ambas plataformas — podés comparar si un fallo se ve en las dos (bug real) o solo en una (sospecha de entorno).

Una advertencia operativa: TestRail Cloud limita la API a **180 requests/minuto**. trcli batchea (de a 50) y reintenta solo, pero conviene **evitar disparar uploads simultáneos de ambos CIs con el mismo push** cuando sea posible (por ejemplo, no re-corras a mano el pipeline de Azure justo cuando está subiendo el de CircleCI). Si igualmente aparece un HTTP 429, es esto — esperá un minuto y re-intentá.

---

## 🔗 Links relacionados

- [Setup de TestRail (CircleCI + Azure)](testrail-setup-circleci.md) — el checklist completo de configuración
- [Comparativa de plataformas CI](comparativa-ci.md) — por qué este proyecto usa estos dos CIs
- [README de calidad](README.md) — el hub, con la FAQ (incluido el caveat del verde de Azure)
- El paso en cada pipeline: `🧷 Subir resultados a TestRail` en [`.circleci/config.yml`](../../.circleci/config.yml) y `🚀 Subir resultados a TestRail` en [`azure-pipelines.yml`](../../azure-pipelines.yml) — ambos llaman al mismo `scripts/upload-testrail.sh`
