# 📊 Estado del proyecto — Métricas de calidad (JaCoCo + TestRail)

> Última actualización: 2026-08-17
> Repo: https://github.com/Zkes11/jabref-metricas-calidad

## ✅ Lo que se hizo

### Phase 1 — Integración TestRail en CircleCI (implementada, pendiente validación live)
| Archivo | Qué es |
|---|---|
| `scripts/upload-testrail.sh` | Script que sube los JUnit XML a TestRail vía `trcli` (pineado `1.15.2`). Gateado por `TESTRAIL_URL/EMAIL/KEY`: sin credenciales → skip limpio (exit 0); con credenciales y error → hard fail. Usa `--case-matcher auto` + `--close-run` |
| `.circleci/config.yml` | Step **🧷 Subir resultados a TestRail** en el job `build_test`, después de consolidar reportes, `when: always` |
| `docs/calidad/testrail-setup-circleci.md` | Guía pedagógica de 7 pasos (trial → Enable API → proyecto → campo `automation_id` → API key → env vars → primer run) + §9 Azure + troubleshooting |

### Phase 2 — Pipeline genérico reutilizable (COMPLETA, verificada 6/6)
| Archivo | Qué es |
|---|---|
| `templates/CONTRACT.md` | Contrato de 12 variables de entorno (ECOSYSTEM, BUILD_CMD, TEST_CMD, JUNIT_GLOB, COVERAGE_*, TESTRAIL_*) |
| `templates/circleci-config.yml` | Plantilla CircleCI con bloque **⚙️ CONFIGURÁ** arriba — otro repo solo edita eso |
| `templates/azure-pipelines.yml` | Plantilla Azure espejo del mismo contrato |
| `templates/scripts/setup-defaults.sh` | Dispatch de defaults por ecosistema (java/python/node) |
| `templates/scripts/collect-junit.sh` | Consolida XMLs a `reports/junit/` con nombres anti-colisión |
| `templates/scripts/upload-testrail.sh` | Copia genérica del script de Phase 1 (sin refs a jabref) |
| `templates/adapters/java-gradle.md` | Adapter Java (Gradle + JaCoCo) — implementado |
| `templates/adapters/python-pytest.md` | Adapter Python (pytest --junitxml + coverage) — documentado |
| `templates/adapters/node-jest.md` | Adapter Node (jest-junit + c8) — documentado |
| `templates/README.md` | Checklist de adopción en 9 pasos |

**4 bugs arreglados en configs vivas:**
1. SpotBugs con `~` entre comillas → reportes vacíos (ahora `$HOME`)
2. Orb de codecov declarado sin usar → eliminado
3. `continueOnError` de Azure → documentado (verde ≠ todo pasó)
4. Colisión de nombres XML de JaCoCo → `jacocoTestReport-${module}.xml`

### Phase 3 — TestRail en Azure + comparativa + docs finales (COMPLETA, verificada 4/4)
| Archivo | Qué es |
|---|---|
| `azure-pipelines.yml` | Step TestRail después de `PublishTestResults@2`, `condition: always()`, bloque `env:` con las 5 vars, defaults vacíos (skip seguro) |
| `docs/calidad/comparativa-ci.md` | CircleCI vs Azure vs GitHub Actions vs GitLab (datos verificados agosto 2026) |
| `docs/calidad/guia-lectura-resultados.md` | Cómo leer CI vs TestRail (incluye caveat "verde ≠ todo pasó") |
| `docs/calidad/resumen-ejecutivo.md` | Resumen del proyecto completo con diagrama de arquitectura |
| `docs/decisions/0070-testrail-pipeline-generico.md` | ADR: trcli + contrato JUnit XML + templates copy-paste |

**Verificaciones:** `.planning/phases/1-VERIFICATION.md`, `2-VERIFICATION.md`, `3-VERIFICATION.md` — 14/14 requisitos PASS. Auditoría de seguridad Mia: SHIP (0 bloqueantes).

---

## ⏳ Lo que falta (solo vos podés hacerlo)

### 1. Setup de TestRail (una sola vez, ~20 min)
Seguí `docs/calidad/testrail-setup-circleci.md` §3 en este orden:
1. Crear cuenta trial → https://testrail.com/trial (30 días, sin tarjeta) → tu instancia será `https://<nombre>.testrail.io`
2. **Enable API**: Administration → Site Settings → API (sin esto todo da 401)
3. Crear proyecto **`jabref-metricas`** en modo *single suite*
4. Crear campo custom **`automation_id`** (Administration → Customizations → Case Fields → Text) — ⚠️ **debe existir ANTES del primer upload** o duplica casos
5. Generar **API key** (avatar → My Account → Local Settings → API keys)
6. Configurar las 5 variables en CircleCI (Project Settings → Environment Variables):
   - `TESTRAIL_URL` = `https://<tu-instancia>.testrail.io`
   - `TESTRAIL_EMAIL` = tu email
   - `TESTRAIL_KEY` = tu API key 🔒
   - `TESTRAIL_PROJECT` = `jabref-metricas`
   - `TESTRAIL_SUITE_ID` = `1`
7. (Opcional) Las mismas 5 en Azure vía **variable group** — guía §9

### 2. Disparar el pipeline
- Push a `main` (o "Rerun workflow from start" en CircleCI)
- Ver el job `build-test`: el paso 🧷 corre después de consolidar reportes
- ⚠️ La primera subida tarda **~8 min** (auto-crea ~2.000 casos) — no cancelar

### 3. Reportar observaciones (para cerrar Phase 1 Task 5)
- URL del run en TestRail
- ¿Qué status les dio a los tests *skipped*? (esperado: **Retest**)
- ¿Cómo quedaron anidadas las secciones a partir de los nombres de clase Java?
- (Opcional) ¿Sobrevivieron los títulos largos con parámetros?

### 4. Seguridad (1 minuto)
- CircleCI → Settings → Advanced → verificar que **"Pass secrets to builds from forked pull requests"** esté **OFF**

---

## 🧭 Cómo adoptar esto en OTRO repo (el objetivo final)
1. Copiar la carpeta `templates/`
2. Editar solo el bloque **⚙️ CONFIGURÁ** (ECOSYSTEM + TEST_CMD + JUNIT_GLOB)
3. Seguir el checklist de 9 pasos de `templates/README.md`
4. Listo — JaCoCo es Java-only, pero TestRail funciona con cualquier stack que emita JUnit XML (Python, Node, etc.)
