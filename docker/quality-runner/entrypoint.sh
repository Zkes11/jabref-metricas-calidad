#!/usr/bin/env bash
# entrypoint.sh — Orquesta el contrato de calidad dentro del container.
# Misma secuencia que .circleci/config.yml: defaults → build → test →
# collect → upload. El gate de TestRail vive en upload-testrail.sh
# (sin credenciales → 1 línea de skip + exit 0; el container "funciona"
# igual sin TestRail, igual que un fork del repo).
set -euo pipefail

SCRIPTS=/opt/quality/scripts
export PATH="$HOME/.local/bin:$PATH"

# QUALITY_MODE:
#   full   (default) build + test + collect + upload  — pipeline completo
#   upload            collect + upload sobre XMLs YA generados (p. ej.
#                     corrés los tests en tu máquina y solo subís a TestRail)
MODE="${QUALITY_MODE:-full}"

echo ">> calidad-runner | mode=${MODE} | repo=$(pwd)"

# 1) Resolver defaults del contrato (auto-detecta ECOSYSTEM por los
#    archivos del repo montado; las env vars que vinieron en docker run -e
#    mandan sobre los defaults).
if [ "$MODE" = "full" ]; then
  bash "$SCRIPTS/setup-defaults.sh"

  echo ">> BUILD_CMD: ${BUILD_CMD:-} "
  if [ -n "${BUILD_CMD:-}" ]; then
    eval "$BUILD_CMD"
  else
    echo ">> BUILD_CMD vacía — skip"
  fi

  echo ">> TEST_CMD: ${TEST_CMD:-}"
  eval "$TEST_CMD"
fi

# 2) Canonizar los JUnit XML a reports/junit/ (anti-colisión de nombres).
bash "$SCRIPTS/collect-junit.sh"

# 3) Subir a TestRail (gateado por credenciales — ver cabecera).
bash "$SCRIPTS/upload-testrail.sh" "reports/junit/*.xml"

echo ">> calidad-runner: listo."