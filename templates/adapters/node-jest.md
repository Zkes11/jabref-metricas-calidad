# Adapter: Node + Jest

> Cómo adoptar el pipeline de calidad en un repo Node/Jest.
> La API completa está en [CONTRACT.md](../CONTRACT.md); la guía general en [README.md](../README.md).

## 1. Prerrequisitos del repo

- `package.json` **con** `package-lock.json`: el default `BUILD_CMD` es `npm ci`, que
  exige lockfile commiteado.
- Instalá el reporter JUnit (ojo: el paquete es `jest-junit`, con "j-j" — NO "jest-jest"):

  ```bash
  npm install --save-dev jest-junit
  ```

- Configurá el reporter. En `jest.config.js`:

  ```js
  module.exports = {
    reporters: [
      'default',
      ['jest-junit', { outputDirectory: 'reports', outputName: 'junit.xml' }],
    ],
    coverageReporters: ['lcov', 'text'],
  };
  ```

  (o su equivalente embebido en `package.json` bajo la clave `"jest"`).

## 2. Bloque ⚙️ CONFIGURÁ — valores para Node/Jest

```yaml
ECOSYSTEM: node
BUILD_CMD: ''   # default: npm ci
TEST_CMD: ''    # default: npx jest --ci --reporters=default --reporters=jest-junit
JUNIT_GLOB: reports/junit.xml  # override: el snippet de arriba manda el XML a reports/;
                               # sin configurar outputDirectory, dejá '' (default del contrato: junit.xml en la raíz)
COVERAGE_CMD: ''        # default: npx jest --coverage
COVERAGE_REPORT: ''     # default: coverage/lcov.info  (formato lcov)
```

Nota: `JUNIT_GLOB` es el único valor que suele convenir tocar — tiene que apuntar adonde
tu config de `jest-junit` deja el XML.

## 3. Coverage

Default: `npx jest --coverage` con `coverageReporters: ['lcov', 'text']` →
`coverage/lcov.info`.

¿Runner no-Jest (node:test, mocha, etc.)? Alternativa con `c8`:

```bash
npx c8 --reporter=lcov npm test
```

Override equivalente: `COVERAGE_CMD: npx c8 --reporter=lcov npm test` (y
`COVERAGE_REPORT: coverage/lcov.info`).

## 4. Compatibilidad TestRail

Cualquier JUnit XML sirve. El `automation_id` que matchea casos es `classname.name` —
jest-junit arma el `classname` desde el path de `describe`. Ver la guía de setup TestRail
del proyecto para crear el campo custom `automation_id` **antes** de la primera subida.

## 5. Conveniencia local opcional: `just test-report`

NO es requisito del pipeline (el contrato es de env vars, ver CONTRACT.md). Si usás `just`:

```just
# justfile
[unix]
test-report:
    npx jest --ci --reporters=default --reporters=jest-junit
```

Mismo XML que el CI, en tu máquina — útil para inspeccionarlo antes de que suba.
