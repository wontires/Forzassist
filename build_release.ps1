param(
    [switch]$SkipInstaller,
    [switch]$SkipUPX,
    [switch]$SkipViGEmDownload
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

Write-Host ""
Write-Host "==> Building embedded Essentials public base" -ForegroundColor Cyan
& ".\build_embedded_base.ps1" -SkipInstaller -SkipViGEmDownload

Write-Host ""
Write-Host "==> Embedded size audit before compact pass" -ForegroundColor Cyan
& ".\diagnostics\embedded_size_audit.ps1"

if (-not $SkipUPX) {
    Write-Host ""
    Write-Host "==> Embedded runtime UPX probe" -ForegroundColor Cyan
    & ".\diagnostics\upx_embedded_runtime_probe.ps1"
}

Write-Host ""
Write-Host "==> Embedded size audit after compact pass" -ForegroundColor Cyan
& ".\diagnostics\embedded_size_audit.ps1"

Write-Host ""
Write-Host "==> Creating compact embedded portable archive" -ForegroundColor Cyan
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

if (Test-Path $ZipPath) {
    Write-Host "Compact embedded portable archive:" -ForegroundColor Green
    Write-Host "  $ZipPath"
    Write-Host "  $([Math]::Round((Get-Item $ZipPath).Length / 1MB, 1)) MB" -ForegroundColor Yellow
}

if (-not $SkipInstaller) {
    Write-Host ""
    Write-Host "==> Building compact embedded installer" -ForegroundColor Cyan

    $ViGEmFile = "ViGEmBus_1.22.0_x64_x86_arm64.exe"
    $ViGEmUrl = "https://github.com/nefarius/ViGEmBus/releases/download/v1.22.0/$ViGEmFile"
    $RedistDir = Join-Path $Root "redist"
    $ViGEmPath = Join-Path $RedistDir $ViGEmFile
    New-Item -ItemType Directory -Force -Path $RedistDir | Out-Null

    if (-not $SkipViGEmDownload -and -not (Test-Path $ViGEmPath)) {
        Write-Host "Downloading ViGEmBus redistributable..." -ForegroundColor Cyan
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
            throw "Could not download ViGEmBus automatically. Download ViGEmBus_1.22.0_x64_x86_arm64.exe manually from the official nefarius/ViGEmBus GitHub release and place it in the redist folder, then rerun build_release.ps1. Expected path: $ViGEmPath"
        }
    }

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

        Remove-Item -Recurse -Force ".\installer\Output" -ErrorAction SilentlyContinue
        & $Iscc.Source ".\installer\Forzassist.iss"

        $Setup = Join-Path $Root "installer\Output\Forzassist_Setup.exe"
        if (Test-Path $Setup) {
            Write-Host ""
            Write-Host "Compact embedded installer:" -ForegroundColor Green
            Write-Host "  $Setup"
            Write-Host "  $([Math]::Round((Get-Item $Setup).Length / 1MB, 1)) MB" -ForegroundColor Yellow
        }
    } else {
        Write-Warning "Inno Setup was not found. Portable archive was still built."
    }
}

Write-Host ""
Write-Host "Scan targets:" -ForegroundColor Cyan
Write-Host "  installer\Output\Forzassist_Setup.exe"
Write-Host "  dist_embedded\Forzassist\runtime\Forzassist.exe"
Write-Host ""
Write-Host "Logs:" -ForegroundColor Cyan
Write-Host "  release\embedded_prune_log.txt"
Write-Host "  release\embedded_upx_probe_log.txt"
