#!/usr/bin/env bash
# ============================================================================
#  run-quality.sh - Ejecuta todas las herramientas de calidad localmente
# ============================================================================
set -e
cd "$(dirname "$0")/.."

echo ""
echo "================================================"
echo "  Métricas de Calidad para JabRef - Modo Local"
echo "================================================"
echo ""

# 1. Verificar JDK
if ! java -version 2>&1 | grep -qE 'version "25|version "2[6-9]'; then
    echo "⚠️  JabRef requiere JDK 25+. JDK actual:"
    java -version
    echo ""
    echo "Instalá Temurin 25: https://adoptium.net/temurin/releases/?version=25"
    exit 1
fi
echo "✅ JDK OK"; java -version

# 2. Compilar
echo ""
echo "🔨 [1/5] Compilando (./gradlew assemble)..."
./gradlew assemble --no-daemon

# 3. Tests + cobertura (databaseTest y fetcherTest SOLO existen en jablib)
echo ""
echo "🧪 [2/5] Tests unitarios + JaCoCo..."
./gradlew test :jablib:jacocoTestReport \
    -x databaseTest -x fetcherTest \
    --no-daemon

# 4. Checkstyle + Modernizer
echo ""
echo "✏️ [3/5] Checkstyle..."
./gradlew checkstyleMain checkstyleTest --no-daemon

echo ""
echo "🔄 [4/5] Modernizer..."
./gradlew modernizer --no-daemon

# 5. OpenRewrite (validación)
echo ""
echo "🪄 [5/5] OpenRewrite dry-run..."
./gradlew rewriteDryRun --no-daemon || echo "⚠️  Hay archivos que OpenRewrite podría reescribir (correr ./gradlew rewriteRun)"

# Resumen
echo ""
echo "================================================"
echo "  ✅ Listo. Reportes generados:"
echo "================================================"
echo "📊 Cobertura:     jablib/build/reports/jacoco/test/html/index.html"
echo "✏️  Checkstyle:    <modulo>/build/reports/checkstyle/main.html"
echo "🧪 Tests:         <modulo>/build/reports/tests/test/index.html"
echo ""
echo "Abrí el HTML de cobertura en el navegador."
