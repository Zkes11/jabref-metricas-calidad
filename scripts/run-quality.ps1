# ============================================================================
#  run-quality.ps1 - Ejecuta todas las herramientas de calidad localmente
# ============================================================================
$ErrorActionPreference = "Stop"
Set-Location -Path (Split-Path -Parent $PSScriptRoot)

Write-Host ""
Write-Host "================================================"
Write-Host "  Metricas de Calidad para JabRef - Modo Local"
Write-Host "================================================"
Write-Host ""

# 1. Verificar JDK
$javaOutput = & java -version 2>&1 | Out-String
if ($javaOutput -notmatch 'version "2[5-9]') {
    Write-Host "WARNING: JabRef requiere JDK 25+. JDK actual:"
    Write-Host $javaOutput
    Write-Host ""
    Write-Host "Instala Temurin 25: https://adoptium.net/temurin/releases/?version=25"
    exit 1
}
Write-Host "JDK OK"; & java -version

# 2. Compilar
Write-Host ""
Write-Host "[1/5] Compilando (./gradlew assemble)..."
.\gradlew.bat assemble --no-daemon

# 3. Tests + cobertura (databaseTest y fetcherTest SOLO existen en jablib)
Write-Host ""
Write-Host "[2/5] Tests unitarios + JaCoCo..."
.\gradlew.bat test :jablib:jacocoTestReport `
    -x databaseTest -x fetcherTest `
    --no-daemon

# 4. Checkstyle + Modernizer
Write-Host ""
Write-Host "[3/5] Checkstyle..."
.\gradlew.bat checkstyleMain checkstyleTest --no-daemon

Write-Host ""
Write-Host "[4/5] Modernizer..."
.\gradlew.bat modernizer --no-daemon

# 5. OpenRewrite
Write-Host ""
Write-Host "[5/5] OpenRewrite dry-run..."
try {
    .\gradlew.bat rewriteDryRun --no-daemon
} catch {
    Write-Host "WARNING: Hay archivos que OpenRewrite podria reescribir (correr .\gradlew.bat rewriteRun)"
}

Write-Host ""
Write-Host "================================================"
Write-Host "  Listo. Reportes generados:"
Write-Host "================================================"
Write-Host "Cobertura:   jablib/build/reports/jacoco/test/html/index.html"
Write-Host "Checkstyle:  <modulo>/build/reports/checkstyle/main.html"
Write-Host "Tests:       <modulo>/build/reports/tests/test/index.html"
