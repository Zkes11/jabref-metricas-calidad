#!/usr/bin/env bash
# upload-testrail.sh — Sube resultados JUnit XML a TestRail vía trcli (parse_junit).
#
# Uso:
#   bash scripts/upload-testrail.sh "<glob-de-XMLs-junit>"
#   (sin argumento usa el default **/build/test-results/test/TEST-*.xml)
#
# Env vars — 100% de la config viene por acá (ninguna específica de un CI:
# el mismo script sirve para CircleCI, Azure Pipelines o una corrida local):
#   TESTRAIL_URL          (gate) Instancia completa CON esquema https:// (ej: https://xyz.testrail.io)
#   TESTRAIL_EMAIL        (gate) Email de login en TestRail
#   TESTRAIL_KEY          (gate) API key (My Account > Local Settings > API keys). SECRETO.
#   TESTRAIL_PROJECT      Nombre del proyecto en TestRail (default: jabref-metricas)
#   TESTRAIL_SUITE_ID     Opcional: ID numérico de la suite (no hace falta en single-suite)
#   TESTRAIL_SECTION_ID   Opcional: ancla las secciones/casos auto-creados bajo una
#                         sección padre existente (mitigación de anidamiento por FQCN)
#
# Comportamiento:
#   - Sin credenciales (alguna de URL/EMAIL/KEY vacía) → UNA línea de skip + exit 0.
#   - Con credenciales y fallo → exit != 0 (hard fail por diseño, sin soft-fail).
set -euo pipefail

TRCLI_VERSION="1.15.2"  # pin: instala exactamente trcli==1.15.2 (verificado 2026-08-17, research testrail-trcli.md). Subir deliberadamente + re-smoke.
XML_GLOB="${1:-**/build/test-results/test/TEST-*.xml}"

# --- Gate: exactamente las 3 vars de auth componen el gate (PROJECT/SUITE_ID NO gatean) ---
if [ -z "${TESTRAIL_URL:-}" ] || [ -z "${TESTRAIL_EMAIL:-}" ] || [ -z "${TESTRAIL_KEY:-}" ]; then
  echo ">> TestRail: credenciales no configuradas (TESTRAIL_URL/TESTRAIL_EMAIL/TESTRAIL_KEY) — omitiendo subida / upload skipped"
  exit 0
fi

# --- Validación temprana del host (trcli rechaza hosts sin esquema; damos error claro antes de instalar nada) ---
case "${TESTRAIL_URL}" in
  https://*) ;;
  *) echo "!! TESTRAIL_URL debe incluir el esquema https:// (ej: https://mi-instancia.testrail.io)"; exit 1 ;;
esac

TESTRAIL_PROJECT="${TESTRAIL_PROJECT:-jabref-metricas}"  # default sano; override por env var
export PATH="$HOME/.local/bin:$PATH"

# --- Instalación de trcli (versión pineada; ladder defensivo para cimg/openjdk:25.0) ---
# cimg trae python3 pero pip puede faltar; Ubuntu 24.04 puede aplicar PEP 668.
# OJO: --break-system-packages solo existe en pip >= 23.0. En Ubuntu 22.04 (jammy,
# cimg/openjdk:25.0) el pip de apt es 22.0.2 y NO soporta el flag (ni lo necesita:
# jammy no aplica PEP 668). Se agrega el flag solo si el pip lo soporta.
install_trcli() {
  local extra=""
  if python3 -m pip --version 2>/dev/null | grep -qE "pip (2[3-9]|[3-9][0-9])"; then
    extra="--break-system-packages"
  fi
  python3 -m pip install --quiet --user $extra "trcli==${TRCLI_VERSION}"
}

if ! pip3 install --quiet "trcli==${TRCLI_VERSION}" 2>/dev/null; then
  if ! python3 -m pip install --quiet --user "trcli==${TRCLI_VERSION}" 2>/dev/null; then
    if ! command -v pip3 >/dev/null 2>&1; then
      sudo apt-get update -qq && sudo apt-get install -y python3-pip
    fi
    install_trcli
  fi
fi
command -v trcli >/dev/null 2>&1 || { echo "!! trcli no quedó disponible en PATH tras la instalación"; exit 1; }

# --- Título del run con contexto del CI (genérico: detecta CircleCI, Azure o local) ---
if [ -n "${CIRCLE_BUILD_NUM:-}" ]; then
  TITLE="CircleCI #${CIRCLE_BUILD_NUM} (${CIRCLE_BRANCH:-sin rama})"
elif [ -n "${BUILD_BUILDID:-}" ]; then
  TITLE="Azure Pipelines #${BUILD_BUILDID} (${BUILD_SOURCEBRANCHNAME:-sin rama})"
else
  TITLE="Corrida local"
fi
TITLE="${TITLE} — $(date +%Y-%m-%d)"

# --- Flags opcionales por env var (ambos son flags del subcomando parse_junit → van al final) ---
EXTRA_ARGS=()
if [ -n "${TESTRAIL_SUITE_ID:-}" ];     then EXTRA_ARGS+=(--suite-id "${TESTRAIL_SUITE_ID}"); fi
if [ -n "${TESTRAIL_SECTION_ID:-}" ];   then EXTRA_ARGS+=(--section-id "${TESTRAIL_SECTION_ID}"); fi

# --- Subida. El glob va QUOTED ("${XML_GLOB}"): lo expande trcli, NO el shell. ---
trcli -y \
  -h "${TESTRAIL_URL}" \
  -u "${TESTRAIL_EMAIL}" \
  -k "${TESTRAIL_KEY}" \
  --project "${TESTRAIL_PROJECT}" \
  parse_junit \
  -f "${XML_GLOB}" \
  --case-matcher auto \
  --title "${TITLE}" \
  --run-description "Subida automática desde CI. Build: ${CIRCLE_BUILD_URL:-corrida local}" \
  --close-run \
  "${EXTRA_ARGS[@]}"
