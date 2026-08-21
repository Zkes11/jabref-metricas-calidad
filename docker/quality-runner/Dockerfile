# ======================================================================
# calidad-runner — El pipeline de calidad "en una caja"
# ======================================================================
# Dockeriza EL APLICATIVO de este proyecto: el pipeline de métricas
# (build → tests → JUnit XML → TestRail), con el MISMO contrato de
# variables que usa CircleCI (templates/CONTRACT.md).
#
# ¿Por qué dockerizar el pipeline y no la app JabRef?
#   - jabgui es una app de ESCRITORIO (JavaFX) → se instala con jpackage,
#     no corre en un container sin display.
#   - jabsrv/jabkit ya tienen Dockerfiles propios del upstream.
#   - Lo que NOSOTROS construimos es el pipeline → esto lo hace portable:
#     la misma caja corre en cualquier máquina con Docker, sin CircleCI.
#
# Uso (repo montado como volumen — el repo NO vive dentro de la imagen):
#   docker build -t calidad-runner -f docker/quality-runner/Dockerfile .
#   docker run --rm -v ${PWD}:/workspace calidad-runner
#   docker run --rm -v ${PWD}:/workspace \
#     -e TESTRAIL_URL=... -e TESTRAIL_EMAIL=... -e TESTRAIL_KEY=... \
#     -e TESTRAIL_PROJECT=... calidad-runner
# ======================================================================

FROM ubuntu:24.04

# --- Runtime bootstrap -------------------------------------------------
# JDK 21 como arranque: Gradle descarga solo el JDK 25 real vía toolchain
# (igual que en CI). python3+pip son para trcli. git/curl/unzip: utilidades
# del contrato. Hacemos TODO en una capa RUN para menos MB de imagen.
RUN apt-get update && apt-get install -y --no-install-recommends \
      openjdk-21-jdk-headless \
      python3 python3-pip python3-venv \
      git curl unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# --- trcli pre-instalado (versión pineada, igual que el script) --------
# El script de subida igual lo instalaría; pre-instalarlo acelera corridas
# repetidas y permite correr offline de PyPI.
RUN python3 -m pip install --break-system-packages --no-cache-dir "trcli==1.15.2"

# --- Los 3 scripts del contrato (fuente única: templates/) -------------
# .dockerignore deja pasar SOLO templates/scripts/ y docker/ → el contexto
# de build no arrastra el repo entero (2+ GB) al daemon.
COPY templates/scripts/setup-defaults.sh \
     templates/scripts/collect-junit.sh \
     templates/scripts/upload-testrail.sh \
     /opt/quality/scripts/

COPY docker/quality-runner/entrypoint.sh /opt/quality/entrypoint.sh

RUN chmod +x /opt/quality/scripts/*.sh /opt/quality/entrypoint.sh

# El repo montado acá (docker run -v ${PWD}:/workspace). La imagen queda
# GENÉRICA: la misma caja sirve para cualquier repo (java/python/node).
WORKDIR /workspace
VOLUME ["/workspace"]

# ENTRYPOINT (no CMD): la identidad del container ES el pipeline.
# Para debuggear: docker run --rm -it --entrypoint bash calidad-runner
ENTRYPOINT ["/opt/quality/entrypoint.sh"]