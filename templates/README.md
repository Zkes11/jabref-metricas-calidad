# templates/ — Pipeline de calidad reutilizable (copy-paste)

Un pipeline de calidad multi-CI (CircleCI + Azure Pipelines) que cualquier repo
Java, Python o Node adopta **copiando archivos y editando un solo bloque de variables**.

## Qué es y por qué

- **Qué es**: 2 plantillas de CI + 3 scripts + 3 adapters + 1 contrato de variables.
- **Por qué**: para que "medir calidad" (tests + coverage + TestRail opcional) no
  implique re-escribir YAML en cada repo. El mecanismo es copy-paste con contrato de
  env vars — el mismo patrón que usa
  [super-linter](https://github.com/super-linter/super-linter) a escala mundial: un solo
  config genérico, todo el comportamiento controlado por variables.
- **Regla de oro**: *tu repo solo tiene que saber producir JUnit XML; el pipeline se
  encarga del resto.* JUnit XML es el único formato que ambas CIs y TestRail consumen
  nativamente — es el pegamento del contrato.

## Checklist de adopción (9 pasos)

1. Copiá `circleci-config.yml` → `.circleci/config.yml` y/o `azure-pipelines.yml` → raíz de tu repo, y `scripts/` (los 3 `.sh`) → `scripts/` de tu repo.
2. Abrí el bloque `⚙️ CONFIGURÁ` (arriba de todo de la plantilla) y seteá `ECOSYSTEM: java | python | node`.
3. Ajustá la imagen del runner (CircleCI: `docker: image:`) según tu ecosistema — es edición manual, la imagen no puede venir de una variable.
4. ¿Tus comandos no son los estándar? Sobreescribí `BUILD_CMD` / `TEST_CMD`. Regla: tu `TEST_CMD` DEBE dejar JUnit XML en disco.
5. Ajustá `JUNIT_GLOB` si tus XML caen en otra ruta (tu adapter te dice cuál es la típica).
6. Opcional cobertura: seteá `COVERAGE_CMD` + `COVERAGE_REPORT` (vacías = el paso se salta).
7. Opcional TestRail: cargá `TESTRAIL_URL` / `TESTRAIL_EMAIL` / `TESTRAIL_KEY` (+ `TESTRAIL_PROJECT`) como secrets del CI — sin ellas, el paso se auto-salta con 1 línea de log.
8. Push + conectá el repo en el CI y verificá la pestaña *Tests* (todo se canoniza en `reports/junit/`).
9. Fijá versiones de imagen y tools (ej. `cimg/python:3.12`, `trcli==1.15.2`) — nunca uses `latest`.

## Mapa del template

- [CONTRACT.md](CONTRACT.md) — **la API**: las 12 variables, el gate de TestRail y los defaults por ecosistema. Empezá por acá.
- [circleci-config.yml](circleci-config.yml) · [azure-pipelines.yml](azure-pipelines.yml) — las plantillas de CI.
- `scripts/` — `setup-defaults.sh` (dispatch de defaults), `collect-junit.sh` (canoniza a `reports/junit/`), `upload-testrail.sh` (subida gateada a TestRail).
- Adapters por ecosistema: [java-gradle.md](adapters/java-gradle.md) · [python-pytest.md](adapters/python-pytest.md) · [node-jest.md](adapters/node-jest.md).

## Versionado

Práctica futura (no creadas todavía): git tags `pipeline-vX.Y.Z` + un changelog del
template para saber qué re-copiar entre versiones. Como es copy-paste, el repo adoptante
NO se auto-actualiza — aceptar el drift es parte del trade-off elegido.

## Camino de evolución (v2 — documentado, no construido)

Si algún día la actualización centralizada supera al copy-paste:

- **CircleCI orbs**: `circleci orb pack` para empaquetar estos mismos steps como un orb
  versionado (semver) y consumirlo desde cada repo.
- **Azure Pipelines**: templates cross-repo (`resources: repositories:` + service
  connection) referenciados por `ref`.
- **GitHub Actions**: workflows reutilizables (`on: workflow_call`) consumidos con `uses:`.

Ninguno de esos mecanismos es portable entre CIs — por eso el contrato de env vars es el
corazón de este template, y esos mecanismos son la evolución natural *dentro* de cada
plataforma.
