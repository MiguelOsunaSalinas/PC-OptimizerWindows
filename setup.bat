@echo off
chcp 65001 >nul
title PC Optimizer Agent - Configuracion inicial

echo.
echo  ================================================================
echo   PC OPTIMIZER AGENT  -  Configuracion inicial
echo  ================================================================
echo.

REM ─── Verificar Python ───────────────────────────────────────────
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] Python no esta instalado o no esta en el PATH.
    echo.
    echo  Descargalo desde: https://www.python.org/downloads/
    echo  IMPORTANTE: Marca "Add Python to PATH" durante la instalacion.
    echo.
    pause
    exit /b 1
)

echo  [OK] Python detectado:
python --version
echo.

REM ─── Crear entorno virtual ──────────────────────────────────────
if not exist "venv" (
    echo  Creando entorno virtual...
    python -m venv venv
    if %errorlevel% neq 0 (
        echo  [ERROR] No se pudo crear el entorno virtual.
        pause
        exit /b 1
    )
    echo  [OK] Entorno virtual creado.
) else (
    echo  [OK] Entorno virtual ya existe.
)
echo.

REM ─── Activar entorno e instalar dependencias ────────────────────
echo  Instalando dependencias...
call venv\Scripts\activate.bat
python -m pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet

if %errorlevel% neq 0 (
    echo  [ERROR] Fallo la instalacion de dependencias.
    pause
    exit /b 1
)
echo  [OK] Dependencias instaladas correctamente.
echo.

REM ─── Solicitar API Key ──────────────────────────────────────────
echo  ================================================================
echo   CONFIGURACION DE API KEY DE ANTHROPIC
echo  ================================================================
echo.
echo  Necesitas una API Key de Anthropic para usar el agente.
echo  Obtienela en: https://console.anthropic.com/
echo.

if "%ANTHROPIC_API_KEY%"=="" (
    set /p API_KEY="  Ingresa tu ANTHROPIC_API_KEY: "
    if not "!API_KEY!"=="" (
        setx ANTHROPIC_API_KEY "!API_KEY!" >nul 2>&1
        set ANTHROPIC_API_KEY=!API_KEY!
        echo  [OK] API Key configurada para esta sesion y futuras sesiones.
    ) else (
        echo  [AVISO] No ingresaste una API Key. Podras configurarla luego.
    )
) else (
    echo  [OK] ANTHROPIC_API_KEY ya esta configurada en el sistema.
)
echo.

REM ─── Crear acceso directo run_agent.bat ─────────────────────────
echo  Configuracion completada con exito.
echo.
echo  Para ejecutar el agente, usa:  run_agent.bat
echo.
pause
