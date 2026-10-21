# Script: update-iw4x.ps1
# Downloads IW4x rawfiles and client DLL, generates hashes, and updates the manifest

$ErrorActionPreference = "Stop"

# Define paths relative to script location
$scriptDir = $PSScriptRoot
$rootDir = Split-Path -Parent $scriptDir
$iw4xDir = Join-Path $rootDir "updater\iw4x"
$updaterDir = Join-Path $rootDir "updater"
$hasherExe = Join-Path $scriptDir "update-hasher.exe"

# Authenticated in CI, where shared runner IPs hit the anonymous API rate limit
$ghHeaders = @{ "User-Agent" = "PowerShell" }
if ($env:GITHUB_TOKEN) { $ghHeaders["Authorization"] = "Bearer $env:GITHUB_TOKEN" }

# 1. Download release.zip from iw4x-rawfiles
Write-Host "Downloading iw4x rawfiles..."
$rawfilesApi = "https://api.github.com/repos/iw4x/iw4x-rawfiles/releases/latest"
$rawfilesRelease = Invoke-RestMethod -Uri $rawfilesApi -Headers $ghHeaders
$rawfilesAsset = $rawfilesRelease.assets | Where-Object { $_.name -eq "release.zip" } | Select-Object -First 1

if (-not $rawfilesAsset) {
    Write-Host "ERROR: Could not find release.zip in latest iw4x-rawfiles release" -ForegroundColor Red
    if (-not $env:CI) { Read-Host }
    exit 1
}

$zipPath = Join-Path ([System.IO.Path]::GetTempPath()) "iw4x-release-temp.zip"
Invoke-WebRequest -Uri $rawfilesAsset.browser_download_url -OutFile $zipPath

# 2. Download iw4x.dll from iw4x-client
Write-Host "Downloading iw4x.dll..."
$clientApi = "https://api.github.com/repos/iw4x/iw4x-client/releases/latest"
$clientRelease = Invoke-RestMethod -Uri $clientApi -Headers $ghHeaders
$dllAsset = $clientRelease.assets | Where-Object { $_.name -eq "iw4x.dll" } | Select-Object -First 1

if (-not $dllAsset) {
    Write-Host "ERROR: Could not find iw4x.dll in latest iw4x-client release" -ForegroundColor Red
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    if (-not $env:CI) { Read-Host }
    exit 1
}

Invoke-WebRequest -Uri $dllAsset.browser_download_url -OutFile (Join-Path $iw4xDir "iw4x.dll")

# 3. Extract release.zip into iw4x directory
Write-Host "Extracting rawfiles..."
$extractPath = Join-Path ([System.IO.Path]::GetTempPath()) "iw4x-release-temp"
if (Test-Path $extractPath) {
    Remove-Item $extractPath -Recurse -Force
}
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

# Copy all extracted files into iw4x directory
Get-ChildItem -Path $extractPath -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($extractPath.Length + 1)
    $destPath = Join-Path $iw4xDir $relativePath
    $destDir = Split-Path -Parent $destPath
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Copy-Item -Path $_.FullName -Destination $destPath -Force
}

# Cleanup temp files
Remove-Item $zipPath -Force
Remove-Item $extractPath -Recurse -Force

# 4. Download alterware-launcher.exe from its latest release (same source as alt-launchers)
Write-Host "Downloading alterware-launcher.exe..."
$alterwareUrl = "https://github.com/alterware/alterware-launcher/releases/latest/download/alterware-launcher.exe"
Invoke-WebRequest -Uri $alterwareUrl -OutFile (Join-Path $iw4xDir "alterware-launcher.exe")

# 5. Copy hasher to iw4x directory
Write-Host "Copying update-hasher.exe..."
$hasherDest = Join-Path $iw4xDir "update-hasher.exe"
Copy-Item $hasherExe -Destination $hasherDest

# 6. Run hasher in iw4x directory
Write-Host "Running update-hasher.exe..."
Push-Location $iw4xDir
& ".\update-hasher.exe"
Pop-Location

# 7. Move hashed.json to updater/iw4x.json
Write-Host "Moving hashed.json to iw4x.json..."
$hashedJson = Join-Path $iw4xDir "hashed.json"
$destJson = Join-Path $updaterDir "iw4x.json"
Move-Item $hashedJson -Destination $destJson -Force

# 8. Cleanup - remove hasher from iw4x directory
Write-Host "Cleaning up..."
Remove-Item $hasherDest

Write-Host "Done!"
if (-not $env:CI) { Read-Host }
