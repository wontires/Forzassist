$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$DistRoot = ".\dist_embedded\Forzassist"
if (-not (Test-Path $DistRoot)) {
    Write-Host "Missing $DistRoot. Build embedded first." -ForegroundColor Red
    exit 1
}

function SizeMB($Path) {
    if (-not (Test-Path $Path)) { return 0 }
    $bytes = (Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    [Math]::Round($bytes / 1MB, 2)
}

Write-Host ""
Write-Host "Embedded total size: $(SizeMB $DistRoot) MB" -ForegroundColor Yellow

Write-Host ""
Write-Host "Top 60 embedded files:" -ForegroundColor Cyan
Get-ChildItem $DistRoot -Recurse -File -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending |
    Select-Object -First 60 FullName,@{Name="MB";Expression={[Math]::Round($_.Length / 1MB, 2)}} |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Top folders:" -ForegroundColor Cyan
Get-ChildItem $DistRoot -Directory -ErrorAction SilentlyContinue |
    ForEach-Object {
        [PSCustomObject]@{
            Folder = $_.Name
            MB = SizeMB $_.FullName
        }
    } |
    Sort-Object MB -Descending |
    Format-Table -AutoSize

$Site = Join-Path $DistRoot "runtime\Lib\site-packages"
if (Test-Path $Site) {
    Write-Host ""
    Write-Host "site-packages top folders:" -ForegroundColor Cyan
    Get-ChildItem $Site -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
            [PSCustomObject]@{
                Folder = $_.Name
                MB = SizeMB $_.FullName
            }
        } |
        Sort-Object MB -Descending |
        Format-Table -AutoSize
}

$PySide = Join-Path $Site "PySide6"
if (Test-Path $PySide) {
    Write-Host ""
    Write-Host "PySide6 top folders:" -ForegroundColor Cyan
    Get-ChildItem $PySide -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
            [PSCustomObject]@{
                Folder = $_.FullName.Replace((Resolve-Path $DistRoot).Path + "\", "")
                MB = SizeMB $_.FullName
            }
        } |
        Sort-Object MB -Descending |
        Format-Table -AutoSize
}
