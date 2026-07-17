# ============================================================
#  LimpiezaSistema.ps1
#  Limpieza de archivos temporales, cache y papelera
#  SIN requerir permisos elevados (UAC)
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

# ── Colores para consola ─────────────────────────────────────
function Write-Header { param([string]$msg)
    Write-Host "`n━━━ $msg ━━━" -ForegroundColor Cyan }

function Write-Ok { param([string]$msg)
    Write-Host "  ✓ $msg" -ForegroundColor Green }

function Write-Skip { param([string]$msg)
    Write-Host "  · $msg" -ForegroundColor DarkGray }

function Write-Fail { param([string]$msg)
    Write-Host "  ✗ $msg" -ForegroundColor Yellow }

# ── Función de limpieza ──────────────────────────────────────
function Remove-Items {
    param([string]$Descripcion, [string[]]$Rutas, [string]$Patron = "*")
    Write-Header $Descripcion
    foreach ($ruta in $Rutas) {
        $expandida = [System.Environment]::ExpandEnvironmentVariables($ruta)
        if (-not (Test-Path $expandida)) {
            Write-Skip "No existe: $expandida"
            continue
        }
        $items = Get-ChildItem -Path $expandida -Filter $Patron -Recurse -Force `
                               -ErrorAction SilentlyContinue
        $count = 0
        foreach ($item in $items) {
            try {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                $count++
            } catch {
                # Archivo en uso o sin permiso — se omite silenciosamente
            }
        }
        Write-Ok "$count elemento(s) eliminados en: $expandida"
    }
}

# ── Calcular espacio libre antes ─────────────────────────────
function Get-FreeGB {
    $drive = (Get-Location).Drive.Name + ":"
    $disk  = Get-PSDrive -Name (Get-Location).Drive.Name
    return [math]::Round($disk.Free / 1GB, 2)
}

$antesGB = Get-FreeGB
Write-Host "`n╔══════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host   "║   Limpieza del Sistema — Sin UAC     ║" -ForegroundColor Magenta
Write-Host   "╚══════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host "  Espacio libre antes: $antesGB GB`n"

# ════════════════════════════════════════════════════════════
#  1. TEMPORALES DEL USUARIO
# ════════════════════════════════════════════════════════════
Remove-Items "Temporales del usuario (%TEMP%)" @("%TEMP%")

# ════════════════════════════════════════════════════════════
#  2. TEMPORALES DE INTERNET (IE / EDGE LEGACY)
# ════════════════════════════════════════════════════════════
Remove-Items "Caché de Internet Explorer / Edge legacy" @(
    "%LOCALAPPDATA%\Microsoft\Windows\INetCache",
    "%LOCALAPPDATA%\Microsoft\Windows\Temporary Internet Files"
)

# ════════════════════════════════════════════════════════════
#  3. EDGE (CHROMIUM)
# ════════════════════════════════════════════════════════════
Remove-Items "Caché Microsoft Edge (Chromium)" @(
    "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache",
    "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Code Cache",
    "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\GPUCache"
)

# ════════════════════════════════════════════════════════════
#  4. GOOGLE CHROME
# ════════════════════════════════════════════════════════════
Remove-Items "Caché Google Chrome" @(
    "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache",
    "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Code Cache",
    "%LOCALAPPDATA%\Google\Chrome\User Data\Default\GPUCache"
)

# ════════════════════════════════════════════════════════════
#  5. FIREFOX
# ════════════════════════════════════════════════════════════
Write-Header "Caché Firefox"
$ffProfiles = "%APPDATA%\Mozilla\Firefox\Profiles"
$ffExpanded = [System.Environment]::ExpandEnvironmentVariables($ffProfiles)
if (Test-Path $ffExpanded) {
    $ffCaches = Get-ChildItem -Path $ffExpanded -Directory |
                ForEach-Object { $_.FullName + "\cache2" }
    Remove-Items "Firefox cache2" $ffCaches
} else {
    Write-Skip "Firefox no encontrado"
}

# ════════════════════════════════════════════════════════════
#  6. THUMBNAILS DE WINDOWS EXPLORER
# ════════════════════════════════════════════════════════════
Remove-Items "Miniaturas (thumbnails)" @(
    "%LOCALAPPDATA%\Microsoft\Windows\Explorer"
) "thumbcache_*.db"

# ════════════════════════════════════════════════════════════
#  7. PREFETCH (solo si no requiere admin; Windows lo ignora si falla)
# ════════════════════════════════════════════════════════════
Remove-Items "Prefetch" @("C:\Windows\Prefetch") "*.pf"

# ════════════════════════════════════════════════════════════
#  8. LOGS DE APLICACIONES DEL USUARIO
# ════════════════════════════════════════════════════════════
Remove-Items "Logs de usuario (%LOCALAPPDATA%\Temp)" @(
    "%LOCALAPPDATA%\Temp"
)

# ════════════════════════════════════════════════════════════
#  9. ONEDRIVE — caché local de sincronización
# ════════════════════════════════════════════════════════════
Write-Header "OneDrive — caché"
$odPaths = @(
    "%LOCALAPPDATA%\Microsoft\OneDrive\logs",
    "%LOCALAPPDATA%\Microsoft\OneDrive\setup\logs",
    "%APPDATA%\Microsoft\OneDrive\logs"
)
Remove-Items "OneDrive logs" $odPaths

# Archivos temporales de sync (.tmp) en la carpeta de OneDrive
$odFolder = "$env:USERPROFILE\OneDrive"
if (Test-Path $odFolder) {
    Remove-Items "OneDrive archivos .tmp" @($odFolder) "*.tmp"
}

# ════════════════════════════════════════════════════════════
#  10. TEAMS / OUTLOOK / OFFICE CACHE
# ════════════════════════════════════════════════════════════
Remove-Items "Microsoft Teams caché" @(
    "%APPDATA%\Microsoft\Teams\Cache",
    "%APPDATA%\Microsoft\Teams\blob_storage",
    "%APPDATA%\Microsoft\Teams\databases",
    "%APPDATA%\Microsoft\Teams\GPUCache",
    "%APPDATA%\Microsoft\Teams\IndexedDB",
    "%APPDATA%\Microsoft\Teams\Local Storage",
    "%APPDATA%\Microsoft\Teams\tmp"
)

Remove-Items "Office caché" @(
    "%LOCALAPPDATA%\Microsoft\Office\16.0\OfficeFileCache",
    "%APPDATA%\Microsoft\Office\Recent"
)

# ════════════════════════════════════════════════════════════
#  11. PAPELERA DE RECICLAJE (solo del usuario actual)
# ════════════════════════════════════════════════════════════
Write-Header "Papelera de reciclaje"
try {
    $shell = New-Object -ComObject Shell.Application
    $recycle = $shell.Namespace(0xA)   # 0xA = Recycle Bin
    $recycle.Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force }
    Write-Ok "Papelera vaciada"
} catch {
    Write-Fail "No se pudo vaciar la papelera: $_"
}

# ════════════════════════════════════════════════════════════
#  12. MINIDUMPS DEL USUARIO
# ════════════════════════════════════════════════════════════
Remove-Items "MiniDumps" @(
    "%LOCALAPPDATA%\CrashDumps",
    "%APPDATA%\Microsoft\Windows\WER\ReportQueue",
    "%APPDATA%\Microsoft\Windows\WER\ReportArchive"
)

# ════════════════════════════════════════════════════════════
#  RESUMEN FINAL
# ════════════════════════════════════════════════════════════
$despuesGB  = Get-FreeGB
$liberadoMB = [math]::Round(($despuesGB - $antesGB) * 1024, 1)

Write-Host "`n╔══════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host   "║            RESUMEN FINAL             ║" -ForegroundColor Magenta
Write-Host   "╚══════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host "  Espacio libre antes : $antesGB GB"
Write-Host "  Espacio libre ahora : $despuesGB GB"
if ($liberadoMB -gt 0) {
    Write-Host "  Espacio liberado    : $liberadoMB MB" -ForegroundColor Green
} else {
    Write-Host "  (los archivos en uso serán eliminados al reiniciar)" -ForegroundColor Yellow
}
Write-Host "`n  Limpieza completada. Presiona cualquier tecla para salir..."
[void][System.Console]::ReadKey($true)
