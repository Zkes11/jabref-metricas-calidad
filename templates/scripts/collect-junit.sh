#!/usr/bin/env bash
# collect-junit.sh — Consolida todos los JUnit XML que matchean JUNIT_GLOB en reports/junit/ (path canónico del contrato).
#
# Uso:
#   bash scripts/collect-junit.sh                (usa $JUNIT_GLOB del contrato)
#   bash scripts/collect-junit.sh "<glob>"       (override puntual como argumento $1)
#
# Comportamiento:
#   - mkdir -p reports/junit y copia cada match ahí con nombre plano anti-colisión
#     prefijado por módulo, derivado del path (./m1/build/.../TEST-A.xml →
#     m1__build__...__TEST-A.xml). Los nombres de archivo planos son irrelevantes
#     para trcli y para los Tests tabs: lo que parsean es el CONTENIDO XML
#     (classname/name vienen adentro de cada archivo).
#   - 0 archivos encontrados → error claro + exit 1 (TEST_CMD prometió JUnit XML
#     y no lo dejó — ver CONTRACT.md).
set -euo pipefail

GLOB="${1:-${JUNIT_GLOB:?!! JUNIT_GLOB no está seteada y no se pasó un glob como argumento (ver CONTRACT.md)}}"

mkdir -p reports/junit

# globstar: para que ** crucce directorios; nullglob: para detectar "0 matches" sin errores
shopt -s globstar nullglob

count=0
for f in $GLOB; do
  [ -f "$f" ] || continue
  flat=$(printf '%s' "$f" | sed 's|^\./||; s|/|__|g')
  cp "$f" "reports/junit/${flat}"
  count=$((count + 1))
done

if [ "$count" -eq 0 ]; then
  echo "!! TEST_CMD no produjo JUnit XML en JUNIT_GLOB='${GLOB}' — revisá CONTRACT.md: tu TEST_CMD DEBE dejar JUnit XML en disco" >&2
  exit 1
fi

echo ">> collect-junit: ${count} archivo(s) copiado(s) a reports/junit/"
