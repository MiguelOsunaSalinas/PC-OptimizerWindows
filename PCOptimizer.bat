@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title PC Optimizer Agent

:: ================================================================
::  AUTO-ELEVACION A ADMINISTRADOR
:: ================================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: ================================================================
::  RECOPILAR INFO DEL SISTEMA AL INICIO
:: ================================================================
echo  Recopilando informacion del sistema...

for /f "skip=1 tokens=*" %%i in ('wmic cpu get Name 2^>nul') do (
    if not "%%i"=="" if not defined CPU set CPU=%%i
)
for /f "skip=1 tokens=1" %%i in ('wmic computersystem get TotalPhysicalMemory 2^>nul') do (
    if not "%%i"=="" set /a RAM_GB=%%i/1073741824
)
for /f "tokens=2 delims==" %%i in ('wmic os get Caption /value 2^>nul') do (
    if not "%%i"=="" set OS_NAME=%%i
)
for /f "skip=1 tokens=*" %%i in ('wmic path win32_videocontroller get Name 2^>nul') do (
    if not "%%i"=="" if not defined GPU set GPU=%%i
)
for /f "tokens=*" %%i in ('hostname') do set PC_NAME=%%i
for /f "skip=1 tokens=*" %%i in ('wmic csproduct get UUID 2^>nul') do (
    if not "%%i"=="" if not defined UUID set UUID=%%i
)
for /f "skip=1 tokens=*" %%i in ('wmic bios get SerialNumber 2^>nul') do (
    if not "%%i"=="" if not defined SERIAL set SERIAL=%%i
)
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /i "IPv4" 2^>nul') do (
    if not defined IP ( set IP=%%i & set IP=!IP: =! )
)
for /f "skip=1 tokens=1" %%i in ('getmac /fo table /nh 2^>nul') do (
    if not defined MAC set MAC=%%i
)

:: Tipo de disco via PowerShell
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "try { $d = Get-PhysicalDisk | Select-Object -First 1; if ($d.MediaType -match 'NVMe' -or $d.BusType -eq 'NVMe') { 'NVMe SSD' } elseif ($d.MediaType -eq 'SSD') { 'SSD' } elseif ($d.MediaType -eq 'HDD') { 'HDD' } else { 'SSD/HDD' } } catch { 'SSD/HDD' }" 2^>nul') do set DISK=%%i
if not defined DISK set DISK=SSD/HDD

:: ================================================================
::  MENU PRINCIPAL
:: ================================================================
:MENU
cls
echo.
echo  ================================================================
echo    PC OPTIMIZER AGENT  -  Sin API Key
echo    Equipo: !PC_NAME!
echo  ================================================================
echo.
echo    1.  Generar prompt de optimizacion y abrir Claude AI
echo    2.  Modificar nombre del dispositivo
echo    3.  Extraer ID fisico, IP y MAC  (Devices Report)
echo    0.  Salir
echo.
echo  ================================================================
echo.
set /p OPCION="  Selecciona una opcion: "

if "!OPCION!"=="1" goto :GENERAR_PROMPT
if "!OPCION!"=="2" goto :CAMBIAR_NOMBRE
if "!OPCION!"=="3" goto :INFO_DISPOSITIVO
if "!OPCION!"=="0" goto :SALIR

echo  [!] Opcion invalida.
timeout /t 2 >nul
goto :MENU


:: ================================================================
::  OPCION 1 - GENERAR PROMPT Y ABRIR CLAUDE AI
:: ================================================================
:GENERAR_PROMPT
cls
echo.
echo  ================================================================
echo    GENERANDO PROMPT DE OPTIMIZACION
echo  ================================================================
echo.
echo  Uso principal del equipo:
echo    1. Gaming
echo    2. Trabajo / Oficina
echo    3. Diseno / Edicion
echo    4. Uso general
echo.
set /p USO_NUM="  Selecciona [1-4]: "
if "!USO_NUM!"=="1" set USO=gaming
if "!USO_NUM!"=="2" set USO=trabajo y oficina
if "!USO_NUM!"=="3" set USO=diseno y edicion
if "!USO_NUM!"=="4" set USO=uso general
if not defined USO set USO=uso general

echo.
set /p APPS="  Aplicaciones que mas usas (ej: Chrome, Office): "
if "!APPS!"=="" set APPS=no especificado

echo.
set /p PROBLEMAS="  Problemas que notas (ej: lentitud, alto RAM): "
if "!PROBLEMAS!"=="" set PROBLEMAS=ninguno especificado

:: ── Escribir prompt a archivo temporal ──────────────────────
set TMPFILE=%TEMP%\pc_optimizer_prompt.txt

(
echo Actua como un experto en administracion de sistemas Windows con mas de 15 anos de experiencia en optimizacion de rendimiento, seguridad y mantenimiento de equipos. Analiza la informacion de mi PC y dame un plan completo de optimizacion:
echo.
echo ================================================================
echo INFORMACION DEL SISTEMA
echo ================================================================
echo Nombre del equipo : !PC_NAME!
echo Sistema Operativo : !OS_NAME!
echo Procesador        : !CPU!
echo RAM instalada     : !RAM_GB! GB
echo Tipo de disco     : !DISK!
echo Tarjeta grafica   : !GPU!
echo Uso principal     : !USO!
echo Apps frecuentes   : !APPS!
echo Problemas         : !PROBLEMAS!
echo.
echo ================================================================
echo AREAS A OPTIMIZAR
echo ================================================================
echo.
echo 1. RENDIMIENTO GENERAL
echo - Procesos de inicio a deshabilitar segun mi uso
echo - Plan de energia optimo para mi CPU
echo - Ajustes visuales para priorizar rendimiento
echo - Optimizacion del archivo de paginacion para !RAM_GB! GB de RAM
echo.
echo 2. FIREWALL Y SEGURIDAD
echo - Reglas de Firewall recomendadas para uso de !USO!
echo - Servicios de Windows a deshabilitar
echo - Herramientas gratuitas de seguridad recomendadas
echo - Como verificar procesos sospechosos
echo.
echo 3. GESTION DE APLICACIONES
echo - Como identificar apps no usadas en 30/60/90 dias
echo - Bloatware de Windows seguro de eliminar
echo - Herramientas para desinstalacion limpia
echo.
echo 4. OPTIMIZACION DE MEMORIA RAM ^(!RAM_GB! GB^)
echo - Procesos que mas consumen RAM y como gestionarlos
echo - Configuraciones para liberar RAM automaticamente
echo - Comandos PowerShell para monitoreo de memoria
echo.
echo 5. LIMPIEZA Y MANTENIMIENTO
echo - Limpieza de temporales, cache y logs del sistema
echo - Optimizacion de disco tipo !DISK!
echo - Tareas automaticas de mantenimiento recomendadas
echo.
echo ================================================================
echo Dame un RESUMEN EJECUTIVO con las 10 acciones mas importantes
echo ordenadas por impacto, indicando cada una como [BASICO] o
echo [AVANZADO] e incluye el comando exacto de PowerShell o CMD.
echo ================================================================
) > "!TMPFILE!"

:: ── Copiar al portapapeles ───────────────────────────────────
type "!TMPFILE!" | clip
del "!TMPFILE!" >nul 2>&1

echo.
echo  [OK] Prompt copiado al portapapeles.
echo  [OK] Abriendo Claude AI en el navegador...
echo.
echo  Solo presiona Ctrl+V dentro del chat y Enter.
echo.

:: ── Abrir navegador ──────────────────────────────────────────
start https://claude.ai/new

pause
goto :MENU


:: ================================================================
::  OPCION 2 - CAMBIAR NOMBRE DEL DISPOSITIVO
:: ================================================================
:CAMBIAR_NOMBRE
cls
echo.
echo  ================================================================
echo    MODIFICAR NOMBRE DEL DISPOSITIVO
echo  ================================================================
echo.
echo  Nombre actual: !PC_NAME!
echo.
set /p NOMBRE_NUEVO="  Nuevo nombre (max 15 caracteres, sin espacios): "

if "!NOMBRE_NUEVO!"=="" (
    echo  [X] Nombre invalido. Operacion cancelada.
    timeout /t 2 >nul
    goto :MENU
)
if /i "!NOMBRE_NUEVO!"=="!PC_NAME!" (
    echo  [!] El nombre es identico al actual.
    timeout /t 2 >nul
    goto :MENU
)

echo.
set /p CONFIRMAR="  Cambiar '!PC_NAME!' por '!NOMBRE_NUEVO!'? [S/N]: "
if /i not "!CONFIRMAR!"=="S" goto :MENU

echo.
echo  [..] Aplicando cambio...

reg add "HKLM\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName" /v ComputerName /t REG_SZ /d "!NOMBRE_NUEVO!" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" /v ComputerName /t REG_SZ /d "!NOMBRE_NUEVO!" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v Hostname /t REG_SZ /d "!NOMBRE_NUEVO!" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "NV Hostname" /t REG_SZ /d "!NOMBRE_NUEVO!" /f >nul 2>&1
powershell -Command "Rename-Computer -NewName '!NOMBRE_NUEVO!' -Force" >nul 2>&1

echo  [OK] Nombre cambiado a: !NOMBRE_NUEVO!
echo  [!] Reinicia el equipo para aplicar en todas las pantallas.
echo.
set PC_NAME=!NOMBRE_NUEVO!
pause
goto :MENU


:: ================================================================
::  OPCION 3 - EXTRAER INFO Y GUARDAR EN DEVICES REPORT
:: ================================================================
:INFO_DISPOSITIVO
cls
echo.
echo  ================================================================
echo    INFORMACION DEL DISPOSITIVO
echo  ================================================================
echo.
echo  Nombre del equipo : !PC_NAME!
echo  ID Fisico (UUID)  : !UUID!
echo  N. Serie (BIOS)   : !SERIAL!
echo  Direccion IP      : !IP!
echo  Direccion MAC     : !MAC!
echo.

:: ── Guardar en Devices Report.txt (append) ──────────────────
set REPORTE=%~dp0Devices Report.txt
(
    echo ================================================================
    echo  REGISTRO: %date% %time%
    echo ================================================================
    echo  Nombre del equipo : !PC_NAME!
    echo  ID Fisico (UUID)  : !UUID!
    echo  N. Serie (BIOS)   : !SERIAL!
    echo  Direccion IP      : !IP!
    echo  Direccion MAC     : !MAC!
    echo  Sistema Operativo : !OS_NAME!
    echo  CPU               : !CPU!
    echo  RAM               : !RAM_GB! GB
    echo  Disco             : !DISK!
    echo  GPU               : !GPU!
    echo.
) >> "!REPORTE!"

echo  [OK] Registro guardado en: !REPORTE!
echo.
pause
goto :MENU


:: ================================================================
::  SALIR
:: ================================================================
:SALIR
echo.
echo  Hasta luego.
timeout /t 2 >nul
exit /b
