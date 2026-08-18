# Adapter: Python + pytest

> Cómo adoptar el pipeline de calidad en un repo Python/pytest.
> La API completa está en [CONTRACT.md](../CONTRACT.md); la guía general en [README.md](../README.md).

## 1. Prerrequisitos del repo

- `requirements.txt` con tus dependencias (mínimo para el pipeline: `pytest`; para
  coverage: `coverage`):

  ```bash
  python -m pip install pytest coverage
  ```

- Fijá la familia del XML para que sea moderna y estable. En `pyproject.toml`:

  ```toml
  [tool.pytest.ini_options]
  junit_family = "xunit2"
  ```

  o en `pytest.ini`:

  ```ini
  [pytest]
  junit_family = xunit2
  ```

- **venv**: activá el entorno antes de correr el pipeline (`source venv/bin/activate`)
  o usá el path del binario del venv directo en los comandos (ej.
  `venv/bin/python -m pytest ...`).   Los defaults del contrato asumen el `python` del PATH (en las imágenes CI de Python
  eso es exactamente lo que querés).

## 2. Bloque ⚙️ CONFIGURÁ — valores para Python/pytest

Dejá las vars vacías y ya funciona: `setup-defaults.sh` resuelve exactamente estos defaults.

```yaml
ECOSYSTEM: python
BUILD_CMD: ''   # default: python -m pip install -r requirements.txt
TEST_CMD: ''    # default: python -m pytest --junitxml=reports/junit.xml
JUNIT_GLOB: ''  # default: reports/junit.xml
COVERAGE_CMD: ''        # default: coverage run -m pytest && coverage xml
COVERAGE_REPORT: ''     # default: coverage.xml  (formato Cobertura — ambas CIs lo aceptan)
```

## 3. Coverage

Default: `coverage run -m pytest && coverage xml` — corre los tests bajo `coverage` y
emite `coverage.xml`. Si preferís `pytest-cov`, el override equivalente:

```yaml
COVERAGE_CMD: python -m pytest --junitxml=reports/junit.xml --cov --cov-report=xml
COVERAGE_REPORT: coverage.xml
```

## 4. Compatibilidad TestRail

Cualquier JUnit XML sirve. El `automation_id` que matchea casos es `classname.name` —
con pytest el `classname` sale del módulo/case. Ver la guía de setup TestRail del
proyecto para crear el campo custom `automation_id` **antes** de la primera subida.

## 5. Conveniencia local opcional: `just test-report`

NO es requisito del pipeline (el contrato es de env vars, ver CONTRACT.md). Si usás `just`:

```just
# justfile
[unix]
test-report:
    python -m pytest --junitxml=reports/junit.xml
```

Mismo XML que el CI, en tu máquina — útil para inspeccionarlo antes de que suba.
