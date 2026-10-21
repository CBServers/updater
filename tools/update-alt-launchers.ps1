# Script: update-alt-launchers.ps1
# Downloads alternative launchers, generates hashes, and updates the manifest

$ErrorActionPreference = "Stop"

# Define paths relative to script location
$scriptDir = $PSScriptRoot
$rootDir = Split-Path -Parent $scriptDir
$altLaunchersDir = Join-Path $rootDir "updater\alt-launchers"
$updaterDir = Join-Path $rootDir "updater"
$hasherExe = Join-Path $scriptDir "update-hasher.exe"

# URLs to download (direct exe downloads)
$downloads = @(
    @{ Url = "https://cdn.plutonium.pw/updater/plutonium.exe"; Name = "plutonium.exe" },
    @{ Url = "https://github.com/alterware/alterware-launcher/releases/latest/download/alterware-launcher.exe"; Name = "alterware-launcher.exe" }
)

# 1. Download each direct launcher
Write-Host "Downloading launchers..."
foreach ($download in $downloads) {
    $outPath = Join-Path $altLaunchersDir $download.Name
    Write-Host "  Downloading $($download.Name)..."
    Invoke-WebRequest -Uri $download.Url -OutFile $outPath
}

# 2. Copy hasher to alt-launchers
Write-Host "Copying update-hasher.exe..."
$hasherDest = Join-Path $altLaunchersDir "update-hasher.exe"
Copy-Item $hasherExe -Destination $hasherDest

# 3. Run hasher in alt-launchers directory
Write-Host "Running update-hasher.exe..."
Push-Location $altLaunchersDir
& ".\update-hasher.exe"
Pop-Location

# 4. Move hashed.json to updater/alt-launchers.json
Write-Host "Moving hashed.json to alt-launchers.json..."
$hashedJson = Join-Path $altLaunchersDir "hashed.json"
$destJson = Join-Path $updaterDir "alt-launchers.json"
Move-Item $hashedJson -Destination $destJson -Force

# 5. Cleanup - remove hasher from alt-launchers
Write-Host "Cleaning up..."
Remove-Item $hasherDest

Write-Host "Done!"
if (-not $env:CI) { Read-Host }