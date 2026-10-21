# Script: update-iw3x.ps1
# Mirrors IW3x (CoD4R) from its update server into updater/iw3x per our layout:
# client dll + launcher.dll -> bin/ (appdata), root assets -> game root,
# main -> main/, zone -> zone/english/. Skips their launcher exe and dedi.
# Verifies upstream SHA-256 per file, then re-hashes with update-hasher.exe
# (SHA-1, plus dest column from the committed updater/iw3x/dest.json sidecar).

$ErrorActionPreference = "Stop"

# Define paths relative to script location
$scriptDir = $PSScriptRoot
$rootDir = Split-Path -Parent $scriptDir
$iw3xDir = Join-Path $rootDir "updater\iw3x"
$updaterDir = Join-Path $rootDir "updater"
$hasherExe = Join-Path $scriptDir "update-hasher.exe"

if (-not (Test-Path (Join-Path $iw3xDir "dest.json"))) {
    Write-Host "ERROR: updater/iw3x/dest.json sidecar is missing; the manifest would carry no dest column" -ForegroundColor Red
    if (-not $env:CI) { Read-Host }
    exit 1
}

# 1. Fetch upstream manifest
Write-Host "Fetching IW3x manifest.json..."
$manifestUrl = "http://74.208.200.240/manifest.json"
$manifest = Invoke-RestMethod -Uri $manifestUrl
$baseUrl = $manifest.base_url
Write-Host ("Upstream: generated {0}, client v{1}" -f $manifest.generated, $manifest.client.version)

function Get-Verified {
    param(
        [string]$Path,
        [string]$DestPath,
        [int64]$ExpectedSize,
        [string]$ExpectedSha256
    )
    $destDir = Split-Path -Parent $DestPath
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $encodedPath = ($Path -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    Invoke-WebRequest -Uri "$baseUrl/$encodedPath" -OutFile $DestPath

    $actualSize = (Get-Item $DestPath).Length
    if ($actualSize -ne $ExpectedSize) {
        Write-Host ("ERROR: size mismatch for {0} (expected {1}, got {2})" -f $Path, $ExpectedSize, $actualSize) -ForegroundColor Red
        Remove-Item $DestPath -Force -ErrorAction SilentlyContinue
        if (-not $env:CI) { Read-Host }
        exit 1
    }

    $actualHash = (Get-FileHash $DestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $ExpectedSha256.ToLowerInvariant()) {
        Write-Host ("ERROR: sha256 mismatch for {0}" -f $Path) -ForegroundColor Red
        Remove-Item $DestPath -Force -ErrorAction SilentlyContinue
        if (-not $env:CI) { Read-Host }
        exit 1
    }
}

# 2. Client dll: version-namespaced beside CoD4x's (bin\cod4r_022\cod4r_022.dll)
$clientName = Split-Path -Leaf $manifest.client.path
$clientStem = [System.IO.Path]::GetFileNameWithoutExtension($clientName)
Write-Host ("Downloading {0}..." -f $clientName)
Get-Verified -Path $manifest.client.path -DestPath (Join-Path $iw3xDir "bin\$clientStem\$clientName") `
    -ExpectedSize $manifest.client.size -ExpectedSha256 $manifest.client.sha256

# Prune older mirrored client versions so the manifest only ever carries the current one
Get-ChildItem (Join-Path $iw3xDir "bin") -Directory -Filter "cod4r_*" |
    Where-Object { $_.Name -ne $clientStem } |
    ForEach-Object {
        Write-Host ("Pruning old client version {0}..." -f $_.Name)
        Remove-Item $_.FullName -Recurse -Force
    }

# 3. Assets, mapped from upstream dest to our live-layout-relative paths
$destMap = @{
    "root" = ""
    "main" = "main"
    "zone" = "zone\english"
    "bin"  = "bin"
}
$total = $manifest.assets.Count
for ($i = 0; $i -lt $total; $i++) {
    $entry = $manifest.assets[$i]
    if (-not $destMap.ContainsKey($entry.dest)) {
        Write-Host ("ERROR: unknown upstream dest '{0}' for {1}" -f $entry.dest, $entry.name) -ForegroundColor Red
        if (-not $env:CI) { Read-Host }
        exit 1
    }
    $relDir = $destMap[$entry.dest]
    $destPath = if ($relDir) { Join-Path (Join-Path $iw3xDir $relDir) $entry.name } else { Join-Path $iw3xDir $entry.name }
    Write-Host ("[{0}/{1}] {2}" -f ($i + 1), $total, $entry.name)
    Get-Verified -Path $entry.path -DestPath $destPath -ExpectedSize $entry.size -ExpectedSha256 $entry.sha256
}

# Upstream `launcher` (CoD4R-Launcher.exe) is deliberately not mirrored: we are the launcher.
# Upstream `dedi` (Cod4R-DedRun.exe) is not mirrored either; add it here if dedi support lands.

# 4. Copy hasher to iw3x directory
Write-Host "Copying update-hasher.exe..."
$hasherDest = Join-Path $iw3xDir "update-hasher.exe"
Copy-Item $hasherExe -Destination $hasherDest

# 5. Run hasher in iw3x directory
Write-Host "Running update-hasher.exe..."
Push-Location $iw3xDir
& ".\update-hasher.exe"
Pop-Location

# 6. Move hashed.json to updater/iw3x.json
Write-Host "Moving hashed.json to iw3x.json..."
$hashedJson = Join-Path $iw3xDir "hashed.json"
$destJson = Join-Path $updaterDir "iw3x.json"
Move-Item $hashedJson -Destination $destJson -Force

# 7. Cleanup - remove hasher from iw3x directory
Write-Host "Cleaning up..."
Remove-Item $hasherDest

Write-Host "Done!"
if (-not $env:CI) { Read-Host }
