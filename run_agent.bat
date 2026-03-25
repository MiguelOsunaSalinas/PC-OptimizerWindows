@echo off
chcp 65001 >nul
title PC Optimizer Agent - Claude AI

REM ─── Activar entorno virtual si existe ──────────────────────────
if exist "venv\Scripts\activate.bat" (
    call venv\Scripts\activate.bat
) else (
    REM Sin venv, usa Python global
)

REM ─── Verificar API Key ──────────────────────────────────────────
if "%ANTHROPIC_API_KEY%"=="" (
    echo.
    echo  [AVISO] ANTHROPIC_API_KEY no esta configurada.
    set /p ANTHROPIC_API_KEY="  Ingresa tu API Key ahora: "
    echo.
)

REM ─── Ejecutar el agente ─────────────────────────────────────────
python pc_optimizer_agent.py

REM Si falla, mostrar error
if %errorlevel% neq 0 (
    echo.
    echo  [ERROR] El agente termino con un error.
    echo  Ejecuta setup.bat si es la primera vez que usas el programa.
    echo.
    pause
)
