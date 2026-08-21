# 🐳 REPORTE — Dockerización del Pipeline de Calidad

> Qué dockerizamos, qué NO (y por qué), cada archivo, cada decisión, y cómo
> correrlo. Creado el 2026-08-21.

---

## 1. LA DECISIÓN MÁS IMPORTANTE: ¿QUÉ DOCKERIZAMOS?

Este repo (JabRef) tiene 4 partes distintas, y no todas tienen sentido en Docker:

| Parte | ¿Docker? | Por qué |
|---|---|---|
| **jabgui** (app de escritorio) | ❌ | Es JavaFX: necesita la pantalla de TU máquina. Se distribuye con `jpackage` (.exe/.msi/.dmg). Un container no tiene display → dockerizarla no tiene uso práctico. |
| **jabsrv** (servidor HTTP) | ✅ ya estaba | El upstream trae `Dockerfile.jabsrv` (multi-stage, puerto 23119). Un servidor ES el caso perfecto de Docker. |
| **jabkit** (CLI) | ✅ ya estaba | Ídem: `Dockerfile.jabkit`. |
| **NUESTRO aplicativo: el pipeline de calidad** | ✅ **esto hicimos** | Lo que construimos en este proyecto es el pipeline (build → tests → JUnit XML → TestRail). Dockerizarlo = **portarlo**: la misma caja corre en cualquier máquina sin CircleCI. |

**Conclusión**: dockerizamos lo que ES nuestro — el pipeline de métricas —
reutilizando los mismos scripts del contrato (`templates/scripts/`).

---

## 2. LOS ARCHIVOS CREADOS (3)

```
docker/quality-runner/
├── Dockerfile                    ← la receta de la imagen
├── Dockerfile.dockerignore       ← allowlist del contexto de build (solo nuestro Dockerfile)
└── entrypoint.sh                 ← el orquestador (misma secuencia que CircleCI)
```

---

## 3. EL DOCKERFILE, LÍNEA POR LÍNEA — EL POR QUÉ

### `FROM ubuntu:24.04`
- LTS estable, con `apt` (fácil instalar runtimes).
- Misma filosofía que nuestro template de CI: **base universal + se instala el
  runtime que haga falta** (en CircleCI usamos `cimg/base:current`; acá su
  equivalente "local").

### `RUN apt-get install openjdk-21-jdk-headless python3 python3-pip git curl unzip` (en UNA capa)
- **JDK 21 como bootstrap**: Gradle descarga solo el JDK 25 real vía toolchain
  (comportamiento oficial de JabRef). No hace falta hornear el 25.
- **python3+pip**: para `trcli` (la CLI de TestRail).
- **Una sola capa RUN**: cada capa suma MB de imagen; juntar los installs y
  limpiar `/var/lib/apt/lists` mantiene la imagen chica.

### `RUN pip install trcli==1.15.2`
- **Versión pineada** — exactamente la misma que usa `upload-testrail.sh`.
- Pre-instalarla acelera corridas repetidas (el script la instalaría igual,
  pero descargarla cada vez es lento).

### `COPY templates/scripts/*.sh /opt/quality/scripts/`
- **Fuente única de verdad**: los mismos 3 scripts del contrato que usa el
  template genérico. Cero duplicación: si mejorás un script, el container y
  el CI se actualizan juntos.

### `WORKDIR /workspace` + `VOLUME ["/workspace"]`
- **El repo NO vive dentro de la imagen** — se monta al correr:
  `docker run -v ${PWD}:/workspace ...`
- Por eso la MISMA imagen sirve para **cualquier** repo (java/python/node):
  la imagen es el ejecutor, el repo es el dato.

### `ENTRYPOINT` (no `CMD`)
- La **identidad** del container ES el pipeline: corrés el container y el
  pipeline arranca.
- `CMD` se puede sobreescribir fácil; ENTRYPOINT es "esto que ES".
- Debug: `docker run --rm -it --entrypoint bash calidad-runner` → entrás a un
  bash dentro de la caja para inspeccionar.

---

## 4. `entrypoint.sh` — MISMA SECUENCIA QUE CIRCLECI

```
setup-defaults.sh → BUILD_CMD → TEST_CMD → collect-junit.sh → upload-testrail.sh
```

- **`QUALITY_MODE`** (env var):
  - `full` (default): todo el pipeline — build, tests, consolidar, subir.
  - `upload`: solo `collect-junit.sh` + `upload-testrail.sh` sobre XMLs que YA
    generaste en tu máquina. Útil para "subir a TestRail sin CI".
- **El gate se preserva**: sin las 3 credenciales TESTRAIL_*, el script de
  subida imprime 1 línea y sale 0 → **el container funciona igual sin
  TestRail** (igual que un fork del repo).

---

## 5. `Dockerfile.dockerignore` — EL ALLOWLIST (la decisión más fina)

**Problema**: `docker build` manda el CONTEXTO completo al daemon. Nuestro
repo pesa GBs (código + .git + builds). Sin ignore, cada build transferiría todo.

**Problema 2**: ya existe un `.dockerignore` raíz — pero es del UPSTREAM y lo
necesitan `Dockerfile.jabsrv`/`jabkit` (hacen `COPY . .`). Tocarlo los rompería.

**Solución**: BuildKit soporta un ignore **por-Dockerfile**: al construir con
`-f docker/quality-runner/Dockerfile`, usa
`docker/quality-runner/Dockerfile.dockerignore` (si existe) en vez del raíz.
Patrón allowlist:

```dockerignore
*                          ← ignora TODO
!templates/scripts/        ← deja pasar SOLO lo que copiamos
!docker/quality-runner/
```

Resultado: contexto de **KBs**, no GBs.

---

## 6. DETALLE QUE ROMPE TODO: FIN DE LÍNEA LF

`entrypoint.sh` se escribió con **LF puro** (sin CRLF de Windows). Si un
`.sh` tiene `\r\n`, bash falla con errores crípticos (`\r: command not found`).
Verificado: 0 CRLF en el archivo.

---

## 7. CÓMO CONSTRUIRLO Y CORRERLO

```powershell
# 1) Construir la imagen (ojo el -f y el punto del contexto)
docker build -t calidad-runner -f docker/quality-runner/Dockerfile .

# 2) Correr SIN TestRail (el gate salta limpio — prueba de humo)
docker run --rm -v ${PWD}:/workspace calidad-runner

# 3) Correr con subida a TestRail (los secrets van por -e, NUNCA horneados)
docker run --rm -v ${PWD}:/workspace `
  -e TESTRAIL_URL="https://zkes11.testrail.io" `
  -e TESTRAIL_EMAIL="santiago11ro11@gmail.com" `
  -e TESTRAIL_KEY="..." `
  -e TESTRAIL_PROJECT="jabref-metricas" `
  -e TESTRAIL_SUITE_ID="6" `
  calidad-runner

# 4) Solo subir XMLs ya generados
docker run --rm -v ${PWD}:/workspace -e QUALITY_MODE=upload `
  -e TESTRAIL_URL=... -e TESTRAIL_EMAIL=... -e TESTRAIL_KEY=... `
  calidad-runner
```

⚠️ Nota JabRef: el build completo dentro del container tarda (Gradle baja el
JDK 25 y todas las dependencias — no hay caché montado). Para iterar rápido,
montá también el caché: `-v gradle-cache:/home/root/.gradle`.

---

## 8. LA FRASE PARA EL REPORTE/PRESENTACIÓN

> *"La app de escritorio no se dockeriza (no tiene sentido sin pantalla); los
> servidores ya tenían Dockerfiles del upstream; lo que dockerizamos es
> NUESTRO pipeline de calidad: una imagen con el mismo contrato de variables
> que CircleCI, que monta cualquier repo y ejecuta build → tests → TestRail.
> El container ES el job de CI, portable."*

---

## 9. LIMITACIONES Y PRÓXIMOS PASOS (honestidad técnica)

| Limitación | Mitigación futura |
|---|---|
| La imagen trae JDK+Python (no Node) | Variante por ecosistema o multi-stage |
| El build de JabRef dentro tarda mucho sin caché | Montar `-v gradle-cache:...` |
| `QUALITY_MODE=full` corre TODO (no filtrado por suite) | Podrían agregarse modos `test-only`, `coverage-only` |
| Corre como root dentro del container | Crear usuario no-root (buena práctica de hardening) |