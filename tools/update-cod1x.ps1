# Script: update-cod1x.ps1
# Downloads the latest CoD1x (codextended-client) release archive, extracts
# cod1x.dll and CoDMP.exe into updater/cod1x, generates hashes, and updates
# the manifest.

$ErrorActionPreference = "Stop"

# Define paths relative to script location
$scriptDir = $PSScriptRoot
$rootDir = Split-Path -Parent $scriptDir
$cod1xDir = Join-Path $rootDir "updater\cod1x"
$updaterDir = Join-Path $rootDir "updater"
$hasherExe = Join-Path $scriptDir "update-hasher.exe"

# Authenticated in CI, where shared runner IPs hit the anonymous API rate limit
$ghHeaders = @{ "User-Agent" = "PowerShell" }
if ($env:GITHUB_TOKEN) { $ghHeaders["Authorization"] = "Bearer $env:GITHUB_TOKEN" }

# Only these files are mirrored; the archive also ships CoDMP_old.exe and an
# uninstaller we deliberately skip.
$wantedFiles = @("cod1x.dll", "CoDMP.exe")

# Ensure cod1x directory exists
if (-not (Test-Path $cod1xDir)) {
    New-Item -ItemType Directory -Path $cod1xDir -Force | Out-Null
}

# 1. Find the latest release archive
Write-Host "Fetching CoD1x latest release..."
$releaseApi = "https://api.github.com/repos/xtnded/codextended-client/releases/latest"
$release = Invoke-RestMethod -Uri $releaseApi -Headers $ghHeaders
Write-Host ("Upstream: {0} (tag {1})" -f $release.name, $release.tag_name)

$archiveAsset = $release.assets | Where-Object { $_.name -eq "CoD1x_Archive.zip" } | Select-Object -First 1

if (-not $archiveAsset) {
    Write-Host "ERROR: Could not find CoD1x_Archive.zip in latest CoD1x release" -ForegroundColor Red
    if (-not $env:CI) { Read-Host }
    exit 1
}

# 2. Download the release zip
Write-Host ("Downloading {0}..." -f $archiveAsset.name)
$zipPath = Join-Path ([System.IO.Path]::GetTempPath()) "cod1x-release-temp.zip"
Invoke-WebRequest -Uri $archiveAsset.browser_download_url -OutFile $zipPath

$actualSize = (Get-Item $zipPath).Length
if ($actualSize -ne [int64]$archiveAsset.size) {
    Write-Host ("ERROR: size mismatch for {0} (expected {1}, got {2})" -f $archiveAsset.name, $archiveAsset.size, $actualSize) -ForegroundColor Red
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    if (-not $env:CI) { Read-Host }
    exit 1
}

# 3. Extract the zip
Write-Host "Extracting release..."
$extractPath = Join-Path ([System.IO.Path]::GetTempPath()) "cod1x-release-temp"
if (Test-Path $extractPath) {
    Remove-Item $extractPath -Recurse -Force
}
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

# 4. Copy only the wanted files into the cod1x directory
foreach ($wanted in $wantedFiles) {
    $src = Get-ChildItem -Path $extractPath -Recurse -File |
        Where-Object { $_.Name -eq $wanted } | Select-Object -First 1

    if (-not $src) {
        Write-Host ("ERROR: {0} not found in the release zip" -f $wanted) -ForegroundColor Red
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        if (-not $env:CI) { Read-Host }
        exit 1
    }

    Write-Host ("Copying {0}..." -f $wanted)
    Copy-Item -Path $src.FullName -Destination (Join-Path $cod1xDir $wanted) -Force
}

# Cleanup temp files
Remove-Item $zipPath -Force
Remove-Item $extractPath -Recurse -Force

# 5. Copy hasher to cod1x directory
Write-Host "Copying update-hasher.exe..."
$hasherDest = Join-Path $cod1xDir "update-hasher.exe"
Copy-Item $hasherExe -Destination $hasherDest

# 6. Run hasher in cod1x directory
Write-Host "Running update-hasher.exe..."
Push-Location $cod1xDir
& ".\update-hasher.exe"
Pop-Location

# 7. Move hashed.json to updater/cod1x.json
Write-Host "Moving hashed.json to cod1x.json..."
$hashedJson = Join-Path $cod1xDir "hashed.json"
$destJson = Join-Path $updaterDir "cod1x.json"
Move-Item $hashedJson -Destination $destJson -Force

# 8. Cleanup - remove hasher from cod1x directory
Write-Host "Cleaning up..."
Remove-Item $hasherDest

Write-Host "Done!"
if (-not $env:CI) { Read-Host }
