#!/usr/bin/env python3
"""
PC Optimizer Agent - Powered by Claude AI
Analiza y optimiza tu PC con Windows mediante inteligencia artificial.
v2.0 - Incluye identidad de equipo, red y tareas automaticas programadas.
"""

import os
import sys
import platform
import subprocess
import socket
import uuid
import json
import re
from datetime import datetime

try:
    import anthropic
except ImportError:
    print("[ERROR] La libreria 'anthropic' no esta instalada.")
    print("Ejecuta: pip install anthropic")
    sys.exit(1)

try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False

try:
    from colorama import init, Fore, Style
    init(autoreset=True)
    COLORS = True
except ImportError:
    COLORS = False

IS_WINDOWS = platform.system() == "Windows"

# ─────────────────────────────────────────────
# Helpers de color y UI
# ─────────────────────────────────────────────
def c(text, color="white", bold=False):
    if not COLORS:
        return text
    colors = {
        "red": Fore.RED, "green": Fore.GREEN, "yellow": Fore.YELLOW,
        "blue": Fore.BLUE, "cyan": Fore.CYAN, "magenta": Fore.MAGENTA,
        "white": Fore.WHITE,
    }
    style = Style.BRIGHT if bold else ""
    return f"{style}{colors.get(color, '')}{text}{Style.RESET_ALL}"

def banner():
    print()
    print(c("=" * 65, "cyan", bold=True))
    print(c("   PC OPTIMIZER AGENT  v2.0  -  Powered by Claude AI", "cyan", bold=True))
    print(c("   Optimizacion inteligente para Windows", "yellow"))
    print(c("=" * 65, "cyan", bold=True))
    print()

def section(title):
    print()
    print(c(f"  [{title}]", "yellow", bold=True))
    print(c("  " + "─" * (len(title) + 4), "yellow"))

def ok(msg):   print(c(f"  [OK] {msg}", "green"))
def warn(msg): print(c(f"  [!]  {msg}", "yellow"))
def err(msg):  print(c(f"  [X]  {msg}", "red"))
def info(msg): print(f"  {msg}")


# ═══════════════════════════════════════════════════════════════
# BLOQUE 1 - IDENTIDAD DEL EQUIPO
# ═══════════════════════════════════════════════════════════════

def get_pc_name() -> str:
    return platform.node()


def change_pc_name(new_name: str) -> bool:
    """Cambia el nombre del equipo via PowerShell (requiere admin y reinicio)."""
    if not IS_WINDOWS:
        err("Cambio de nombre solo disponible en Windows.")
        return False
    try:
        result = subprocess.run(
            ["powershell", "-Command",
             f'Rename-Computer -NewName "{new_name}" -Force'],
            capture_output=True, text=True, timeout=15
        )
        if result.returncode == 0:
            return True
        else:
            err(f"PowerShell: {result.stderr.strip()}")
            return False
    except Exception as e:
        err(f"Error al cambiar nombre: {e}")
        return False


def get_ip_addresses() -> dict:
    """Obtiene IP local (IPv4) e IP publica si hay conexion."""
    ips = {"local": "No disponible", "todas": []}
    try:
        # IP local principal
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ips["local"] = s.getsockname()[0]
        s.close()
    except Exception:
        pass

    # Todas las interfaces
    if PSUTIL_AVAILABLE:
        try:
            for iface, addrs in psutil.net_if_addrs().items():
                for addr in addrs:
                    if addr.family == socket.AF_INET and not addr.address.startswith("127."):
                        ips["todas"].append(f"{iface}: {addr.address}")
        except Exception:
            pass
    return ips


def get_mac_addresses() -> list:
    """Obtiene las direcciones MAC de las interfaces de red activas."""
    macs = []
    if PSUTIL_AVAILABLE:
        try:
            AF_LINK = psutil.AF_LINK if hasattr(psutil, "AF_LINK") else -1
            # En Windows psutil usa -1 para AF_LINK, en Linux 17
            for iface, addrs in psutil.net_if_addrs().items():
                for addr in addrs:
                    # AF_LINK = 18 en macOS, 17 en Linux, psutil.AF_LINK en Windows
                    if addr.family in (17, 18, -1) or (hasattr(psutil, 'AF_LINK') and addr.family == psutil.AF_LINK):
                        mac = addr.address
                        if mac and mac != "00:00:00:00:00:00" and len(mac) >= 17:
                            macs.append(f"{iface}: {mac.upper()}")
        except Exception:
            pass
    if not macs:
        # Fallback usando uuid
        raw = uuid.getnode()
        mac_str = ":".join(f"{(raw >> i) & 0xFF:02X}" for i in range(40, -1, -8))
        macs.append(f"Principal: {mac_str}")
    return macs


def get_serial_number() -> str:
    """Obtiene el numero de serie del equipo via WMIC/PowerShell."""
    if not IS_WINDOWS:
        return "Deteccion solo disponible en Windows"
    # Intentar serie del BIOS
    for cmd in [
        ["wmic", "bios", "get", "SerialNumber"],
        ["powershell", "-Command", "(Get-WmiObject Win32_BIOS).SerialNumber"],
    ]:
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=8)
            lines = [l.strip() for l in result.stdout.splitlines()
                     if l.strip() and l.strip().lower() not in ("serialnumber", "")]
            if lines and lines[0] not in ("To Be Filled By O.E.M.", "Default string", "N/A"):
                return lines[0]
        except Exception:
            pass
    # Intentar serie del sistema (motheboard)
    try:
        result = subprocess.run(
            ["wmic", "csproduct", "get", "IdentifyingNumber"],
            capture_output=True, text=True, timeout=8
        )
        lines = [l.strip() for l in result.stdout.splitlines()
                 if l.strip() and l.strip().lower() != "identifyingnumber"]
        if lines:
            return lines[0]
    except Exception:
        pass
    return "No disponible (puede requerir permisos de administrador)"


def pc_identity_section() -> dict:
    """
    Seccion inicial: muestra identidad del equipo (nombre, IP, MAC, serie)
    y ofrece cambiar el nombre de la PC.
    """
    section("IDENTIDAD DEL EQUIPO")

    pc_name   = get_pc_name()
    ips       = get_ip_addresses()
    macs      = get_mac_addresses()
    serial    = get_serial_number()

    print(f"  {c('Nombre del equipo:', 'cyan', bold=True)} {c(pc_name, 'white', bold=True)}")
    print(f"  {c('IP local principal:', 'cyan')}   {ips['local']}")
    if ips["todas"]:
        for entry in ips["todas"]:
            print(f"  {c('  Interfaz:', 'blue')} {entry}")
    print(f"  {c('Direcciones MAC:', 'cyan')}")
    for mac in macs:
        print(f"    {mac}")
    print(f"  {c('N. de serie (BIOS):', 'cyan')} {serial}")

    # Ofrecer cambio de nombre
    print()
    cambiar = input(
        c("  Deseas cambiar el nombre del equipo? [s/N]: ", "yellow")
    ).strip().lower()

    new_name = pc_name
    if cambiar == "s":
        nuevo = input(
            c("  Nuevo nombre (sin espacios, max 15 caracteres): ", "yellow")
        ).strip()
        nuevo = re.sub(r"[^A-Za-z0-9\-]", "", nuevo)[:15]
        if not nuevo:
            warn("Nombre invalido, se omite el cambio.")
        elif nuevo == pc_name:
            warn("El nombre es identico al actual, no se realiza ningun cambio.")
        else:
            print()
            warn("Esta accion requiere permisos de Administrador y reinicio del equipo.")
            confirmar = input(
                c(f"  Confirmar cambio de '{pc_name}' a '{nuevo}'? [s/N]: ", "yellow")
            ).strip().lower()
            if confirmar == "s":
                if change_pc_name(nuevo):
                    ok(f"Nombre cambiado a '{nuevo}'. Reinicia el equipo para aplicar.")
                    new_name = nuevo
                else:
                    err("No se pudo cambiar el nombre. Ejecuta como Administrador.")
            else:
                info("Cambio de nombre cancelado.")

    return {
        "pc_name": pc_name,
        "new_name": new_name,
        "ip_local": ips["local"],
        "ips_all": ips["todas"],
        "macs": macs,
        "serial": serial,
    }


# ═══════════════════════════════════════════════════════════════
# BLOQUE 2 - DETECCION DEL SISTEMA
# ═══════════════════════════════════════════════════════════════

def get_disk_type() -> str:
    if not IS_WINDOWS:
        return "Desconocido (deteccion solo en Windows)"
    try:
        result = subprocess.run(
            ["powershell", "-Command",
             "Get-PhysicalDisk | Select-Object -First 1 MediaType | ConvertTo-Json"],
            capture_output=True, text=True, timeout=8
        )
        if result.returncode == 0 and result.stdout.strip():
            data = json.loads(result.stdout.strip())
            media = str(data.get("MediaType", ""))
            if "NVMe" in media or media == "3":
                return "NVMe SSD"
            elif "SSD" in media or media == "2":
                return "SSD"
            elif "HDD" in media or media == "3":
                return "HDD"
    except Exception:
        pass
    try:
        result = subprocess.run(
            ["wmic", "diskdrive", "get", "Model,MediaType"],
            capture_output=True, text=True, timeout=8
        )
        out = result.stdout.lower()
        if "nvme" in out:           return "NVMe SSD"
        elif "ssd" in out:          return "SSD"
        elif "hdd" in out:          return "HDD"
    except Exception:
        pass
    return "SSD/HDD (no detectado)"


def get_gpu() -> str:
    if not IS_WINDOWS:
        return "Desconocido (deteccion solo en Windows)"
    try:
        result = subprocess.run(
            ["wmic", "path", "win32_videocontroller", "get", "Name"],
            capture_output=True, text=True, timeout=8
        )
        lines = [l.strip() for l in result.stdout.splitlines()
                 if l.strip() and l.strip().lower() != "name"]
        return " / ".join(lines) if lines else "No detectado"
    except Exception:
        return "No detectado"


def get_ram_gb():
    if PSUTIL_AVAILABLE:
        return round(psutil.virtual_memory().total / (1024 ** 3), 1)
    if IS_WINDOWS:
        try:
            result = subprocess.run(
                ["wmic", "computersystem", "get", "TotalPhysicalMemory"],
                capture_output=True, text=True, timeout=8
            )
            lines = [l.strip() for l in result.stdout.splitlines() if l.strip().isdigit()]
            if lines:
                return round(int(lines[0]) / (1024 ** 3), 1)
        except Exception:
            pass
    return "Desconocido"


def get_cpu() -> str:
    if IS_WINDOWS:
        try:
            result = subprocess.run(
                ["wmic", "cpu", "get", "Name"],
                capture_output=True, text=True, timeout=8
            )
            lines = [l.strip() for l in result.stdout.splitlines()
                     if l.strip() and l.strip().lower() != "name"]
            if lines:
                return lines[0]
        except Exception:
            pass
    return platform.processor() or "Desconocido"


def collect_system_info() -> dict:
    section("DETECTANDO HARDWARE DEL SISTEMA")

    os_ver    = platform.platform()
    ram       = get_ram_gb()
    cpu       = get_cpu()
    disk_type = get_disk_type()
    gpu       = get_gpu()

    print(f"  {c('Sistema Operativo:', 'cyan')} {os_ver}")
    print(f"  {c('RAM instalada:    ', 'cyan')} {ram} GB")
    print(f"  {c('Procesador:       ', 'cyan')} {cpu}")
    print(f"  {c('Tipo de disco:    ', 'cyan')} {disk_type}")
    print(f"  {c('Tarjeta grafica:  ', 'cyan')} {gpu}")

    return {"os": os_ver, "ram_gb": ram, "cpu": cpu, "disk_type": disk_type, "gpu": gpu}


# ═══════════════════════════════════════════════════════════════
# BLOQUE 3 - TAREAS AUTOMATICAS PROGRAMADAS
# ═══════════════════════════════════════════════════════════════

TASKS = {
    "1": {
        "nombre":      "PCOpt_LimpiezaTemporal",
        "descripcion": "Limpieza semanal de archivos temporales (cada Domingo 02:00)",
        "cmd":         r"cmd /c del /q /f /s %TEMP%\* & cleanmgr /sagerun:1",
        "schedule":    "/SC WEEKLY /D SUN /ST 02:00",
        "nivel":       "BASICO",
    },
    "2": {
        "nombre":      "PCOpt_TRIM_Defrag",
        "descripcion": "TRIM/Desfragmentacion mensual (dia 1 de cada mes, 03:00)",
        "cmd":         r"powershell -Command \"Get-PhysicalDisk | ForEach-Object { if ($_.MediaType -eq 'SSD') { Optimize-Volume -DriveLetter C -ReTrim -Verbose } else { defrag C: /U /V } }\"",
        "schedule":    "/SC MONTHLY /D 1 /ST 03:00",
        "nivel":       "BASICO",
    },
    "3": {
        "nombre":      "PCOpt_LimpiezaLogs",
        "descripcion": "Limpieza mensual de logs del sistema (dia 15, 04:00)",
        "cmd":         r"powershell -Command \"wevtutil el | ForEach-Object { wevtutil cl $_ }\"",
        "schedule":    "/SC MONTHLY /D 15 /ST 04:00",
        "nivel":       "AVANZADO",
    },
    "4": {
        "nombre":      "PCOpt_VerificarDisco",
        "descripcion": "Verificacion mensual de salud del disco (dia 20, 05:00)",
        "cmd":         r"powershell -Command \"Get-Volume | Repair-Volume -OfflineScanAndFix\"",
        "schedule":    "/SC MONTHLY /D 20 /ST 05:00",
        "nivel":       "AVANZADO",
    },
    "5": {
        "nombre":      "PCOpt_ActualizarWindows",
        "descripcion": "Buscar actualizaciones de Windows semanalmente (Sabado 01:00)",
        "cmd":         r"powershell -Command \"(New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()\"",
        "schedule":    "/SC WEEKLY /D SAT /ST 01:00",
        "nivel":       "BASICO",
    },
}


def list_existing_tasks() -> list:
    """Devuelve tareas PCOpt_ ya existentes en el Programador de Windows."""
    if not IS_WINDOWS:
        return []
    existing = []
    try:
        result = subprocess.run(
            ["schtasks", "/Query", "/FO", "LIST"],
            capture_output=True, text=True, timeout=10
        )
        for line in result.stdout.splitlines():
            if "PCOpt_" in line:
                name = line.split("\\")[-1].strip() if "\\" in line else line.split(":")[-1].strip()
                existing.append(name)
    except Exception:
        pass
    return existing


def create_scheduled_task(task: dict) -> bool:
    """Crea una tarea en el Programador de tareas de Windows usando schtasks."""
    if not IS_WINDOWS:
        warn("La creacion de tareas programadas solo funciona en Windows.")
        return False
    cmd = (
        f'schtasks /Create /TN "\\PCOptimizer\\{task["nombre"]}" '
        f'/TR "{task["cmd"]}" '
        f'{task["schedule"]} '
        f'/RU SYSTEM /RL HIGHEST /F'
    )
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=15)
        if result.returncode == 0:
            return True
        else:
            err(f"  schtasks: {result.stderr.strip() or result.stdout.strip()}")
            return False
    except Exception as e:
        err(f"  Excepcion: {e}")
        return False


def delete_scheduled_task(task_name: str) -> bool:
    if not IS_WINDOWS:
        return False
    try:
        result = subprocess.run(
            ["schtasks", "/Delete", "/TN", f"\\PCOptimizer\\{task_name}", "/F"],
            capture_output=True, text=True, timeout=10
        )
        return result.returncode == 0
    except Exception:
        return False


def scheduled_tasks_menu():
    """Menu interactivo para gestionar tareas automaticas programadas."""
    section("TAREAS AUTOMATICAS DE MANTENIMIENTO")

    existing = list_existing_tasks()

    print(c("  Tareas disponibles para programar:", "white", bold=True))
    print()
    for key, task in TASKS.items():
        estado = c("[INSTALADA]", "green", bold=True) if task["nombre"] in existing else c("[No instalada]", "white")
        nivel  = c(f"[{task['nivel']}]", "cyan") if task["nivel"] == "BASICO" else c(f"[{task['nivel']}]", "yellow")
        print(f"  {c(key + '.', 'yellow', bold=True)} {nivel} {task['descripcion']}")
        print(f"     {estado}")
        print()

    print(c("  Opciones:", "white", bold=True))
    print("  A  - Instalar TODAS las tareas")
    print("  B  - Instalar solo las BASICAS")
    print("  S  - Seleccionar tareas individualmente (ej: 1,3,5)")
    print("  E  - Eliminar todas las tareas PCOptimizer")
    print("  X  - Omitir / Continuar sin cambios")
    print()

    if not IS_WINDOWS:
        warn("Nota: La instalacion real solo funciona en Windows.")
        warn("En Linux/Mac se simula el proceso.")
        print()

    opcion = input(c("  Tu eleccion: ", "yellow")).strip().upper()

    if opcion == "X" or opcion == "":
        info("Tareas programadas: sin cambios.")
        return

    to_install = []
    if opcion == "A":
        to_install = list(TASKS.keys())
    elif opcion == "B":
        to_install = [k for k, v in TASKS.items() if v["nivel"] == "BASICO"]
    elif opcion == "E":
        print()
        warn("Esta accion eliminara TODAS las tareas del grupo PCOptimizer.")
        conf = input(c("  Confirmar eliminacion? [s/N]: ", "yellow")).strip().lower()
        if conf == "s":
            for task in TASKS.values():
                if delete_scheduled_task(task["nombre"]):
                    ok(f"Eliminada: {task['nombre']}")
                else:
                    warn(f"No encontrada o error: {task['nombre']}")
        return
    else:
        # Seleccion individual: "1,3" o "1 3"
        nums = re.findall(r"\d", opcion)
        to_install = [n for n in nums if n in TASKS]
        if not to_install:
            warn("Seleccion no valida. Sin cambios.")
            return

    if not to_install:
        warn("No hay tareas en la seleccion.")
        return

    print()
    warn("La creacion de tareas requiere permisos de Administrador.")
    warn("Si el agente no esta corriendo como Admin, las tareas fallaran.")
    print()
    conf = input(c("  Confirmar instalacion de tareas seleccionadas? [S/n]: ", "yellow")).strip().lower()
    if conf == "n":
        info("Instalacion cancelada.")
        return

    print()
    created, failed = 0, 0
    for key in to_install:
        task = TASKS[key]
        info(f"Instalando: {task['nombre']}...")
        if create_scheduled_task(task):
            ok(f"Tarea creada: {task['nombre']}")
            created += 1
        else:
            err(f"Fallo al crear: {task['nombre']}")
            failed += 1

    print()
    if created:
        ok(f"{created} tarea(s) programadas correctamente en el Programador de tareas de Windows.")
        ok("Puedes verlas en: Programador de tareas > PCOptimizer")
    if failed:
        warn(f"{failed} tarea(s) fallaron. Asegurate de ejecutar como Administrador.")


# ═══════════════════════════════════════════════════════════════
# BLOQUE 4 - INFORMACION ADICIONAL DEL USUARIO
# ═══════════════════════════════════════════════════════════════

def ask_user_info() -> dict:
    section("INFORMACION ADICIONAL  (Enter para omitir)")

    uso = input(
        f"  {c('Uso principal', 'yellow')} [gaming/trabajo/diseno/general]: "
    ).strip() or "uso general"

    apps = input(
        f"  {c('Aplicaciones que mas usas', 'yellow')} [Chrome, Office, Spotify...]: "
    ).strip() or "no especificado"

    problemas = input(
        f"  {c('Problemas que notas', 'yellow')} [lentitud, alto RAM, etc.]: "
    ).strip() or "ninguno especificado"

    return {"uso": uso, "apps": apps, "problemas": problemas}


# ═══════════════════════════════════════════════════════════════
# BLOQUE 5 - AGENTE CLAUDE AI
# ═══════════════════════════════════════════════════════════════

SYSTEM_PROMPT = """Eres un experto en administracion de sistemas Windows con mas de 15 anos de experiencia
en optimizacion de rendimiento, seguridad y mantenimiento de equipos.
Tu objetivo es analizar la informacion del PC del usuario y proporcionar recomendaciones
especificas, practicas y seguras.
Siempre indica claramente si una accion requiere conocimientos tecnicos avanzados (AVANZADO)
o si es apta para cualquier usuario (BASICO). Usa secciones claras con emojis y formato estructurado.
Responde siempre en espanol."""


def build_user_prompt(sys_info: dict, identity: dict, user_info: dict) -> str:
    macs_str = " | ".join(identity.get("macs", []))
    ips_str  = " | ".join(identity.get("ips_all", [identity.get("ip_local", "N/A")]))

    return f"""Analiza mi PC Windows y dame un plan completo de optimizacion:

### IDENTIDAD DEL EQUIPO:
- **Nombre del equipo:** {identity['pc_name']}
- **IP local:** {identity['ip_local']}
- **Interfaces de red:** {ips_str}
- **Direcciones MAC:** {macs_str}
- **Numero de serie:** {identity['serial']}

### HARDWARE DETECTADO:
- **Sistema Operativo:** {sys_info['os']}
- **RAM instalada:** {sys_info['ram_gb']} GB
- **Tipo de disco:** {sys_info['disk_type']}
- **Procesador:** {sys_info['cpu']}
- **Tarjeta grafica:** {sys_info['gpu']}

### USO DEL EQUIPO:
- **Uso principal:** {user_info['uso']}
- **Aplicaciones frecuentes:** {user_info['apps']}
- **Problemas reportados:** {user_info['problemas']}

---
Por favor cubre TODAS estas areas con recomendaciones especificas para mi hardware:

### 1. RENDIMIENTO GENERAL
- Procesos de inicio (startup) a deshabilitar segun mi uso
- Plan de energia optimo para mi CPU
- Ajustes visuales para priorizar rendimiento
- Configuraciones de Registro (regedit) utiles
- Optimizacion del archivo de paginacion segun mi RAM ({sys_info['ram_gb']} GB)

### 2. FIREWALL Y SEGURIDAD
- Reglas de Firewall recomendadas para mi uso ({user_info['uso']})
- Servicios de Windows a deshabilitar para reducir superficie de ataque
- Herramientas gratuitas de seguridad recomendadas
- Configuracion optima de UAC
- Como verificar procesos sospechosos (comandos exactos)

### 3. GESTION Y DESINSTALACION DE APLICACIONES
- Como identificar apps no usadas en 30/60/90 dias (PowerShell)
- Lista de bloatware de Windows seguro de eliminar
- Herramientas para desinstalacion limpia
- Como limpiar el registro post-desinstalacion

### 4. OPTIMIZACION DE MEMORIA RAM ({sys_info['ram_gb']} GB)
- Procesos que consumen mas RAM y como gestionarlos
- Configuraciones para liberar RAM automaticamente
- Evaluacion de software de optimizacion de RAM (vale la pena o no?)
- Servicios de Windows que liberan memoria innecesaria
- Comandos PowerShell/CMD para monitoreo de memoria en tiempo real

### 5. LIMPIEZA Y MANTENIMIENTO
- Limpieza de archivos temporales, cache y logs del sistema (comandos exactos)
- {'TRIM para SSD' if 'SSD' in sys_info['disk_type'] or 'NVMe' in sys_info['disk_type'] else 'Desfragmentacion para HDD'} segun mi disco ({sys_info['disk_type']})
- Complementa las siguientes tareas automaticas que ya configure en el Programador de tareas:
  * Limpieza semanal de temporales (Domingo 02:00)
  * TRIM/Defrag mensual (dia 1, 03:00)
  * Limpieza mensual de logs (dia 15, 04:00)
  * Verificacion de disco mensual (dia 20, 05:00)
  * Busqueda de actualizaciones semanal (Sabado 01:00)

### 6. CONFIGURACION DE RED (basado en mi IP: {identity['ip_local']})
- Ajustes de red para mejorar rendimiento segun mi uso
- Configuraciones DNS recomendadas
- Como verificar si mi MAC ({macs_str[:50] if macs_str else 'N/A'}) esta siendo usada en dispositivos no autorizados

---
RESUMEN EJECUTIVO FINAL: Las 10 acciones mas importantes ordenadas por impacto,
marcando cada una como [BASICO] o [AVANZADO], e incluye el comando exacto de PowerShell o CMD
para cada accion donde sea posible."""


def run_agent(sys_info: dict, identity: dict, user_info: dict) -> str:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print()
        err("No se encontro la variable ANTHROPIC_API_KEY.")
        print(c("  Configura tu API Key con uno de estos metodos:", "yellow"))
        print(c("  CMD:        set ANTHROPIC_API_KEY=sk-ant-...", "white"))
        print(c("  PowerShell: $env:ANTHROPIC_API_KEY='sk-ant-...'", "white"))
        print(c("  Linux/Mac:  export ANTHROPIC_API_KEY=sk-ant-...", "white"))
        print()
        api_key = input(c("  O ingresala ahora: ", "yellow")).strip()
        if not api_key:
            sys.exit(1)

    client = anthropic.Anthropic(api_key=api_key)
    prompt = build_user_prompt(sys_info, identity, user_info)

    section("CONSULTANDO AGENTE CLAUDE AI")
    print(c("  Analizando tu sistema, espera 20-60 segundos...", "cyan"))
    print()
    print(c("=" * 65, "green", bold=True))
    print()

    chunks = []
    with client.messages.stream(
        model="claude-opus-4-6",
        max_tokens=8192,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
    ) as stream:
        for text in stream.text_stream:
            print(text, end="", flush=True)
            chunks.append(text)

    print()
    print()
    print(c("=" * 65, "green", bold=True))
    return "".join(chunks)


# ═══════════════════════════════════════════════════════════════
# BLOQUE 6 - GUARDAR REPORTE
# ═══════════════════════════════════════════════════════════════

def save_report(response: str, sys_info: dict, identity: dict) -> str:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename  = f"pc_optimizer_report_{timestamp}.txt"

    header = f"""PC OPTIMIZER AGENT v2.0 - REPORTE DE OPTIMIZACION
Generado   : {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
Equipo     : {identity['pc_name']}
IP local   : {identity['ip_local']}
MAC        : {', '.join(identity['macs'])}
Serie      : {identity['serial']}
S.O.       : {sys_info['os']}
CPU        : {sys_info['cpu']}
RAM        : {sys_info['ram_gb']} GB
Disco      : {sys_info['disk_type']}
GPU        : {sys_info['gpu']}
{"=" * 65}

"""
    with open(filename, "w", encoding="utf-8") as f:
        f.write(header + response)
    return filename


# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════

def main():
    banner()

    # 1. Identidad del equipo (nombre, IP, MAC, serie)
    identity = pc_identity_section()

    # 2. Hardware del sistema
    sys_info = collect_system_info()

    # 3. Tareas automaticas programadas
    scheduled_tasks_menu()

    # 4. Informacion adicional del usuario
    user_info = ask_user_info()

    # 5. Confirmar e iniciar analisis
    print()
    input(c("  Presiona ENTER para iniciar el analisis completo con Claude AI...", "green", bold=True))

    # 6. Ejecutar agente con streaming
    response = run_agent(sys_info, identity, user_info)

    # 7. Guardar reporte
    print()
    save_opt = input(c("  Guardar reporte en archivo .txt? [S/n]: ", "yellow")).strip().lower()
    if save_opt != "n":
        filename = save_report(response, sys_info, identity)
        ok(f"Reporte guardado: {filename}")

    print()
    print(c("  Optimizacion completada. Buena suerte con tu PC!", "cyan", bold=True))
    print()
    input("  Presiona ENTER para salir...")


if __name__ == "__main__":
    main()
