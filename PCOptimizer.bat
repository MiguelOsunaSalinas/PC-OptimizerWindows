@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title PC Optimizer Agent - Claude AI

:: ================================================================
::  PASO 1 - Verificar si ya corre como Administrador
:: ================================================================
net session >nul 2>&1
if %errorlevel% == 0 goto :ADMIN_OK

:: ================================================================
::  PASO 2 - No es admin: re-lanzarse con privilegios elevados
:: ================================================================
echo.
echo  [!] Se requieren permisos de Administrador.
echo  [!] Solicitando elevacion...
echo.
timeout /t 2 >nul
powershell -Command "Start-Process '%~f0' -Verb RunAs"
exit /b

:: ================================================================
::  PASO 3 - Ya es admin, verificar entorno
:: ================================================================
:ADMIN_OK
cls

:: ── Verificar Python ────────────────────────────────────────────
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [X] Python no esta instalado o no esta en el PATH.
    echo  Descargalo desde: https://www.python.org/downloads/
    pause
    exit /b 1
)

:: ── Verificar dependencias ──────────────────────────────────────
python -c "import anthropic, psutil, colorama" >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] Instalando dependencias...
    python -m pip install anthropic psutil colorama --quiet
)

:: ── Verificar API Key ───────────────────────────────────────────
if "%ANTHROPIC_API_KEY%"=="" (
    echo.
    echo  ================================================================
    echo   ANTHROPIC API KEY requerida
    echo   Obtienela en: https://console.anthropic.com/
    echo  ================================================================
    echo.
    set /p ANTHROPIC_API_KEY="  Ingresa tu API Key: "
    if "!ANTHROPIC_API_KEY!"=="" (
        echo  [X] API Key no ingresada. Saliendo.
        pause
        exit /b 1
    )
    setx ANTHROPIC_API_KEY "!ANTHROPIC_API_KEY!" >nul 2>&1
    echo  [OK] API Key guardada.
)

:: ================================================================
::  MENU PRINCIPAL
:: ================================================================
:MENU
cls
echo.
echo  ================================================================
echo    PC OPTIMIZER AGENT  v2.0  -  Powered by Claude AI
echo    Ejecutando como Administrador
echo  ================================================================
echo.
echo    1.  Analisis completo del PC con Claude AI
echo    2.  Modificar nombre del dispositivo
echo    3.  Extraer ID fisico, IP y MAC
echo    0.  Salir
echo.
echo  ================================================================
echo.
set /p OPCION="  Selecciona una opcion: "

if "!OPCION!"=="1" goto :AGENTE
if "!OPCION!"=="2" goto :CAMBIAR_NOMBRE
if "!OPCION!"=="3" goto :INFO_DISPOSITIVO
if "!OPCION!"=="0" goto :SALIR
echo  [!] Opcion invalida.
timeout /t 2 >nul
goto :MENU


:: ================================================================
::  OPCION 1 - Agente Claude AI
:: ================================================================
:AGENTE
cls
echo.
echo  [OK] Iniciando agente de analisis...
echo.
python "%~dp0pc_optimizer_agent.py"
if %errorlevel% neq 0 (
    echo.
    echo  [X] El agente termino con un error.
)
echo.
pause
goto :MENU


:: ================================================================
::  OPCION 2 - Cambiar nombre del dispositivo (sin reinicio)
:: ================================================================
:CAMBIAR_NOMBRE
cls
echo.
echo  ================================================================
echo    MODIFICAR NOMBRE DEL DISPOSITIVO
echo  ================================================================
echo.

:: Mostrar nombre actual
for /f "tokens=*" %%i in ('hostname') do set NOMBRE_ACTUAL=%%i
echo  Nombre actual:  !NOMBRE_ACTUAL!
echo.

set /p NOMBRE_NUEVO="  Nuevo nombre (max 15 caracteres, sin espacios): "

:: Validar que no este vacio
if "!NOMBRE_NUEVO!"=="" (
    echo  [X] Nombre invalido. Operacion cancelada.
    timeout /t 2 >nul
    goto :MENU
)

:: Validar que sea diferente
if /i "!NOMBRE_NUEVO!"=="!NOMBRE_ACTUAL!" (
    echo  [!] El nombre es identico al actual. Sin cambios.
    timeout /t 2 >nul
    goto :MENU
)

echo.
echo  [!] Se cambiara el nombre de "!NOMBRE_ACTUAL!" a "!NOMBRE_NUEVO!"
set /p CONFIRMAR="  Confirmar? [S/N]: "
if /i not "!CONFIRMAR!"=="S" (
    echo  Operacion cancelada.
    timeout /t 2 >nul
    goto :MENU
)

echo.
echo  [..] Aplicando cambio de nombre...

:: Cambiar en registro (efecto inmediato en la sesion actual)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName" /v ComputerName /t REG_SZ /d "!NOMBRE_NUEVO!" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" /v ComputerName /t REG_SZ /d "!NOMBRE_NUEVO!" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v Hostname /t REG_SZ /d "!NOMBRE_NUEVO!" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "NV Hostname" /t REG_SZ /d "!NOMBRE_NUEVO!" /f >nul 2>&1

:: Cambiar via PowerShell (metodo oficial)
powershell -Command "Rename-Computer -NewName '!NOMBRE_NUEVO!' -Force" >nul 2>&1

if %errorlevel% == 0 (
    echo  [OK] Nombre cambiado exitosamente a: !NOMBRE_NUEVO!
    echo.
    echo  [!] NOTA: El nuevo nombre es visible en el registro.
    echo  [!] Para que aparezca en todas las pantallas de Windows
    echo  [!] se recomienda reiniciar el equipo cuando sea posible.
) else (
    echo  [X] No se pudo cambiar el nombre. Verifica permisos de Admin.
)

echo.
pause
goto :MENU


:: ================================================================
::  OPCION 3 - Extraer ID fisico, IP y MAC
:: ================================================================
:INFO_DISPOSITIVO
cls
echo.
echo  ================================================================
echo    INFORMACION DEL DISPOSITIVO
echo  ================================================================
echo.

:: ── Archivo de reporte (siempre el mismo, acumula registros) ──
set REPORTE=%~dp0Devices Report.txt

:: ── Nombre del equipo ─────────────────────────────────────────
for /f "tokens=*" %%i in ('hostname') do set DEV_NOMBRE=%%i

:: ── UUID / ID Fisico ──────────────────────────────────────────
for /f "skip=1 tokens=*" %%i in ('wmic csproduct get UUID 2^>nul') do (
    if not "%%i"=="" set DEV_UUID=%%i
)

:: ── Numero de serie BIOS ──────────────────────────────────────
for /f "skip=1 tokens=*" %%i in ('wmic bios get SerialNumber 2^>nul') do (
    if not "%%i"=="" set DEV_SERIAL=%%i
)

:: ── IP principal ──────────────────────────────────────────────
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /i "IPv4"') do (
    set DEV_IP=%%i
    set DEV_IP=!DEV_IP: =!
)

:: ── MAC principal ─────────────────────────────────────────────
for /f "skip=1 tokens=1" %%i in ('getmac /fo table /nh 2^>nul') do (
    if not "%%i"=="" set DEV_MAC=%%i
)

:: ── Mostrar en pantalla ───────────────────────────────────────
echo  Nombre del equipo : !DEV_NOMBRE!
echo  ID Fisico (UUID)  : !DEV_UUID!
echo  N. Serie (BIOS)   : !DEV_SERIAL!
echo  Direccion IP      : !DEV_IP!
echo  Direccion MAC     : !DEV_MAC!
echo.

:: ── Guardar registro en Devices Report.txt (modo append) ──────
(
    echo ================================================================
    echo  REGISTRO: %date% %time%
    echo ================================================================
    echo  Nombre del equipo : !DEV_NOMBRE!
    echo  ID Fisico (UUID)  : !DEV_UUID!
    echo  N. Serie (BIOS)   : !DEV_SERIAL!
    echo  Direccion IP      : !DEV_IP!
    echo  Direccion MAC     : !DEV_MAC!
    echo.
) >> "!REPORTE!"

echo  [OK] Registro agregado en: !REPORTE!
echo.
pause
goto :MENU


:: ================================================================
::  SALIR
:: ================================================================
:SALIR
echo.
echo  Hasta luego.
echo.
timeout /t 2 >nul
exit /b
