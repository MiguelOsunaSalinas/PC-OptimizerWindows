# ================================================================
#  PC OPTIMIZER AGENT - Instalador
#  Uso: irm https://raw.githubusercontent.com/MiguelOsunaSalinas/PC-OptimizerWindows/main/install.ps1 | iex
# ================================================================

$BAT_URL  = "https://raw.githubusercontent.com/MiguelOsunaSalinas/PC-OptimizerWindows/main/PCOptimizer.bat"
$DEST     = "$env:TEMP\PCOptimizer.bat"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   PC OPTIMIZER AGENT  -  Descargando..." -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

try {
    Invoke-WebRequest -Uri $BAT_URL -OutFile $DEST -UseBasicParsing
    Write-Host "  [OK] Descargado correctamente." -ForegroundColor Green
    Write-Host "  [OK] Iniciando como Administrador..." -ForegroundColor Green
    Write-Host ""
    Start-Process -FilePath $DEST -Verb RunAs
} catch {
    Write-Host "  [X] Error al descargar: $_" -ForegroundColor Red
}
