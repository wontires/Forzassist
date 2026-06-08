param(
    [switch]$SkipInstaller,
    [switch]$SkipViGEmDownload,
    [switch]$SkipEmbeddedPrune,
    [string]$PythonVersion = ""
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Write-Step($Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-FolderSizeMB($Path) {
    if (-not (Test-Path $Path)) { return 0 }
    $bytes = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    return [Math]::Round($bytes / 1MB, 1)
}

function Remove-IfExists($Path) {
    if (Test-Path $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Step "Preparing embedded-Python public build"
Write-Host "This build packages the app with the official embedded Python runtime." -ForegroundColor Yellow
Write-Host "The app runs through a renamed copy of pythonw.exe from the official Python embeddable runtime." -ForegroundColor Yellow

Write-Step "Creating build virtual environment"

$CreatedVenv = $false
$CreateAttempts = @(
    @{ Cmd = "py"; Args = @("-3.12", "-m", "venv", ".venv_embed"); Label = "py -3.12" },
    @{ Cmd = "py"; Args = @("-3.11", "-m", "venv", ".venv_embed"); Label = "py -3.11" },
    @{ Cmd = "py"; Args = @("-3", "-m", "venv", ".venv_embed"); Label = "py -3" },
    @{ Cmd = "python"; Args = @("-m", "venv", ".venv_embed"); Label = "python" }
)

Remove-IfExists ".\.venv_embed"

foreach ($Attempt in $CreateAttempts) {
    $cmd = Get-Command $Attempt.Cmd -ErrorAction SilentlyContinue
    if (-not $cmd) {
        continue
    }

    Write-Host "Trying $($Attempt.Label)..." -ForegroundColor Yellow
    & $Attempt.Cmd @($Attempt.Args)

    if ($LASTEXITCODE -eq 0 -and (Test-Path ".\.venv_embed\Scripts\python.exe")) {
        $CreatedVenv = $true
        break
    }

    Remove-IfExists ".\.venv_embed"
}

if (-not $CreatedVenv) {
    throw "Could not create a Python venv. Install Python 3.12 or 3.11, then rerun. Example: winget install Python.Python.3.12"
}

$VenvPython = Join-Path $Root ".venv_embed\Scripts\python.exe"

$DetectedPythonVersion = (& $VenvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')").Trim()
$DetectedPythonMajorMinor = (& $VenvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')").Trim()

if (-not $PythonVersion) {
    $PythonVersion = $DetectedPythonVersion
}

Write-Host "Build Python: $DetectedPythonVersion" -ForegroundColor Green
Write-Host "Embedded Python runtime to download: $PythonVersion" -ForegroundColor Green

if ($DetectedPythonMajorMinor -notin @("3.11", "3.12")) {
    Write-Warning "Detected Python $DetectedPythonMajorMinor. This may work, but Python 3.11 or 3.12 is recommended for this build."
}

Write-Step "Installing minimal embedded-build dependencies into build venv"
$EmbeddedRequirements = Join-Path $Root "requirements.txt"
if (-not (Test-Path $EmbeddedRequirements)) {
    throw "Missing requirements.txt"
}
& $VenvPython -m pip install --upgrade pip
& $VenvPython -m pip install --no-cache-dir -r $EmbeddedRequirements

Write-Step "Cleaning embedded output"
Remove-IfExists ".\dist_embedded"
Remove-IfExists ".\release\Forzassist_Portable.zip"
Remove-IfExists ".\installer\Output\Forzassist_Setup.exe"

$DistRoot = Join-Path $Root "dist_embedded\Forzassist"
$AppOut = Join-Path $DistRoot "app"
$RuntimeOut = Join-Path $DistRoot "runtime"
$SitePackages = Join-Path $RuntimeOut "Lib\site-packages"

New-Item -ItemType Directory -Force -Path $AppOut | Out-Null
New-Item -ItemType Directory -Force -Path $SitePackages | Out-Null

Write-Step "Downloading Python embeddable runtime"
$Tools = Join-Path $Root "tools"
$EmbedRoot = Join-Path $Tools "python-embed-$PythonVersion"
$EmbedZip = Join-Path $Tools "python-$PythonVersion-embed-amd64.zip"
$EmbedUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip"

New-Item -ItemType Directory -Force -Path $Tools | Out-Null

if (-not (Test-Path $EmbedZip)) {
    Write-Host "Downloading: $EmbedUrl" -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $EmbedUrl -OutFile $EmbedZip
    }
    catch {
        throw "Could not download Python embeddable runtime $PythonVersion from $EmbedUrl. If this version is unavailable, rerun with an explicit version you have installed, e.g. .\build_embedded_base.ps1 -PythonVersion 3.12.8"
    }
}

Remove-IfExists $EmbedRoot
New-Item -ItemType Directory -Force -Path $EmbedRoot | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($EmbedZip, $EmbedRoot)

Copy-Item -Path (Join-Path $EmbedRoot "*") -Destination $RuntimeOut -Recurse -Force

Write-Step "Configuring embedded Python search path"
$pth = Get-ChildItem $RuntimeOut -Filter "python*._pth" | Select-Object -First 1
if (-not $pth) {
    throw "Could not find pythonXY._pth inside embedded runtime."
}

$EmbeddedZipName = "python" + $PythonVersion.Split(".")[0] + $PythonVersion.Split(".")[1] + ".zip"

$pthContent = @(
    $EmbeddedZipName,
    ".",
    "Lib\site-packages",
    "..\app",
    "",
    "# Needed so packages with normal site initialization work.",
    "import site"
)
Set-Content -Path $pth.FullName -Value $pthContent -Encoding ASCII

Write-Step "Installing minimal Forzassist dependencies into embedded runtime"
& $VenvPython -m pip install --no-cache-dir --no-compile --target $SitePackages -r $EmbeddedRequirements

Write-Step "Copying Forzassist app files"
Copy-Item ".\Forzassist\main.py" $AppOut -Force
Copy-Item ".\Forzassist\forzassist_backend.py" $AppOut -Force
if (-not (Test-Path (Join-Path $AppOut "forzassist_backend.py"))) { throw "forzassist_backend.py was not copied to app output." }
Copy-Item ".\Forzassist\Main.qml" $AppOut -Force
Copy-Item ".\Forzassist\forzassist.ico" $AppOut -Force

if (Test-Path ".\Forzassist\assets") {
    Copy-Item ".\Forzassist\assets" (Join-Path $AppOut "assets") -Recurse -Force
}

Get-ChildItem ".\Forzassist" -Filter "Inter_18pt-*.ttf" | ForEach-Object {
    Copy-Item $_.FullName $AppOut -Force
}

Copy-Item (Join-Path $RuntimeOut "pythonw.exe") (Join-Path $RuntimeOut "Forzassist.exe") -Force

$cmd = @"
@echo off
cd /d "%~dp0app"
"..\runtime\Forzassist.exe" "%~dp0app\main.py"
"@
Set-Content -Path (Join-Path $DistRoot "Run_Forzassist.cmd") -Value $cmd -Encoding ASCII

$health = @"
@echo off
cd /d "%~dp0app"
"..\runtime\python.exe" "%~dp0app\main.py" --healthcheck
pause
"@
Set-Content -Path (Join-Path $DistRoot "Healthcheck.cmd") -Value $health -Encoding ASCII

Write-Step "Removing build-only packages if present"
foreach ($pkg in @("PyInstaller", "pyinstaller", "altgraph", "pefile", "pyinstaller_hooks_contrib")) {
    Get-ChildItem $SitePackages -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "$pkg*" } |
        ForEach-Object {
            Write-Host "Removing build-only package $($_.FullName)"
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
}

Write-Step "Cleaning embedded runtime junk"
Get-ChildItem $SitePackages -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Get-ChildItem $SitePackages -Recurse -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -in @("tests", "test", "examples", "docs", "doc", "__pycache__") } |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Get-ChildItem $SitePackages -Recurse -File -Include "*.pyc","*.pyo","*.pdb","*.lib","*.exp","*.h","*.hpp","*.cpp","*.c","*.obj","*.pri","*.prl","*.qmltypes","*.pyi","*.typed" -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

Write-Step "Healthcheck embedded runtime"
$Log = Join-Path $env:APPDATA "Forzassist\startup_error.log"
if (Test-Path $Log) { Remove-Item $Log -Force -ErrorAction SilentlyContinue }

$HealthExe = Join-Path $RuntimeOut "python.exe"
$HealthMain = Join-Path $AppOut "main.py"
$p = Start-Process -FilePath $HealthExe -ArgumentList "`"$HealthMain`" --healthcheck" -WorkingDirectory $AppOut -PassThru -WindowStyle Hidden
$finished = $p.WaitForExit(8000)

if (-not $finished) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    throw "Embedded healthcheck timed out."
}

if ($p.ExitCode -ne 0) {
    if (Test-Path $Log) {
        Write-Host "startup_error.log:" -ForegroundColor Yellow
        Get-Content $Log
    }
    throw "Embedded healthcheck failed with exit code $($p.ExitCode)."
}

Write-Host "Embedded healthcheck passed." -ForegroundColor Green

if (-not $SkipEmbeddedPrune) {
    Write-Step "Pruning embedded runtime with healthcheck restore"
    & ".\diagnostics\prune_embedded_runtime.ps1"
}

Write-Step "Creating embedded portable zip"
New-Item -ItemType Directory -Force -Path ".\release" | Out-Null
$ZipPath = Join-Path $Root "release\Forzassist_Portable.zip"
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

$SevenZip = Get-Command 7z.exe -ErrorAction SilentlyContinue
if ($SevenZip) {
    Push-Location ".\dist_embedded"
    & $SevenZip.Source "a" "-t7z" "-mx=9" "-m0=lzma2" "-ms=on" $ZipPath "Forzassist"
    Pop-Location
} else {
    Compress-Archive -Path ".\dist_embedded\Forzassist" -DestinationPath $ZipPath -CompressionLevel Optimal
}

Write-Host ""
Write-Host "Embedded dist size: $(Get-FolderSizeMB $DistRoot) MB" -ForegroundColor Yellow
Write-Host "Embedded runtime size: $(Get-FolderSizeMB $RuntimeOut) MB" -ForegroundColor Yellow
Write-Host "Embedded site-packages size: $(Get-FolderSizeMB $SitePackages) MB" -ForegroundColor Yellow
if (Test-Path $ZipPath) {
    Write-Host "Embedded portable zip: $([Math]::Round((Get-Item $ZipPath).Length / 1MB, 1)) MB" -ForegroundColor Yellow
}

$ViGEmFile = "ViGEmBus_1.22.0_x64_x86_arm64.exe"
$ViGEmUrl = "https://github.com/nefarius/ViGEmBus/releases/download/v1.22.0/$ViGEmFile"
$RedistDir = Join-Path $Root "redist"
$ViGEmPath = Join-Path $RedistDir $ViGEmFile
New-Item -ItemType Directory -Force -Path $RedistDir | Out-Null

if (-not $SkipInstaller -and -not $SkipViGEmDownload -and -not (Test-Path $ViGEmPath)) {
    Write-Step "Downloading ViGEmBus redistributable"
    $downloaded = $false

    for ($attempt = 1; $attempt -le 4; $attempt++) {
        try {
            Write-Host "Attempt $attempt of 4: $ViGEmUrl" -ForegroundColor Yellow
            Invoke-WebRequest -Uri $ViGEmUrl -OutFile $ViGEmPath -UseBasicParsing -TimeoutSec 120
            $downloaded = Test-Path $ViGEmPath
            if ($downloaded) { break }
        }
        catch {
            Write-Warning "ViGEmBus download attempt $attempt failed: $($_.Exception.Message)"
            Start-Sleep -Seconds (5 * $attempt)
        }
    }

    if (-not $downloaded) {
        throw "Could not download ViGEmBus automatically. Download ViGEmBus_1.22.0_x64_x86_arm64.exe manually from the official nefarius/ViGEmBus GitHub release and place it in the redist folder, then rerun build_embedded_base.ps1. Expected path: $ViGEmPath"
    }
}

if (-not $SkipInstaller) {
    Write-Step "Building embedded-Python installer"
    $Iscc = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if (-not $Iscc) {
        $CommonPaths = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe")
        foreach ($Path in $CommonPaths) {
            if (Test-Path $Path) {
                $Iscc = @{ Source = $Path }
                break
            }
        }
    }

    if ($Iscc) {
        if (-not (Test-Path $ViGEmPath)) {
            throw "Cannot build installer because ViGEmBus redistributable is missing: $ViGEmPath"
        }

        & $Iscc.Source ".\installer\Forzassist.iss"

        $Setup = Join-Path $Root "installer\Output\Forzassist_Setup.exe"
        if (Test-Path $Setup) {
            Write-Host ""
            Write-Host "Embedded installer:" -ForegroundColor Green
            Write-Host "  $Setup"
            Write-Host "  $([Math]::Round((Get-Item $Setup).Length / 1MB, 1)) MB" -ForegroundColor Yellow
        }
    } else {
        Write-Warning "Inno Setup was not found. Portable zip was still built."
    }
}

Write-Host ""
Write-Host "VirusTotal scan targets:" -ForegroundColor Cyan
Write-Host "  dist_embedded\Forzassist\runtime\Forzassist.exe"
Write-Host "  installer\Output\Forzassist_Setup.exe"
Write-Host ""
Write-Host "Expected: runtime\Forzassist.exe is just a copy of official pythonw.exe, so it should look far less suspicious than PyInstaller's bootloader." -ForegroundColor Yellow
