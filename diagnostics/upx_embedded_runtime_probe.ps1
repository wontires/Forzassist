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
$Log = Join-Path $Root "release\embedded_upx_probe_log.txt"
New-Item -ItemType Directory -Force -Path (Split-Path $Log) | Out-Null
Remove-Item -LiteralPath $Log -Force -ErrorAction SilentlyContinue

function Write-Log($Message) {
    Write-Host $Message
    Add-Content -Path $Log -Value $Message
}

function SizeMB($Path) {
    if (-not (Test-Path $Path)) { return 0 }
    $bytes = (Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    [Math]::Round($bytes / 1MB, 2)
}

function Ensure-UPX {
    $cmd = Get-Command upx.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $Tools = Join-Path $Root "tools"
    $UpxRoot = Join-Path $Tools "upx"
    New-Item -ItemType Directory -Force -Path $UpxRoot | Out-Null

    $existing = Get-ChildItem -Path $UpxRoot -Recurse -Filter upx.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existing) { return $existing.FullName }

    Write-Log "Downloading latest UPX release from GitHub"

    $TempUpx = Join-Path $Tools ("upx_extract_" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $TempUpx | Out-Null

    try {
        $api = "https://api.github.com/repos/upx/upx/releases/latest"
        $release = Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "ForzassistBuild" }
        $asset = $release.assets | Where-Object { $_.name -match "win64.*\.zip$" } | Select-Object -First 1
        if (-not $asset) { throw "Could not find a win64 UPX zip in the latest UPX release." }

        $zip = Join-Path $TempUpx $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $TempUpx)

        $found = Get-ChildItem -Path $TempUpx -Recurse -Filter upx.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $found) { throw "UPX download completed, but upx.exe was not found." }

        $StableUpx = Join-Path $UpxRoot "upx.exe"
        Copy-Item -LiteralPath $found.FullName -Destination $StableUpx -Force
        return $StableUpx
    }
    finally {
        Remove-Item -LiteralPath $TempUpx -Recurse -Force -ErrorAction SilentlyContinue
    }
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

$Upx = Ensure-UPX

Write-Log "Embedded UPX probe started"
Write-Log "Initial embedded dist size: $(SizeMB $DistRoot) MB"

if (-not (Healthcheck "baseline before embedded UPX probe")) {
    Write-Log "Baseline embedded healthcheck failed. Aborting."
    exit 1
}

$ForbiddenPathRegex = "\\runtime\\Forzassist\.exe$|\\runtime\\pythonw?\.exe$|\\PySide6\\qml\\|\\PySide6\\plugins\\"
$PreferSkipNameRegex = "api-ms-win|ucrtbase|vcruntime|msvcp|concrt|qwindows\.dll"

$Candidates = Get-ChildItem $DistRoot -Recurse -Include *.dll,*.pyd -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch $ForbiddenPathRegex -and
        $_.Name -notmatch $PreferSkipNameRegex -and
        $_.Length -gt 131072
    } |
    Sort-Object Length -Descending

foreach ($f in $Candidates) {
    if (-not (Test-Path $f.FullName)) { continue }

    $before = SizeMB $DistRoot
    Write-Log ""
    Write-Log "Trying embedded UPX: $($f.FullName) / $([Math]::Round($f.Length / 1MB, 2)) MB"

    & $Upx --best --lzma --force $f.FullName 2>$null | Out-Null

    if (Healthcheck "after UPX $($f.Name)") {
        $after = SizeMB $DistRoot
        Write-Log "KEEP COMPRESSED: $($f.Name) / saved about $([Math]::Round($before - $after, 2)) MB"
    } else {
        Write-Log "DECOMPRESSING FAILED FILE: $($f.Name)"
        & $Upx -d $f.FullName 2>$null | Out-Null
        $restored = SizeMB $DistRoot
        Write-Log "RESTORED: $($f.Name) / size now $restored MB"
    }
}

Write-Log ""
Write-Log "Embedded UPX probe complete"
Write-Log "Final embedded dist size: $(SizeMB $DistRoot) MB"
Write-Log "Log written to: $Log"
