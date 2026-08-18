#!/usr/bin/env bash
# setup-defaults.sh — Resuelve los defaults del contrato según ECOSYSTEM y los persiste para los steps siguientes.
#
# Uso:
#   ECOSYSTEM=java bash scripts/setup-defaults.sh
#   (lo llaman las plantillas de CI como primer paso tras el checkout; también sirve local)
#
# Env vars (ver CONTRACT.md — la API completa):
#   ECOSYSTEM                 REQUERIDA — java | python | node. Selecciona los defaults.
#   BUILD_CMD / TEST_CMD / JUNIT_GLOB / COVERAGE_CMD / COVERAGE_REPORT
#                             Opcionales — si vienen vacías se llenan con el default del
#                             ecosistema (patrón ": ${VAR:=default}" — nunca pisa lo seteado).
#
# Comportamiento:
#   - ECOSYSTEM vacía o desconocida → error claro + exit 1.
#   - Persistencia multi-CI (pitfalls de cada CI, ver CONTRACT.md §7):
#       CircleCI (detecta CIRCLECI):     appendea los exports a $BASH_ENV
#                                       (los export de un run: NO persisten al step siguiente).
#       Azure (detecta TF_BUILD):        emite ##vso[task.setvariable] por var
#                                       (aplica desde el step SIGUIENTE, no el actual).
#   - Siempre además exporta localmente e imprime las vars resueltas (depurabilidad).
#   - Validación final: TEST_CMD no puede quedar vacía (es la única requerida además de ECOSYSTEM).
set -euo pipefail

case "${ECOSYSTEM:-}" in
  java)
    : "${BUILD_CMD:=./gradlew assemble --no-daemon}"
    : "${TEST_CMD:=./gradlew test --no-daemon}"
    : "${JUNIT_GLOB:=**/build/test-results/test/TEST-*.xml}"
    : "${COVERAGE_CMD:=./gradlew jacocoTestReport}"
    : "${COVERAGE_REPORT:=**/build/reports/jacoco/test/jacocoTestReport.xml}"
    ;;
  python)
    : "${BUILD_CMD:=python -m pip install -r requirements.txt}"
    : "${TEST_CMD:=python -m pytest --junitxml=reports/junit.xml}"
    : "${JUNIT_GLOB:=reports/junit.xml}"
    : "${COVERAGE_CMD:=coverage run -m pytest && coverage xml}"
    : "${COVERAGE_REPORT:=coverage.xml}"
    ;;
  node)
    : "${BUILD_CMD:=npm ci}"
    : "${TEST_CMD:=npx jest --ci --reporters=default --reporters=jest-junit}"
    : "${JUNIT_GLOB:=junit.xml}"
    : "${COVERAGE_CMD:=npx jest --coverage}"
    : "${COVERAGE_REPORT:=coverage/lcov.info}"
    ;;
  "")
    echo "!! ECOSYSTEM no está seteada. Valores soportados: java | python | node (ver CONTRACT.md)" >&2
    exit 1
    ;;
  *)
    echo "!! ECOSYSTEM desconocida: '${ECOSYSTEM}'. Valores soportados: java | python | node (ver CONTRACT.md)" >&2
    exit 1
    ;;
esac

export BUILD_CMD TEST_CMD JUNIT_GLOB COVERAGE_CMD COVERAGE_REPORT

# --- Persistencia para el resto del pipeline (ver CONTRACT.md §7) ---
VARS=(BUILD_CMD TEST_CMD JUNIT_GLOB COVERAGE_CMD COVERAGE_REPORT)

if [ -n "${CIRCLECI:-}" ]; then
  # CircleCI: los export de este step mueren al terminar → escribirlos en $BASH_ENV
  if [ -n "${BASH_ENV:-}" ]; then
    for v in "${VARS[@]}"; do
      echo "export ${v}=\"${!v}\"" >> "$BASH_ENV"
    done
  else
    echo ">> aviso: CIRCLECI detectado sin \$BASH_ENV — los defaults solo viven en este step" >&2
  fi
fi

if [ -n "${TF_BUILD:-}" ]; then
  # Azure: ##vso[task.setvariable] aplica desde el step SIGUIENTE (no el actual)
  for v in "${VARS[@]}"; do
    echo "##vso[task.setvariable variable=${v}]${!v}"
  done
fi

# --- Validación final: TEST_CMD es la única requerida además de ECOSYSTEM ---
if [ -z "${TEST_CMD:-}" ]; then
  echo "!! TEST_CMD quedó vacía tras resolver defaults — tu TEST_CMD DEBE dejar JUnit XML en disco (ver CONTRACT.md)" >&2
  exit 1
fi

# --- Depurabilidad: imprimir las vars resueltas ---
echo ">> setup-defaults: ECOSYSTEM=${ECOSYSTEM}"
for v in "${VARS[@]}"; do
  echo ">> ${v}=${!v}"
done
