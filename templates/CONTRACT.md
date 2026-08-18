# CONTRACT.md — El contrato de variables del pipeline de calidad

> Esta es **LA API** de todo el template: las dos plantillas de CI (`circleci-config.yml`,
> `azure-pipelines.yml`), los tres scripts (`scripts/`) y los adapters (`adapters/`)
> hablan exactamente este idioma. Si una variable no está en esta tabla, no existe.

## 1. Tabla de variables (12)

| Variable | Requerida | Significado |
|---|---|---|
| `ECOSYSTEM` | **Sí** | Selecciona los defaults: `java` \| `python` \| `node` |
| `BUILD_CMD` | No | Instala/compila dependencias. Vacía = default del ecosistema; si el ecosistema no necesita build, dejarla vacía saltea el paso |
| `TEST_CMD` | **Sí** (única requerida además de `ECOSYSTEM`) | Corre los tests. **Tu `TEST_CMD` DEBE dejar JUnit XML en disco en `JUNIT_GLOB`** — es la única obligación real del repo adoptante |
| `JUNIT_GLOB` | No | Dónde caen los JUnit XML que produce `TEST_CMD` |
| `COVERAGE_CMD` | No | Genera el reporte de cobertura. Vacía = paso de coverage se salta |
| `COVERAGE_REPORT` | No | Path o glob del reporte de cobertura que produce `COVERAGE_CMD` |
| `TESTRAIL_URL` | No | Instancia completa CON esquema `https://` (ej: `https://xyz.testrail.io`). **Gate** de subida |
| `TESTRAIL_EMAIL` | No | Email de login en TestRail. **Gate** de subida |
| `TESTRAIL_KEY` | No | API key de TestRail (My Account > Local Settings > API keys). **Gate** de subida. **SECRETO** |
| `TESTRAIL_PROJECT` | No | Nombre del proyecto en TestRail. **No gatea**, pero si el gate pasó y está vacía → error claro + `exit 1` |
| `TESTRAIL_SUITE_ID` | No | ID numérico de la suite (innecesaria en proyectos single-suite) |
| `TESTRAIL_SECTION_ID` | No | Ancla las secciones/casos auto-creados bajo una sección padre existente (mitigación del anidamiento por FQCN) |

## 2. Gate de subida a TestRail

**SOLO** `TESTRAIL_URL` + `TESTRAIL_EMAIL` + `TESTRAIL_KEY` componen el gate — textualmente:
esas 3 y ninguna más.

- Cualquiera de las 3 vacía → `scripts/upload-testrail.sh` imprime **exactamente 1 línea**
  de skip y sale con `exit 0` (el job sigue verde; forks sin TestRail funcionan igual).
- Las 3 presentes → se sube. Si la subida falla, el script falla (hard fail a propósito:
  las desconfiguraciones tienen que salir a la luz, sin soft-fail).
- `TESTRAIL_PROJECT` / `TESTRAIL_SUITE_ID` / `TESTRAIL_SECTION_ID` **NO** gatean nada.
- Caso especial: gate pasado pero `TESTRAIL_PROJECT` vacía → error claro + `exit 1`
  (misconfig ruidosa, no silenciosa — un template genérico no puede tener proyecto default).

## 3. Regla de nombres — nombres exactos, cero alias

Los 12 nombres de la tabla son LA API. Este contrato **rechaza explícitamente** los alias:

- Las vars de conexión a TestRail NO tienen variante `_HOST` ni `_USER` — el par correcto
  es `_URL` + `_EMAIL` (mandan los nombres de esta tabla).
- Los env nativos de la herramienta CLI (`TRCLI_*`) tampoco forman parte del contrato:
  el script siempre pasa credenciales por flags explícitos (`-h`, `-u`, `-k`), que son
  self-documenting e idénticos en cualquier CI.
- Si en algún lado ves un nombre con el prefijo `TESTRAIL_` que no está en la tabla de
  arriba, es un bug — corregilo contra esta tabla antes de que se propague.

Un solo juego de nombres, definido acá y en ninguna otra parte.

## 4. Defaults por ecosistema

Los resuelve `scripts/setup-defaults.sh` con el patrón `: "${VAR:=default}"` —
lo que ya vino seteado NUNCA se pisa.

| Var | java | python | node |
|---|---|---|---|
| `BUILD_CMD` | `./gradlew assemble --no-daemon` | `python -m pip install -r requirements.txt` | `npm ci` |
| `TEST_CMD` | `./gradlew test --no-daemon` | `python -m pytest --junitxml=reports/junit.xml` | `npx jest --ci --reporters=default --reporters=jest-junit` |
| `JUNIT_GLOB` | `**/build/test-results/test/TEST-*.xml` | `reports/junit.xml` | `junit.xml` |
| `COVERAGE_CMD` | `./gradlew jacocoTestReport` | `coverage run -m pytest && coverage xml` | `npx jest --coverage` |
| `COVERAGE_REPORT` | `**/build/reports/jacoco/test/jacocoTestReport.xml` | `coverage.xml` | `coverage/lcov.info` |

`ECOSYSTEM` vacía o desconocida → error claro + `exit 1` (no hay adivinación silenciosa).

## 5. Canonicalización: `reports/junit/`

Todo XML que matchee `JUNIT_GLOB` se consolida en `reports/junit/` (paso a cargo de
`scripts/collect-junit.sh`), con nombres planos anti-colisión prefijados por módulo
(derivados del path original). Ese directorio es el **único** path que consumen:

- **CircleCI**: `store_test_results` — espera un **directorio**;
- **Azure Pipelines**: `PublishTestResults@2` con `testResultsFiles: 'reports/junit/*.xml'`
  — espera un **glob**;
- **trcli**: `upload-testrail.sh "reports/junit/*.xml"` — espera un path estable.

Esto resuelve la asimetría real entre CIs (una pide directorio, la otra glob). Los nombres
de archivo planos son irrelevantes para trcli y para los Tests tabs: lo que importa es el
contenido XML (`classname`/`name` vienen adentro de cada archivo).

## 6. Secrets

`TESTRAIL_EMAIL` y `TESTRAIL_KEY` (y toda credencial) se cargan como **secrets del CI**,
nunca escritas en el YAML:

- CircleCI: Project Settings → Environment Variables (o Contexts).
- Azure Pipelines: Pipelines → Library → variable groups con la opción *secret*, mapeadas
  en el pipeline como `TESTRAIL_KEY: $(TESTRAIL_KEY)` desde el grupo vinculado.

## 7. Pitfalls de persistencia — por qué existe `setup-defaults.sh`

Los `export` de bash NO sobreviven igual en cada CI:

1. **CircleCI**: una variable exportada en un `run:` muere al terminar el step → hay que
   escribir los `export` en `$BASH_ENV` (CircleCI lo sourcea al inicio de cada step).
   `setup-defaults.sh` lo hace automáticamente si detecta `CIRCLECI`.
2. **Azure Pipelines**: el comando de logging `##vso[task.setvariable variable=X]` aplica
   desde el step **SIGUIENTE**, no desde el actual. `setup-defaults.sh` lo emite por cada
   var si detecta `TF_BUILD`.
3. En ambos casos el script además hace `export` local e imprime las vars resueltas
   (depurabilidad: siempre podés ver qué defaults se aplicaron en el log).

Por eso ambas plantillas corren `setup-defaults.sh` como primer paso después del checkout.
