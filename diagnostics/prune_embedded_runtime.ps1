$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$DistRootResolved = Resolve-Path ".\dist_embedded\Forzassist" -ErrorAction SilentlyContinue
if (-not $DistRootResolved) {
    Write-Host "Missing .\dist_embedded\Forzassist. Build embedded first." -ForegroundColor Red
    exit 1
}

$DistRoot = $DistRootResolved.Path
$Runtime = Join-Path $DistRoot "runtime"
$App = Join-Path $DistRoot "app"
$Site = Join-Path $Runtime "Lib\site-packages"
$PySide = Join-Path $Site "PySide6"
$Log = Join-Path $Root "release\embedded_prune_log.txt"
$QuarantineRoot = Join-Path $Root "release\quarantine_embedded_prune"

New-Item -ItemType Directory -Force -Path (Split-Path $Log) | Out-Null
Remove-Item -LiteralPath $Log -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $QuarantineRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $QuarantineRoot | Out-Null

function Write-Log($Message) {
    Write-Host $Message
    Add-Content -Path $Log -Value $Message
}

function SizeMB($Path) {
    if (-not (Test-Path $Path)) { return 0 }
    $bytes = (Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    [Math]::Round($bytes / 1MB, 2)
}

function Healthcheck($Label) {
    $AppLog = Join-Path $env:APPDATA "Forzassist\startup_error.log"
    if (Test-Path $AppLog) { Remove-Item $AppLog -Force -ErrorAction SilentlyContinue }

    $Py = Join-Path $Runtime "python.exe"
    $Main = Join-Path $App "main.py"

    $p = Start-Process `
        -FilePath $Py `
        -ArgumentList "`"$Main`" --healthcheck" `
        -WorkingDirectory $App `
        -PassThru `
        -WindowStyle Hidden

    $finished = $p.WaitForExit(9000)

    if (-not $finished) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        Write-Log "FAIL: $Label / healthcheck timed out"
        if (Test-Path $AppLog) {
            Write-Log "startup_error.log:"
            Get-Content $AppLog | ForEach-Object { Write-Log "  $_" }
        }
        return $false
    }

    if ($p.ExitCode -eq 0) {
        Write-Log "PASS: $Label"
        return $true
    }

    Write-Log "FAIL: $Label / ExitCode=$($p.ExitCode)"
    if (Test-Path $AppLog) {
        Write-Log "startup_error.log:"
        Get-Content $AppLog | ForEach-Object { Write-Log "  $_" }
    }
    return $false
}

function RelativePath($Path) {
    $full = (Resolve-Path -LiteralPath $Path).Path
    return $full.Substring($DistRoot.Length).TrimStart("\")
}

function Quarantine-Item($Path) {
    $rel = RelativePath $Path
    $dest = Join-Path $QuarantineRoot $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    Move-Item -LiteralPath $Path -Destination $dest -Force
    return $dest
}

function Restore-Item($QuarantinePath, $OriginalPath) {
    New-Item -ItemType Directory -Force -Path (Split-Path $OriginalPath) | Out-Null
    Move-Item -LiteralPath $QuarantinePath -Destination $OriginalPath -Force
}

function Try-Prune($Path, $Label) {
    if (-not (Test-Path $Path)) {
        Write-Log "SKIP missing: $Label -> $Path"
        return
    }

    $before = SizeMB $DistRoot
    $itemSize = SizeMB $Path

    Write-Log ""
    Write-Log "Trying embedded prune: $Label ($itemSize MB)"
    Write-Log "  Path: $Path"

    $original = (Resolve-Path -LiteralPath $Path).Path
    $q = Quarantine-Item $original
    $afterMove = SizeMB $DistRoot
    Write-Log "  Size after removing candidate: $afterMove MB"

    if (Healthcheck "after pruning $Label") {
        $after = SizeMB $DistRoot
        Write-Log "KEEP REMOVED: $Label / saved about $([Math]::Round($before - $after, 2)) MB"
    } else {
        Restore-Item $q $original
        $afterRestore = SizeMB $DistRoot
        Write-Log "RESTORED: $Label / size back to $afterRestore MB"
    }
}

Write-Log "Embedded runtime prune started"
Write-Log "Initial embedded dist size: $(SizeMB $DistRoot) MB"
Write-Log "Runtime size: $(SizeMB $Runtime) MB"
Write-Log "Site-packages size: $(SizeMB $Site) MB"
Write-Log "PySide6 size: $(SizeMB $PySide) MB"

if (-not (Healthcheck "baseline before embedded prune")) {
    Write-Log "Baseline embedded healthcheck failed. Aborting prune."
    exit 1
}

Write-Log ""
Write-Log "Removing generic junk files/directories without individual tests..."
Get-ChildItem $Runtime -Recurse -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -in @("__pycache__", "tests", "test", "examples", "docs", "doc", "include", "qmltooling", "translations", "phrasebooks", "objects-Debug", "objects-Release", "objects-RelWithDebInfo", ".qt") } |
    Sort-Object FullName -Descending |
    ForEach-Object {
        Write-Log "  deleting dir $($_.FullName)"
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

Get-ChildItem $Runtime -Recurse -File -Include "*.pyc","*.pyo","*.pdb","*.lib","*.exp","*.h","*.hpp","*.cpp","*.c","*.obj","*.pri","*.prl","*.qmltypes","*.pyi","*.typed","*.map","*.debug","*.qm" -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

if (-not (Healthcheck "after generic junk cleanup")) {
    Write-Log "Generic cleanup broke healthcheck. Aborting before further pruning."
    exit 1
}

Get-ChildItem $Site -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match "\.(dist-info|egg-info)$" } |
    Sort-Object Name |
    ForEach-Object {
        Try-Prune $_.FullName "Python package metadata: $($_.Name)"
    }

$PluginRoot = Join-Path $PySide "plugins"
foreach ($name in @("styles", "iconengines", "generic", "networkinformation", "tls", "platformthemes", "printsupport", "sqldrivers", "qmltooling", "multimedia", "mediaservice", "audio", "video", "designer")) {
    Try-Prune (Join-Path $PluginRoot $name) "Qt plugin category: $name"
}

$Img = Join-Path $PluginRoot "imageformats"
foreach ($dll in @("qgif.dll", "qjpeg.dll", "qwebp.dll", "qsvg.dll", "qtiff.dll")) {
    Try-Prune (Join-Path $Img $dll) "imageformat plugin: $dll"
}

$QmlRoot = Join-Path $PySide "qml"
if (Test-Path $QmlRoot) {
    Get-ChildItem $QmlRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("QtQml", "QtQuick", "builtins", "jsroot") } |
        Sort-Object Name |
        ForEach-Object {
            Try-Prune $_.FullName "QML root: $($_.Name)"
        }

    $QtQuick = Join-Path $QmlRoot "QtQuick"
    if (Test-Path $QtQuick) {
        Get-ChildItem $QtQuick -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin @("Window") } |
            Sort-Object Name |
            ForEach-Object {
                Try-Prune $_.FullName "QtQuick submodule: $($_.Name)"
            }
    }

    $QtQml = Join-Path $QmlRoot "QtQml"
    if (Test-Path $QtQml) {
        Get-ChildItem $QtQml -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name |
            ForEach-Object {
                Try-Prune $_.FullName "QtQml submodule: $($_.Name)"
            }
    }
}

$KeepPySidePyd = @(
    "QtCore.pyd",
    "QtGui.pyd",
    "QtQml.pyd",
    "QtQuick.pyd",
    "QtQuickTemplates2.pyd"
)

if (Test-Path $PySide) {
    Get-ChildItem $PySide -File -Filter "*.pyd" -ErrorAction SilentlyContinue |
        Where-Object { $KeepPySidePyd -notcontains $_.Name } |
        Sort-Object Length -Descending |
        ForEach-Object {
            Try-Prune $_.FullName "PySide6 module: $($_.Name)"
        }
}

$KeepQtDllRegex = "Qt6Core|Qt6Gui|Qt6Qml|Qt6QmlModels|Qt6QmlWorkerScript|Qt6Network|Qt6OpenGL|Qt6Quick|Qt6QuickTemplates2|Qt6ShaderTools|Qt6LabsAnimation|Qt6LabsPlatform"
if (Test-Path $PySide) {
    Get-ChildItem $PySide -File -Filter "Qt6*.dll" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch $KeepQtDllRegex } |
        Sort-Object Length -Descending |
        ForEach-Object {
            Try-Prune $_.FullName "Qt DLL: $($_.Name)"
        }
}

foreach ($rel in @(
    "DLLs\_bz2.pyd",
    "DLLs\_lzma.pyd",
    "DLLs\_decimal.pyd",
    "DLLs\_hashlib.pyd",
    "DLLs\_ssl.pyd",
    "DLLs\_sqlite3.pyd",
    "DLLs\unicodedata.pyd",
    "libcrypto-3.dll",
    "libssl-3.dll"
)) {
    Try-Prune (Join-Path $Runtime $rel) "embedded Python optional file: $rel"
}

Write-Log ""
Write-Log "Embedded runtime prune complete"
Write-Log "Final embedded dist size: $(SizeMB $DistRoot) MB"
Write-Log "Runtime size: $(SizeMB $Runtime) MB"
Write-Log "Site-packages size: $(SizeMB $Site) MB"
Write-Log "PySide6 size: $(SizeMB $PySide) MB"
Write-Log "Log written to: $Log"
