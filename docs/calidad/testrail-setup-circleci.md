# 🧷 TestRail: setup e integración con CircleCI

Esta guía te lleva de cero a tener los resultados de los tests de JabRef acumulándose en **TestRail**, subidos automáticamente por los pipelines de CircleCI **y de Azure Pipelines** (§9) — mismo script, mismo gate. Está pensada para alguien que nunca usó TestRail: no hace falta escribir código, solo seguir el checklist en orden.

Qué vas a conseguir al terminar:

- Un **run cerrado** en TestRail por cada build de CircleCI, con un caso por test de la suite.
- Casos **auto-creados** con su `automation_id` (el nombre completo del test en Java).
- Un pipeline que **sigue verde para todos los que no configuran TestRail** (skip limpio).

---

## 📚 1. ¿Qué es TestRail?

TestRail es una plataforma comercial de **gestión de casos de test** (test case management) de Gurock/SmartBear. Importante: TestRail **no ejecuta tests** — eso lo sigue haciendo Gradle/JUnit en el CI. TestRail **guarda, organiza y reporta** los resultados (manuales y automatizados) en un solo lugar.

El modelo mental es una jerarquía de objetos:

```text
Instancia (https://xyz.testrail.io)
└── Proyecto                     ← uno por producto/repo (ej: "jabref-metricas")
    ├── Test Suites              ← contenedores de casos; el "suite mode" se elige al
    │   │                           crear el proyecto (single suite = el más simple)
    │   └── Secciones (árbol)    ← carpetas, generalmente reflejando paquetes/clases
    │       └── Casos de test    ← la unidad "qué probar", con ID tipo C123
    ├── Milestones               ← agrupación opcional (sprints, releases)
    └── Test Runs                ← una ejecución de un conjunto de casos
        └── Tests                ← la copia del caso dentro del run
            └── Resultados       ← historia de estados: Passed/Failed/Blocked/Retest,
                                  ← duración, comentarios, adjuntos
```

Concepto clave: un **caso** es la definición duradera del test; un **run** contiene *tests* (copias de casos) y cada test acumula **resultados** en el tiempo. La CLI que usamos crea un **run nuevo por subida** y le adjunta los resultados.

**¿En qué se diferencia del CI?** CircleCI (o Azure) muestra el *último* build: "¿pasó o no pasó?". TestRail **acumula la historia**: evolución del pass rate, zonas del código que más fallan, tests flaky (fallan a veces) detectables por su historia de resultados. Son complementarios, no reemplazos.

---

## 🔌 2. Qué integramos

Un paso nuevo al final del job `build_test` de CircleCI:

```text
job build-test (CircleCI)
   │  🧪 Tests unitarios (Gradle → JUnit XML por módulo)
   │  📦 Consolidar reportes → ~/reports/test-results/test/TEST-*.xml
   ▼
🧷 Subir resultados a TestRail
   │  bash scripts/upload-testrail.sh "$HOME/reports/test-results/test/TEST-*.xml"
   │  → instala trcli (pin de versión) y corre: trcli ... parse_junit
   ▼
TestRail: run cerrado (estado Completed) con un resultado por test
```

El paso corre con `when: always`, así que **sube también los resultados cuando hay tests fallidos** (ver los fallos en TestRail es justo el punto).

**El gate**: el script solo intenta subir si `TESTRAIL_URL`, `TESTRAIL_EMAIL` y `TESTRAIL_KEY` están configuradas. Si falta cualquiera, imprime **una sola línea** de skip y sale con `exit 0` — el job queda verde. Por eso los forks (o corridas locales) sin TestRail siguen funcionando igual.

---

## ✅ 3. Checklist de setup (una sola vez, en este orden)

> ⚠️ **El orden importa.** La API (paso 2) tiene que estar habilitada antes de cualquier llamada, y el campo `automation_id` (paso 4) tiene que existir **antes de la primera subida** — si no, el matching de casos degrada y se duplican. Seguí los pasos al pie de la letra.

### Paso 1 de 7 — Crear la cuenta trial (30 días, sin tarjeta)

1. Andá a <https://www.testrail.com/trial/> y apretá **Start free trial**.
2. Completá nombre, email de trabajo, empresa y país → enviar.
3. Te llega un **código de verificación de 6 dígitos** por email (podés pedir uno nuevo si expira) → ingresalo.
4. Elegí el **nombre de tu instancia**; TestRail la provisiona como `https://<tu-instancia>.testrail.io` y te redirige ahí.
5. Logueate con el email/contraseña que creaste. Ya sos administrador de la instancia.

👉 Esa URL de la instancia es tu futura `TESTRAIL_URL` (con `https://` incluido).

> 📸 *Screenshot acá: formulario de signup y/o email con el código de 6 dígitos (guardala en `docs/calidad/img/`)*

### Paso 2 de 7 — Habilitar la API

**Administration → Site Settings → API → tildar "Enable API"** → Save.

Sin esto, **toda** llamada a la API falla (es la causa #1 de errores 401 recién arrancado).

> 📸 *Screenshot acá: Site Settings → API con el checkbox tildado*

### Paso 3 de 7 — Crear el proyecto `jabref-metricas` (single suite)

1. Desde el dashboard: **Add Project**.
2. Nombre: `jabref-metricas` (tiene que coincidir con `TESTRAIL_PROJECT` del paso 6).
3. **Suite mode: single suite mode** ("una sola suite"). Es el modo más simple y evita tener que pasar `--suite-id` obligatoriamente.

> 📸 *Screenshot acá: formulario de proyecto con el suite mode elegido*

### Paso 4 de 7 — Crear el campo custom `automation_id`

**Administration → Customizations → Case Fields → Add Field**, con:

- **Type**: Text
- **System name**: `automation_id`

¿Por qué? El *case matcher* `auto` de la CLI computa `classname.name` de cada test del XML (ej: `org.jabref.logic.util.BuildInfoTest.testBuildInfo`) y matchea/crea los casos de TestRail contra ese campo. Sin el campo, el matching degrada y los casos se duplican.

> ⚠️ Este campo debe existir **antes de la primera subida**.

> 📸 *Screenshot acá: alta del campo con Type=Text y System name=automation_id*

### Paso 5 de 7 — Generar la API key

1. Click en tu **avatar → My Account → Local Settings → API keys → Add API key**.
2. Nombrale `circleci` (para saber para qué es y poder revocarla sola después).
3. **Copiala apenas se genera**: se muestra una sola vez.

👉 Esta key es tu futura `TESTRAIL_KEY`. La API key es preferible a la contraseña: se revoca independientemente y es la práctica documentada para CI.

> 📸 *Screenshot acá: lista de API keys con la key "circleci" recién creada*

### Paso 6 de 7 — Configurar las 5 variables en CircleCI

**CircleCI → tu proyecto → Project Settings → Environment Variables → Add Variable**, una por una:

| Variable | Ejemplo | ¿Secreto? |
|---|---|---|
| `TESTRAIL_URL` | `https://jabref-metricas.testrail.io` | No |
| `TESTRAIL_EMAIL` | `santiago@ejemplo.com` (tu email de login) | No |
| `TESTRAIL_KEY` | *(la API key del paso 5)* | **Sí** 🔒 |
| `TESTRAIL_PROJECT` | `jabref-metricas` | No |
| `TESTRAIL_SUITE_ID` | `1` (el típico en un proyecto single-suite) | No |

Nota: solo `TESTRAIL_URL` / `TESTRAIL_EMAIL` / `TESTRAIL_KEY` forman el **gate** (sin las tres → skip limpio). `TESTRAIL_PROJECT` tiene default en el script y `TESTRAIL_SUITE_ID` es opcional en modo single-suite. Nunca commitees la key: vive solo en CircleCI.

> 📸 *Screenshot acá: lista de las 5 variables ya cargadas en CircleCI*

### Paso 7 de 7 — Disparar el pipeline y ver el run

1. Dispará el pipeline: hacé un push a `main`, o en CircleCI abrí el último workflow → **"Rerun workflow from start"**.
2. Seguí el job `build-test`: el paso 🧷 corre justo después de 📦 Consolidar.
3. Cuando termina, abrí TestRail → **Test Runs & Results** → debe haber un run titulado `CircleCI #<N> (<rama>) — <fecha>`.

> 📸 *Screenshot acá: el run apareciendo en Test Runs & Results*

---

## 👀 4. Cómo leer el primer run

- **Estado**: el run queda **cerrado** (Completed) porque el script pasa `--close-run` — cada build es un run inmutable.
- **Título**: `CircleCI #<número> (<rama>) — <fecha>`, con el link del build en la descripción.
- **Casos**: la primera subida **auto-crea** un caso por test de la suite, con `automation_id` = nombre completo (`classname.name`), ej: `org.jabref.logic.util.BuildInfoTest.testBuildInfo`.
- **Secciones**: se crean a partir del nombre de clase de cada XML (una sección por clase, posiblemente anidadas por paquete — es justo una de las cosas a observar en el smoke test).
- **Resultados**: Passed para los que pasaron; los fallos llevan el mensaje y stack trace como comentario del resultado.

> ⏳ **La primera subida es LENTA y está bien que lo sea**: auto-crea ~miles de casos en un solo paso (cifras oficiales: ~2.000 casos ≈ 460 s, unos 8 minutos). **No canceles el job.** Las siguientes subidas solo agregan resultados y son mucho más rápidas.

---

## 🧪 5. Smoke test — checklist de observaciones

Cosas que conviene mirar del primer run real y anotar acá (los defaults teóricos están en la guía, pero conviene verificarlos con nuestros datos). **Estado inicial: pendiente de la primera corrida real.**

- [ ] **(a) Tests skipped** → ¿qué estado muestran en TestRail?
  - Default esperado según la documentación: **Retest** (mapeo `skipped → Retest` de trcli).
  - Observado: **Pendiente de observar**
- [ ] **(b) Anidación de secciones desde FQCN con puntos** → ¿queda anidada por paquete (`org > jabref > logic > …`), plana, o con problemas?
  - Observado: **Pendiente de observar**
- [ ] **(c) Opcional: títulos largos de tests parametrizados** → ¿se truncaron o rechazaron por el largo?
  - Observado: **Pendiente de observar**

### Si algo sorprende (mitigaciones ya preparadas)

**(a) Querés que los skipped cuenten como Untested en vez de Retest.**
trcli permite sobreescribir el mapeo de estados con un archivo de config. Ejemplo (`skipped: 3` fuerza Untested; los IDs son 1=Passed, 2=Blocked, 3=Untested, 4=Retest, 5=Failed):

```yaml
# trcli-config.yml — solo el override de estados (no pongas credenciales acá)
case_result_statuses:
  passed: 1
  failure: 5
  error: 5
  skipped: 3
```

Se pasa con `trcli -c trcli-config.yml ...`. Por ahora dejamos el default; si el smoke test sorprende y querés cambiarlo, se documenta la decisión en esta sección.

**(b) Las secciones quedaron raras por los puntos del FQCN.**
Creá (o elegí) una sección padre "Automated" en TestRail, abrila y tomá su **ID numérico de la URL** (el número al final, sin la letra). Después agregá en CircleCI la variable:

```text
TESTRAIL_SECTION_ID = <ese número>
```

El script ya la soporta: cuando la variable existe, agrega `--section-id` y ancla **todas** las secciones/casos auto-creados bajo esa sección padre, dejando el resto del proyecto limpio.

---

## 🍴 6. Sin credenciales (forks y corridas locales)

Si `TESTRAIL_URL`, `TESTRAIL_EMAIL` o `TESTRAIL_KEY` no están configuradas, el paso 🧷 imprime exactamente esta línea en el log:

```text
>> TestRail: credenciales no configuradas (TESTRAIL_URL/TESTRAIL_EMAIL/TESTRAIL_KEY) — omitiendo subida / upload skipped
```

y sale con `exit 0`, así que el job (y el pipeline) queda **verde**. Esto es a propósito: cualquiera puede forkear el repo y correr el pipeline sin tener TestRail. Solo quien configure las tres variables de gate "opta in" a la subida.

---

## 🔧 7. Mantenimiento

- **Renombraste o moviste un test** → su `automation_id` (`classname.name`) cambia → la próxima subida crea un caso **nuevo** y el viejo queda huérfano con historia vieja. Es el comportamiento documentado.
- **Tras un refactor grande**: se puede correr una subida con `--update-existing-cases yes` para actualizar los campos de los casos existentes desde las properties del XML.
- **Limpieza periódica**: revisar de vez en cuando los casos huérfanos desde la UI de TestRail.
- **Versión de trcli**: está pineada (`TRCLI_VERSION` en `scripts/upload-testrail.sh`). Subirla es una decisión deliberada: cambiás el pin, re-corres el pipeline y verificás con un smoke test que todo siga igual.

---

## ⏳ 8. Qué pasa cuando el trial expira (día 30)

El trial dura **30 días** (sin tarjeta). Cuando expira, la API se corta. Con las variables `TESTRAIL_*` todavía configuradas en CircleCI, el paso 🧷 **falla el job** (hard fail, por diseño: preferimos ver el problema antes que perder datos de calidad en silencio).

**Solución documentada (manual, a propósito):** borrá `TESTRAIL_URL`, `TESTRAIL_EMAIL` y `TESTRAIL_KEY` de CircleCI (Project Settings → Environment Variables) → el script vuelve al skip limpio de la sección 6 y el pipeline queda verde. La decisión de renovar/comprar queda fuera del alcance de este proyecto.

---

## ☁️ 9. Azure Pipelines: las mismas variables, otro mecanismo

Azure Pipelines también sube sus resultados a TestRail — **con el MISMO script y el MISMO gate** que CircleCI (§2). Lo único que cambia es cómo se configuran los secrets.

### Qué existe en Azure

El paso `🚀 Subir resultados a TestRail` en el job `Build_Test`, inmediatamente después de `📤 Publicar resultados de tests`, leyendo el mismo glob de XMLs:

```text
job Build_Test (Azure Pipelines)
    │  🧪 Tests unitarios (Gradle → JUnit XML por módulo)
    │  📤 PublishTestResults@2 ('**/build/test-results/test/TEST-*.xml')
    ▼
🚀 Subir resultados a TestRail
    │  bash scripts/upload-testrail.sh "**/build/test-results/test/TEST-*.xml"
    │  → mismo script, mismo gate, mismo trcli que en CircleCI
    ▼
TestRail: run cerrado titulado "Azure Pipelines #<id> (<rama>) — <fecha>"
```

Como en CircleCI, el paso corre siempre (`condition: always()`) — **sube también cuando hay tests fallidos** — y sin las tres variables de gate configuradas imprime una línea de skip y sale `0`.

### Por qué el paso mapea `env:`

Azure DevOps **NO inyecta automáticamente las variables SECRETAS como variables de entorno** de los scripts (sí lo hace con las no-secretas). Por eso el paso del YAML declara un bloque `env:` que mapea cada variable explícitamente (`TESTRAIL_KEY: $(TESTRAIL_KEY)`): la macro `$(...)` se expande del lado del servidor y el valor secreto **llega al proceso sin aparecer en los logs**. Es el patrón canónico de Azure para secrets en scripts (el mismo `azure-pipelines.yml` ya lo usa para `GRADLE_USER_HOME`).

¿Y las 5 líneas `TESTRAIL_*: ''` del bloque `variables:` del YAML? Existen **solo para que un fork sin configuración tenga un skip limpio**: si `$(TESTRAIL_URL)` no existiera en ningún lado, la macro quedaría como el string literal `"$(TESTRAIL_URL)"` (NO vacío) y el gate del script no saltaría. Con el default vacío, el fork expande a string vacío → gate → skip → job verde por construcción.

### Opción A — Variable group (recomendada)

Un **variable group** es una biblioteca de variables compartida que vive fuera del YAML y se vincula al pipeline:

1. (Opcional, primero) Crear el grupo: **Pipelines → Library → + Variable group**, nombre sugerido `testrail`.
2. **Pipelines → tu pipeline → Edit → Variables → Variable groups → Link variable group** → elegir el grupo.
3. Dentro del grupo, crear las 5 variables con los MISMOS nombres exactos:

   | Variable | Ejemplo | ¿Secreta? |
   |---|---|---|
   | `TESTRAIL_URL` | `https://jabref-metricas.testrail.io` | No |
   | `TESTRAIL_EMAIL` | `santiago@ejemplo.com` | No |
   | `TESTRAIL_KEY` | *(la API key del paso 5 del checklist)* | **Sí** 🔒 (candado "secret") |
   | `TESTRAIL_PROJECT` | `jabref-metricas` | No |
   | `TESTRAIL_SUITE_ID` | `1` | No |

**Ventajas**: un solo lugar para rotar la key (cambiás el valor una vez y todos los pipelines vinculados lo ven), reutilizable entre pipelines, y los valores viven fuera del git para siempre.

### Opción B — Variables del pipeline

Más rápido si tenés un solo pipeline: **Pipelines → tu pipeline → Edit → Variables → New variable**, cargando los mismos 5 nombres. En `TESTRAIL_KEY` tildá **"Keep this value secret"** (el candado 🔒) — es lo que activa la redacción en logs y la necesidad del bloque `env:`.

### Regla de oro

**Nunca pongas valores reales en `azure-pipelines.yml`.** Las 5 líneas `TESTRAIL_*: ''` del bloque `variables:` quedan siempre como están (vacías); los valores reales viven en el variable group o en la UI del pipeline. El archivo está commiteado — cualquier valor que pongas ahí lo ve todo el mundo con acceso al repo.

### Cómo validar

- **Sin grupo vinculado**: cualquier push que toque `azure-pipelines.yml` dispara un run — el paso 🚀 imprime la línea de skip y el job queda **verde**. Ese camino se puede ver gratis, sin credenciales.
- **Con grupo vinculado**: al correr el pipeline, en TestRail → **Test Runs & Results** aparece un run titulado `Azure Pipelines #<id> (<rama>) — <fecha>`, distinguible de los de CircleCI por el título.

> ⚠️ **Nota del checkpoint pendiente**: la validación **en vivo** (con subida real a TestRail) requiere la cuenta trial del paso 1 del checklist — el mismo checkpoint pendiente de la Phase 1. Cuando esa cuenta exista, **el MISMO checklist sirve para ambos CIs**: el paso ya está cableado en CircleCI (🧷) y en Azure (🚀); solo falta configurar las variables en cada plataforma y disparar un pipeline.

### Trial expiry

Aplica igual que en §8: vencido el trial, la API se corta y el paso 🚀 **falla el job** (hard fail por diseño). Solución: borrá las 3 variables de gate del grupo/UI → el script vuelve al skip limpio y el pipeline queda verde.

---

## 🚑 10. Troubleshooting

| Síntoma | Causa | Solución |
|---|---|---|
| `!! TESTRAIL_URL debe incluir el esquema https://` | La URL no tiene esquema (trcli valida y rechaza hosts sin `https://`) | Seteá `TESTRAIL_URL` completa: `https://<instancia>.testrail.io` |
| `Got unexpected extra argument` | El glob se pasó sin comillas y el shell lo expandió antes que trcli | El script ya lo cita; si lo invocás a mano, pasá el glob **entre comillas** |
| El job queda colgado en trcli sin error | Falta `-y` → trcli espera confirmación interactiva por teclado | Ya está en el script (`trcli -y`); no lo saques |
| HTTP 401 / credenciales inválidas | API deshabilitada en la instancia (paso 2) o email/key mal cargados | Verificá "Enable API" y regenerá/verificá la key (paso 5) |
| Casos duplicados en TestRail | Renombraste/moviste tests (cambia el `automation_id`) | `--update-existing-cases yes` tras refactors + limpieza (sección 7) |
| HTTP 429 (rate limit) | Límite de la nube (180 req/min en el plan Professional) | trcli batchea de a 50 y reintenta solo; si persiste, esperá un poco |
| La primera subida tarda ~8 min | Auto-crea ~miles de casos (2.000 ≈ 460 s según cifras oficiales) | Paciencia — **no canceles el job**; las siguientes son rápidas |
| Vinculé el variable group pero el paso 🚀 sigue en skip | Nombres no EXACTOS (mayúsculas incluidas), grupo no vinculado a ESTE pipeline, o las variables no llegan al paso (el paso las mapea solo vía su bloque `env:` — revisá el step en `azure-pipelines.yml`) | Verificá los 5 nombres letra por letra y que el grupo esté vinculado al pipeline |
| Job rojo en 🚀 con `!! TESTRAIL_URL debe incluir el esquema https://` | La URL cargada en el variable group/UI quedó sin el esquema | Cargala completa: `https://<instancia>.testrail.io` (con `https://` incluido) |
