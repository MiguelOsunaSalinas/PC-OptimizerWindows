@echo off
chcp 65001 >nul
title PC Optimizer Agent - Compilar EXE

echo.
echo  ================================================================
echo   PC OPTIMIZER AGENT  -  Compilar ejecutable .EXE
echo  ================================================================
echo.

REM ─── Activar entorno virtual ────────────────────────────────────
if exist "venv\Scripts\activate.bat" (
    call venv\Scripts\activate.bat
) else (
    echo  [AVISO] Entorno virtual no encontrado. Usando Python global.
    echo  Ejecuta setup.bat primero si no lo has hecho.
    echo.
)

REM ─── Verificar PyInstaller ──────────────────────────────────────
pyinstaller --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  Instalando PyInstaller...
    pip install pyinstaller --quiet
)
echo  [OK] PyInstaller disponible.
echo.

REM ─── Compilar ───────────────────────────────────────────────────
echo  Compilando pc_optimizer_agent.py...
echo  Esto puede tomar 1-3 minutos, por favor espera...
echo.

pyinstaller ^
    --onefile ^
    --console ^
    --name "PCOptimizerAgent_v2" ^
    --icon NONE ^
    --add-data "requirements.txt;." ^
    --hidden-import psutil ^
    --hidden-import colorama ^
    --hidden-import anthropic ^
    pc_optimizer_agent.py

if %errorlevel% neq 0 (
    echo.
    echo  [ERROR] La compilacion fallo.
    pause
    exit /b 1
)

echo.
echo  ================================================================
echo   COMPILACION EXITOSA
echo  ================================================================
echo.
echo  El ejecutable se encuentra en:
echo    dist\PCOptimizerAgent_v2.exe
echo.
echo  IMPORTANTE: Para ejecutarlo necesitas configurar la variable
echo  de entorno ANTHROPIC_API_KEY antes de abrirlo:
echo.
echo    PowerShell:  $env:ANTHROPIC_API_KEY = 'tu_api_key'
echo    CMD:         set ANTHROPIC_API_KEY=tu_api_key
echo.
echo  O simplemente ejecuta el .exe y te pedira la key si no la tiene.
echo.
pause
