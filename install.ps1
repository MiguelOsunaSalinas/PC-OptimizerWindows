# ================================================================
#  PC OPTIMIZER AGENT - Instalador One-Liner
#  Uso: irm https://raw.githubusercontent.com/MiguelOsunaSalinas/PC-OptimizerWindows/main/install.ps1 | iex
# ================================================================

$ErrorActionPreference = "Stop"
$REPO_BASE = "https://raw.githubusercontent.com/MiguelOsunaSalinas/PC-OptimizerWindows/main"
$INSTALL_DIR = "C:\PCOptimizer"

function Write-Header {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "   PC OPTIMIZER AGENT  v2.0  -  Instalador" -ForegroundColor Cyan
    Write-Host "   Powered by Claude AI" -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  [X]  $msg" -ForegroundColor Red }
function Write-Info($msg) { Write-Host "  $msg" }

# ── PASO 1: Verificar Python ─────────────────────────────────────
function Check-Python {
    Write-Host "  [1/5] Verificando Python..." -ForegroundColor Yellow
    try {
        $ver = python --version 2>&1
        Write-Ok "Python detectado: $ver"
        return $true
    } catch {
        Write-Warn "Python no encontrado. Descargando Python 3.11..."
        try {
            $pythonUrl = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
            $pythonInstaller = "$env:TEMP\python_installer.exe"
            Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller -UseBasicParsing
            Write-Info "Instalando Python (esto puede tardar 1-2 minutos)..."
            Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait
            Remove-Item $pythonInstaller -Force
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            Write-Ok "Python instalado correctamente."
            return $true
        } catch {
            Write-Err "No se pudo instalar Python automaticamente."
            Write-Info "Descargalo manualmente desde: https://www.python.org/downloads/"
            Write-Info "IMPORTANTE: Marca 'Add Python to PATH' durante la instalacion."
            return $false
        }
    }
}

# ── PASO 2: Crear carpeta e instalar ─────────────────────────────
function Setup-Directory {
    Write-Host "  [2/5] Preparando carpeta de instalacion..." -ForegroundColor Yellow
    if (-not (Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
        Write-Ok "Carpeta creada: $INSTALL_DIR"
    } else {
        Write-Ok "Carpeta ya existe: $INSTALL_DIR"
    }
}

# ── PASO 3: Descargar archivos desde GitHub ───────────────────────
function Download-Files {
    Write-Host "  [3/5] Descargando archivos desde GitHub..." -ForegroundColor Yellow
    $files = @(
        "pc_optimizer_agent.py",
        "requirements.txt"
    )
    foreach ($file in $files) {
        try {
            $url = "$REPO_BASE/$file"
            $dest = "$INSTALL_DIR\$file"
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
            Write-Ok "Descargado: $file"
        } catch {
            Write-Err "Error al descargar $file desde $REPO_BASE"
            throw
        }
    }
}

# ── PASO 4: Instalar dependencias ────────────────────────────────
function Install-Dependencies {
    Write-Host "  [4/5] Instalando dependencias de Python..." -ForegroundColor Yellow
    try {
        python -m pip install --upgrade pip --quiet
        python -m pip install -r "$INSTALL_DIR\requirements.txt" --quiet
        Write-Ok "anthropic, psutil, colorama instalados correctamente."
    } catch {
        Write-Err "Fallo la instalacion de dependencias."
        throw
    }
}

# ── PASO 5: Configurar API Key ────────────────────────────────────
function Setup-ApiKey {
    Write-Host "  [5/5] Configurando API Key de Anthropic..." -ForegroundColor Yellow
    $existing = [System.Environment]::GetEnvironmentVariable("ANTHROPIC_API_KEY", "User")
    if ($existing) {
        Write-Ok "ANTHROPIC_API_KEY ya esta configurada en el sistema."
    } else {
        Write-Host ""
        Write-Host "  Necesitas una API Key de Anthropic para usar el agente." -ForegroundColor White
        Write-Host "  Obtienela en: https://console.anthropic.com/" -ForegroundColor Cyan
        Write-Host ""
        $apiKey = Read-Host "  Ingresa tu ANTHROPIC_API_KEY"
        if ($apiKey) {
            [System.Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", $apiKey, "User")
            $env:ANTHROPIC_API_KEY = $apiKey
            Write-Ok "API Key guardada para esta y futuras sesiones."
        } else {
            Write-Warn "No ingresaste una API Key. Podras configurarla luego con:"
            Write-Info '  $env:ANTHROPIC_API_KEY = "sk-ant-..."'
        }
    }
}

# ── CREAR ACCESO DIRECTO EN EL ESCRITORIO ────────────────────────
function Create-Shortcut {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcut = "$desktop\PC Optimizer Agent.lnk"
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $lnk = $wsh.CreateShortcut($shortcut)
        $lnk.TargetPath = "python"
        $lnk.Arguments = "$INSTALL_DIR\pc_optimizer_agent.py"
        $lnk.WorkingDirectory = $INSTALL_DIR
        $lnk.Description = "PC Optimizer Agent - Powered by Claude AI"
        $lnk.Save()
        Write-Ok "Acceso directo creado en el Escritorio."
    } catch {
        Write-Warn "No se pudo crear el acceso directo (no es critico)."
    }
}

# ════════════════════════════════════════════════════════════════
#  MAIN
# ════════════════════════════════════════════════════════════════
Write-Header

try {
    $pyOk = Check-Python
    if (-not $pyOk) { exit 1 }

    Setup-Directory
    Download-Files
    Install-Dependencies
    Setup-ApiKey
    Create-Shortcut

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Ok "Instalacion completada exitosamente."
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Info "Puedes ejecutar el agente de dos formas:"
    Write-Host "  1. Doble clic en 'PC Optimizer Agent' en el Escritorio" -ForegroundColor Cyan
    Write-Host "  2. Desde PowerShell: python $INSTALL_DIR\pc_optimizer_agent.py" -ForegroundColor Cyan
    Write-Host ""
    $run = Read-Host "  Ejecutar el agente ahora? [S/n]"
    if ($run -ne "n") {
        python "$INSTALL_DIR\pc_optimizer_agent.py"
    }

} catch {
    Write-Host ""
    Write-Err "La instalacion fallo: $_"
    Write-Warn "Intenta ejecutar PowerShell como Administrador."
    Write-Host ""
}
