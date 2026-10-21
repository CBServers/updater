# Script: update-h2-mod.ps1
# Downloads h2-mod files from h2-mod.alicent.cat (manifest), generates hashes,
# and updates the manifest.

$ErrorActionPreference = "Stop"

# Define paths relative to script location
$scriptDir = $PSScriptRoot
$rootDir = Split-Path -Parent $scriptDir
$h2ModDir = Join-Path $rootDir "updater\h2-mod"
$updaterDir = Join-Path $rootDir "updater"
$hasherExe = Join-Path $scriptDir "update-hasher.exe"

# Ensure h2-mod directory exists
if (-not (Test-Path $h2ModDir)) {
    New-Item -ItemType Directory -Path $h2ModDir -Force | Out-Null
}

# 1. Fetch manifest
Write-Host "Fetching files-dev.json manifest..."
$manifestUrl = "https://h2-mod.alicent.cat/files-dev.json"
$manifest = Invoke-RestMethod -Uri $manifestUrl

$total = $manifest.Count
Write-Host "Manifest contains $total file(s)."

# 2. Download each file and verify size
$baseUrl = "https://h2-mod.alicent.cat/data-dev/"
for ($i = 0; $i -lt $total; $i++) {
    $entry = $manifest[$i]
    $relPath = $entry[0]
    $expectedSize = [int64]$entry[1]

    $destPath = Join-Path $h2ModDir $relPath
    $destDir = Split-Path -Parent $destPath
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $encodedPath = ($relPath -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    $url = $baseUrl + $encodedPath

    Write-Host ("[{0}/{1}] {2}" -f ($i + 1), $total, $relPath)
    Invoke-WebRequest -Uri $url -OutFile $destPath

    $actualSize = (Get-Item $destPath).Length
    if ($actualSize -ne $expectedSize) {
        Write-Host ("ERROR: size mismatch for {0} (expected {1}, got {2})" -f $relPath, $expectedSize, $actualSize) -ForegroundColor Red
        Remove-Item $destPath -Force -ErrorAction SilentlyContinue
        if (-not $env:CI) { Read-Host }
        exit 1
    }
}

# 3. Copy hasher to h2-mod directory
Write-Host "Copying update-hasher.exe..."
$hasherDest = Join-Path $h2ModDir "update-hasher.exe"
Copy-Item $hasherExe -Destination $hasherDest

# 4. Run hasher in h2-mod directory
Write-Host "Running update-hasher.exe..."
Push-Location $h2ModDir
& ".\update-hasher.exe"
Pop-Location

# 5. Move hashed.json to updater/h2-mod.json
Write-Host "Moving hashed.json to h2-mod.json..."
$hashedJson = Join-Path $h2ModDir "hashed.json"
$destJson = Join-Path $updaterDir "h2-mod.json"
Move-Item $hashedJson -Destination $destJson -Force

# 6. Cleanup - remove hasher from h2-mod directory
Write-Host "Cleaning up..."
Remove-Item $hasherDest

Write-Host "Done!"
if (-not $env:CI) { Read-Host }
