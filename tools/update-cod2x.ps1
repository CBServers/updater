# Script: update-cod2x.ps1
# Downloads the latest CoD2x Windows release zip, extracts the DLL files into
# updater/cod2x, generates hashes, and updates the manifest.

$ErrorActionPreference = "Stop"

# Define paths relative to script location
$scriptDir = $PSScriptRoot
$rootDir = Split-Path -Parent $scriptDir
$cod2xDir = Join-Path $rootDir "updater\cod2x"
$updaterDir = Join-Path $rootDir "updater"
$hasherExe = Join-Path $scriptDir "update-hasher.exe"

# Authenticated in CI, where shared runner IPs hit the anonymous API rate limit
$ghHeaders = @{ "User-Agent" = "PowerShell" }
if ($env:GITHUB_TOKEN) { $ghHeaders["Authorization"] = "Bearer $env:GITHUB_TOKEN" }

# Ensure cod2x directory exists
if (-not (Test-Path $cod2xDir)) {
    New-Item -ItemType Directory -Path $cod2xDir -Force | Out-Null
}

# 1. Find the latest Windows release zip
Write-Host "Fetching CoD2x latest release..."
$releaseApi = "https://api.github.com/repos/callofduty2x/CoD2x/releases/latest"
$release = Invoke-RestMethod -Uri $releaseApi -Headers $ghHeaders
$winAsset = $release.assets | Where-Object { $_.name -match '_windows\.zip$' } | Select-Object -First 1

if (-not $winAsset) {
    Write-Host "ERROR: Could not find a *_windows.zip asset in latest CoD2x release" -ForegroundColor Red
    if (-not $env:CI) { Read-Host }
    exit 1
}

# 2. Download the release zip
Write-Host ("Downloading {0}..." -f $winAsset.name)
$zipPath = Join-Path ([System.IO.Path]::GetTempPath()) "cod2x-release-temp.zip"
Invoke-WebRequest -Uri $winAsset.browser_download_url -OutFile $zipPath

# 3. Extract the zip
Write-Host "Extracting release..."
$extractPath = Join-Path ([System.IO.Path]::GetTempPath()) "cod2x-release-temp"
if (Test-Path $extractPath) {
    Remove-Item $extractPath -Recurse -Force
}
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

# 4. Copy only the DLL files into cod2x directory (skip readme/txt files)
$dllFiles = Get-ChildItem -Path $extractPath -Recurse -File -Filter *.dll
if (-not $dllFiles) {
    Write-Host "ERROR: No DLL files found in the release zip" -ForegroundColor Red
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    if (-not $env:CI) { Read-Host }
    exit 1
}

foreach ($dll in $dllFiles) {
    $relativePath = $dll.FullName.Substring($extractPath.Length + 1)
    $destPath = Join-Path $cod2xDir $relativePath
    $destDir = Split-Path -Parent $destPath
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Write-Host ("Copying {0}..." -f $relativePath)
    Copy-Item -Path $dll.FullName -Destination $destPath -Force
}

# Cleanup temp files
Remove-Item $zipPath -Force
Remove-Item $extractPath -Recurse -Force

# 5. Copy hasher to cod2x directory
Write-Host "Copying update-hasher.exe..."
$hasherDest = Join-Path $cod2xDir "update-hasher.exe"
Copy-Item $hasherExe -Destination $hasherDest

# 6. Run hasher in cod2x directory
Write-Host "Running update-hasher.exe..."
Push-Location $cod2xDir
& ".\update-hasher.exe"
Pop-Location

# 7. Move hashed.json to updater/cod2x.json
Write-Host "Moving hashed.json to cod2x.json..."
$hashedJson = Join-Path $cod2xDir "hashed.json"
$destJson = Join-Path $updaterDir "cod2x.json"
Move-Item $hashedJson -Destination $destJson -Force

# 8. Cleanup - remove hasher from cod2x directory
Write-Host "Cleaning up..."
Remove-Item $hasherDest

Write-Host "Done!"
if (-not $env:CI) { Read-Host }
