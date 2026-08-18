# 📋 Resumen ejecutivo — métricas de calidad para el fork de JabRef

**Qué es este proyecto:** evolucionamos el fork de JabRef con **métricas de calidad reutilizables**: un pipeline dual (CircleCI + Azure Pipelines) que corre tests y análisis, sube resultados (opcionalmente) a TestRail, y un template genérico multi-lenguaje para que cualquier repo adopte todo — **sin tocar una línea de Java**.

## 🗺️ La arquitectura en un cuadro

```text
repo GitHub (fork de JabRef) ──push──▶ CircleCI ∥ Azure Pipelines (3 jobs cada uno)
                                            │
                                            ▼
                              JUnit XML · JaCoCo · Checkstyle · Modernizer
                              · OpenRewrite · SpotBugs · OWASP Dep-Check
                                            │
                                            ▼ (opcional, gateado por TESTRAIL_*)
                                     TestRail (historia de runs y casos)
```

El corazón del diseño es un **contrato**: cada CI produce los mismos artefactos (XMLs y HTMLs de reporte) y el mismo script (`scripts/upload-testrail.sh`) los consume con el mismo glob en cualquier plataforma — el [ADR-0070](../decisions/0070-testrail-pipeline-generico.md) registra la decisión completa.

## 📏 Qué mide cada pieza

| Herramienta | Qué mide | Dónde se ve |
|---|---|---|
| **JUnit 5** | Tests unitarios: pasan/fallan/skip por test | Pestaña Tests de cada CI + TestRail (historia) |
| **JaCoCo** | Cobertura de código (líneas, ramas) | Pestaña Code coverage de Azure + artifacts JaCoCo |
| **Checkstyle / Modernizer / OpenRewrite** | Estilo, APIs legacy, refactors pendientes | Artifacts `quality-reports` de cada CI |
| **SpotBugs** | Bugs reales en bytecode (null pointers, races) | Artifacts `spotbugs-reports` |
| **OWASP Dep-Check** | CVEs conocidos en dependencias | Artifacts `dependency-check-reports` |
| **TestRail** | Historia de runs, evolución por caso, flakiness | Test Runs & Results (acumulado, no por build) |

## 📆 Las 3 fases del proyecto

- **Phase 1** — Integración TestRail en CircleCI: script compartido `upload-testrail.sh` (gate de credenciales + hard fail), paso 🧷 en `.circleci/config.yml` y guía de setup completa.
- **Phase 2** — Pipeline genérico reutilizable: `templates/` con el contrato de variables ([`CONTRACT.md`](../../templates/CONTRACT.md)), las 2 plantillas de CI, 3 scripts y 3 adapters por ecosistema (Java, Python, Node) + 4 fixes de configuración a los archivos vivos.
- **Phase 3** — TestRail en Azure + cierre: paso 🚀 en `azure-pipelines.yml`, [comparativa de 4 plataformas CI](comparativa-ci.md), [guía de lectura de resultados](guia-lectura-resultados.md), este resumen y el [ADR-0070](../decisions/0070-testrail-pipeline-generico.md).

## 📦 Cómo adoptarlo en otro repo

Copiás la carpeta `templates/` al repo destino (Java, Python o Node), editás **solo el bloque `⚙️ CONFIGURÁ`** de la plantilla del CI que uses, y listo: tests + reportes + subida opcional a TestRail funcionando. El checklist completo (≤9 pasos) vive en [`templates/README.md`](../../templates/README.md).

## ⏳ Estado y pendientes

- **Cuenta trial de TestRail** (30 días, sin tarjeta): checkpoint de usuario **pendiente** — cuando exista, el mismo checklist valida los pasos 🧷 (CircleCI) y 🚀 (Azure) de una vez.
- **Post-trial**: borrar las variables `TESTRAIL_*` del CI → el script vuelve al skip limpio (documentado; decisión de renovar fuera de alcance).
- **GitHub Actions y GitLab CI**: solo comparados ([comparativa](comparativa-ci.md)), no implementados — límite deliberado del fork.

## 🧭 Mapa de documentos

| Documento | Qué tiene |
|---|---|
| [`README.md`](README.md) | Hub principal: herramientas, setup local, setup de ambos CIs, FAQ |
| [`testrail-setup-circleci.md`](testrail-setup-circleci.md) | Checklist completo de TestRail (CircleCI + Azure, §9) |
| [`comparativa-ci.md`](comparativa-ci.md) | Comparativa de 4 plataformas CI (datos verificados agosto 2026) |
| [`guia-lectura-resultados.md`](guia-lectura-resultados.md) | ¿Dónde miro qué? CI vs TestRail, el caveat del verde de Azure |
| [`../../templates/CONTRACT.md`](../../templates/CONTRACT.md) | El contrato de variables (la "API" del template) |
| [`../../templates/README.md`](../../templates/README.md) | Guía de adopción del template genérico |
| [`../decisions/0070-testrail-pipeline-generico.md`](../decisions/0070-testrail-pipeline-generico.md) | ADR-0070: la decisión de arquitectura (trcli + contrato + copy-paste) |
