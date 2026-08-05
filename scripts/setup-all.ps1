# ============================================================================
#  setup-all.ps1 - Setup completo en UN solo comando
# ============================================================================
#  Qué hace:
#    1) Verifica/instala JDK 25 (Temurin) en C:\tools\jdk25 y lo prioriza
#    2) Verifica/instala GitHub CLI (gh), circleci CLI, Azure CLI (az)
#    3) Inicializa submodules de Git
#    4) Valida sintaxis de los pipelines
#    5) Te guía por los pasos manuales (login OAuth) que solo vos podés dar
#
#  Uso:
#    .\scripts\setup-all.ps1                 -> setup completo
#    .\scripts\setup-all.ps1 -SkipInstall    -> saltear instalaciones
#    .\scripts\setup-all.ps1 -RunQuality     -> además corre las métricas
# ============================================================================

[CmdletBinding()]
param(
    [switch]$SkipInstall,
    [switch]$RunQuality
)

Set-Location -Path (Split-Path -Parent $PSScriptRoot)

function Write-Step($msg) { Write-Host "`n[+] $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "    OK $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    !! $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "    XX $msg" -ForegroundColor Red }

function Get-JavaVersion($javaBin) {
    try {
        $out = & $javaBin -version 2>&1 | Out-String
        if ($out -match 'version "(\d+)') { return $matches[1] }
    } catch {}
    return $null
}

$JdkDir      = "C:\tools\jdk25"
$CircleciDir = "C:\tools\circleci"

# ---------------------------------------------------------------------------
# 1) JDK 25 - SIEMPRE preferir el de $JdkDir sobre el del PATH
# ---------------------------------------------------------------------------
Write-Step "Paso 1/6: Verificar JDK 25"

$realJdk = $null
if (Test-Path $JdkDir) {
    $realJdk = (Get-ChildItem $JdkDir -Directory | Where-Object Name -like "jdk-25*" | Select-Object -First 1).FullName
}

if ($realJdk) {
    $env:JAVA_HOME = $realJdk
    $env:PATH = "$realJdk\bin;" + $env:PATH
    $v = Get-JavaVersion "$realJdk\bin\java.exe"
    Write-OK "JDK detectado: $realJdk (version $v)"
} elseif (-not $SkipInstall) {
    Write-Warn "Descargando Temurin JDK 25..."
    $zip = "$env:TEMP\jdk25.zip"
    Invoke-WebRequest -UseBasicParsing -Uri "https://api.adoptium.net/v3/binary/latest/25/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk" -OutFile $zip
    New-Item -ItemType Directory -Force -Path $JdkDir | Out-Null
    Expand-Archive -Path $zip -DestinationPath $JdkDir -Force
    Remove-Item $zip
    $realJdk = (Get-ChildItem $JdkDir -Directory | Where-Object Name -like "jdk-25*" | Select-Object -First 1).FullName
    $env:JAVA_HOME = $realJdk
    $env:PATH = "$realJdk\bin;" + $env:PATH
    Write-OK "JDK 25 instalado: $realJdk"
} else {
    Write-Err "No hay JDK 25 y se pidió -SkipInstall. Abortando."
    exit 1
}

Write-Host "    Verificando java activo:"
& java -version 2>&1 | ForEach-Object { Write-Host "      $_" }

# ---------------------------------------------------------------------------
# 2) CLIs
# ---------------------------------------------------------------------------
Write-Step "Paso 2/6: Verificar CLIs"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Warn "Instalando GitHub CLI via winget..."
    winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements | Out-Null
}
$ghVer = (gh --version 2>&1 | Select-Object -First 1)
Write-OK "gh: $ghVer"

if (-not (Test-Path "$CircleciDir\circleci.exe") -and -not $SkipInstall) {
    Write-Warn "Descargando circleci CLI..."
    New-Item -ItemType Directory -Force -Path $CircleciDir | Out-Null
    $release = Invoke-RestMethod "https://api.github.com/repos/CircleCI-Public/circleci-cli/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -like "*windows*amd64*.zip" } | Select-Object -First 1
    $zip = "$env:TEMP\circleci.zip"
    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $CircleciDir -Force
    Remove-Item $zip
}
$env:PATH = "$CircleciDir;$env:PATH"
if (Test-Path "$CircleciDir\circleci.exe") {
    $ciVer = (& "$CircleciDir\circleci.exe" version 2>&1 | Select-Object -First 1)
    Write-OK "circleci: $ciVer"
}

if (-not (Get-Command az -ErrorAction SilentlyContinue) -and -not $SkipInstall) {
    Write-Warn "Instalando Azure CLI via winget..."
    winget install --id Microsoft.AzureCLI --silent --accept-source-agreements --accept-package-agreements | Out-Null
}
$azCmd = Get-Command az -ErrorAction SilentlyContinue
if ($azCmd) {
    Write-OK "az: instalado"
} else {
    Write-Warn "az CLI instalado pero no en PATH todavía (reiniciar consola)"
}

# ---------------------------------------------------------------------------
# 3) Submodules
# ---------------------------------------------------------------------------
Write-Step "Paso 3/6: Submodules de Git"
$submodules = git submodule status 2>&1
$missing = ($submodules | Where-Object { $_ -match "^-" }).Count
if ($missing -gt 0) {
    Write-Warn "$missing submodules faltantes. Inicializando..."
    git submodule update --init --depth 1
    Write-OK "Submodules inicializados"
} else {
    Write-OK "Submodules ya inicializados"
}

# ---------------------------------------------------------------------------
# 4) Validar pipelines
# ---------------------------------------------------------------------------
Write-Step "Paso 4/6: Validar pipelines"
try {
    python -c "import yaml; yaml.safe_load(open('azure-pipelines.yml', encoding='utf-8'))" 2>&1 | Out-Null
    Write-OK "azure-pipelines.yml válido"
} catch { Write-Err "azure-pipelines.yml inválido: $_" }

try {
    python -c "import yaml; yaml.safe_load(open('.circleci/config.yml', encoding='utf-8'))" 2>&1 | Out-Null
    Write-OK ".circleci/config.yml válido"
} catch { Write-Err ".circleci/config.yml inválido: $_" }

if (Test-Path "$CircleciDir\circleci.exe") {
    & "$CircleciDir\circleci.exe" config validate .circleci/config.yml 2>&1 | ForEach-Object { Write-Host "    $_" }
}

# ---------------------------------------------------------------------------
# 5) Próximos pasos manuales
# ---------------------------------------------------------------------------
Write-Step "Paso 5/6: Variables de entorno"
if ($realJdk) {
    Write-Host "    Para que JDK 25 sobreviva a reinicios de consola, ejecutá:" -ForegroundColor White
    Write-Host "        setx JAVA_HOME `"$realJdk`"" -ForegroundColor White
}

# ---------------------------------------------------------------------------
# 6) Próximos pasos manuales (solo OAuth)
# ---------------------------------------------------------------------------
Write-Step "Paso 6/6: Lo que falta (requiere tu login OAuth)"
Write-Host @"

    ════════════════════════════════════════════════════════════════════
      LO QUE FALTA — solo vos podés hacerlo (autenticación OAuth)
    ════════════════════════════════════════════════════════════════════

    1) FORK en GitHub (si todavía no lo hiciste)
       - Andá a https://github.com/JabRef/jabref
       - Click "Fork" arriba a la derecha

    2) AUTENTICAR GitHub CLI y pushear
       En otra consola PowerShell:
         gh auth login
         # (elegí: GitHub.com -> HTTPS -> Yes -> Login with browser)
         # Esto abre el navegador, autorizás y listo.

         # Subir el código al fork:
         git remote add origin https://github.com/TU_USUARIO/jabref.git
         git add azure-pipelines.yml .circleci/ scripts/ docs/calidad/
         git commit -m "Agregar pipelines Azure + CircleCI"
         git push -u origin main
         # (o el branch que tengas)

    3) CIRCLECI
       - Andá a https://app.circleci.com
       - "Sign in with GitHub" (un click)
       - "Projects" > buscar tu fork > "Set Up Project"
       - Elegir "Existing config" > branch main > "Set Up Project"
       - Listo, el primer build dispara.

    4) AZURE DEVOPS
       - Andá a https://dev.azure.com
       - "Sign in" con cuenta Microsoft (creala si no tenés)
       - Crear proyecto nuevo > nombre: jabref-calidad
       - "Pipelines" > "New pipeline" > GitHub > tu fork
       - "Existing Azure Pipelines file" > /azure-pipelines.yml
       - "Run"

    Después de esos pasos, cada push dispara ambos pipelines.

    ════════════════════════════════════════════════════════════════════
"@

if ($RunQuality) {
    Write-Step "Bonus: corriendo métricas locales (10-20 min la 1ra vez)"
    & .\scripts\run-quality.ps1
}

Write-Host "`n=== Setup local terminado ===`n" -ForegroundColor Green
