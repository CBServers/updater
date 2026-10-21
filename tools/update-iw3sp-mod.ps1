# Script: update-iw3sp-mod.ps1
# Mirrors IW3SP-Mod from jerryalt.codeberg.page (files.json, schema-identical to
# our manifests: path, size, uppercase SHA-1) into updater/iw3sp-mod, pruning
# iw3sp_data files upstream dropped, then adds the CoD4x proxy trio it needs:
# miles32.dll (CoD4x_Client_pub mss archive), mss32.dll (CoD4x-mss) and
# bin/launcher.dll (CoD4x-launcher). Verifies upstream SHA-1 per mirrored file,
# then re-hashes with update-hasher.exe (SHA-1, plus dest column from the
# committed updater/iw3sp-mod/dest.json sidecar).

$ErrorActionPreference = "Stop"

# Define paths relative to script location
$scriptDir = $PSScriptRoot
$rootDir = Split-Path -Parent $scriptDir
$iw3spDir = Join-Path $rootDir "updater\iw3sp-mod"
$updaterDir = Join-Path $rootDir "updater"
$hasherExe = Join-Path $scriptDir "update-hasher.exe"

# Authenticated in CI, where shared runner IPs hit the anonymous API rate limit
$ghHeaders = @{ "User-Agent" = "PowerShell" }
if ($env:GITHUB_TOKEN) { $ghHeaders["Authorization"] = "Bearer $env:GITHUB_TOKEN" }

if (-not (Test-Path (Join-Path $iw3spDir "dest.json"))) {
    Write-Host "ERROR: updater/iw3sp-mod/dest.json sidecar is missing; the manifest would carry no dest column" -ForegroundColor Red
    if (-not $env:CI) { Read-Host }
    exit 1
}

# 1. Fetch upstream manifest and download each file
Write-Host "Fetching files.json manifest..."
$manifestUrl = "https://jerryalt.codeberg.page/files.json"
$manifest = Invoke-RestMethod -Uri $manifestUrl

$total = $manifest.Count
Write-Host "Manifest contains $total file(s)."

$baseUrl = "https://jerryalt.codeberg.page/"
for ($i = 0; $i -lt $total; $i++) {
    $entry = $manifest[$i]
    $relPath = $entry[0]
    $expectedSize = [int64]$entry[1]
    $expectedSha1 = $entry[2]

    $destPath = Join-Path $iw3spDir ($relPath -replace '/', '\')
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

    $actualHash = (Get-FileHash $destPath -Algorithm SHA1).Hash.ToUpperInvariant()
    if ($actualHash -ne $expectedSha1.ToUpperInvariant()) {
        Write-Host ("ERROR: sha1 mismatch for {0}" -f $relPath) -ForegroundColor Red
        Remove-Item $destPath -Force -ErrorAction SilentlyContinue
        if (-not $env:CI) { Read-Host }
        exit 1
    }
}

# 2. Prune iw3sp_data files upstream no longer ships (that tree is 100% upstream-owned)
$upstreamPaths = @{}
foreach ($entry in $manifest) { $upstreamPaths[$entry[0]] = $true }
$iw3spDataDir = Join-Path $iw3spDir "iw3sp_data"
if (Test-Path $iw3spDataDir) {
    Get-ChildItem $iw3spDataDir -File -Recurse | ForEach-Object {
        $relPath = $_.FullName.Substring($iw3spDir.Length + 1) -replace '\\', '/'
        if (-not $upstreamPaths.ContainsKey($relPath)) {
            Write-Host ("Pruning {0} (no longer upstream)..." -f $relPath)
            Remove-Item $_.FullName -Force
        }
    }
}

# 3. CoD4x proxy trio: iw3sp_mod.exe imports mss32.dll (CoD4x's Miles proxy),
# which forwards to miles32.dll and side-loads bin/launcher.dll
Write-Host "Fetching CoD4x_Client_pub latest release..."
$clientPubApi = "https://api.github.com/repos/callofduty4x/CoD4x_Client_pub/releases/latest"
$clientPubRelease = Invoke-RestMethod -Uri $clientPubApi -Headers $ghHeaders
$mssAsset = $clientPubRelease.assets | Where-Object { $_.name -eq "mss" } | Select-Object -First 1

if (-not $mssAsset) {
    Write-Host "ERROR: Could not find 'mss' asset in latest CoD4x_Client_pub release" -ForegroundColor Red
    if (-not $env:CI) { Read-Host }
    exit 1
}

# Helper: download an extension-less zip asset, extract a single file into $iw3spDir
function Get-AssetFile {
    param(
        [string]$AssetUrl,
        [string]$TempZipName,
        [string]$FileToExtract
    )
    $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "iw3sp-mod-$TempZipName"
    $tempExtract = "$tempZip-extract"

    Invoke-WebRequest -Uri $AssetUrl -OutFile $tempZip
    if (Test-Path $tempExtract) {
        Remove-Item $tempExtract -Recurse -Force
    }
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

    $src = Join-Path $tempExtract $FileToExtract
    if (-not (Test-Path $src)) {
        Write-Host ("ERROR: '{0}' not found in archive {1}" -f $FileToExtract, $TempZipName) -ForegroundColor Red
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        if (-not $env:CI) { Read-Host }
        exit 1
    }
    Copy-Item -Path $src -Destination (Join-Path $iw3spDir $FileToExtract) -Force

    Remove-Item $tempZip -Force
    Remove-Item $tempExtract -Recurse -Force
}

Write-Host "Downloading and extracting miles32.dll from mss..."
Get-AssetFile -AssetUrl $mssAsset.browser_download_url -TempZipName "mss-temp.zip" -FileToExtract "miles32.dll"

Write-Host "Fetching CoD4x-mss latest release..."
$mssApi = "https://api.github.com/repos/callofduty4x/CoD4x-mss/releases/latest"
$mssRelease = Invoke-RestMethod -Uri $mssApi -Headers $ghHeaders
$mss32Asset = $mssRelease.assets | Where-Object { $_.name -eq "mss32.dll" } | Select-Object -First 1

if (-not $mss32Asset) {
    Write-Host "ERROR: Could not find 'mss32.dll' asset in latest CoD4x-mss release" -ForegroundColor Red
    if (-not $env:CI) { Read-Host }
    exit 1
}

Write-Host "Downloading mss32.dll..."
Invoke-WebRequest -Uri $mss32Asset.browser_download_url -OutFile (Join-Path $iw3spDir "mss32.dll")

Write-Host "Fetching CoD4x-launcher latest release..."
$launcherApi      = "https://api.github.com/repos/callofduty4x/CoD4x-launcher/releases/latest"
$launcherRelease  = Invoke-RestMethod -Uri $launcherApi -Headers $ghHeaders
$launcherDllAsset = $launcherRelease.assets | Where-Object { $_.name -eq "launcher.dll" } | Select-Object -First 1

if (-not $launcherDllAsset) {
    Write-Host "ERROR: Could not find 'launcher.dll' in latest CoD4x-launcher release" -ForegroundColor Red
    if (-not $env:CI) { Read-Host }
    exit 1
}

$binDir = Join-Path $iw3spDir "bin"
New-Item -ItemType Directory -Path $binDir -Force | Out-Null
Write-Host "Downloading launcher.dll..."
Invoke-WebRequest -Uri $launcherDllAsset.browser_download_url -OutFile (Join-Path $binDir "launcher.dll")

# 4. Copy hasher to iw3sp-mod directory
Write-Host "Copying update-hasher.exe..."
$hasherDest = Join-Path $iw3spDir "update-hasher.exe"
Copy-Item $hasherExe -Destination $hasherDest

# 5. Run hasher in iw3sp-mod directory
Write-Host "Running update-hasher.exe..."
Push-Location $iw3spDir
& ".\update-hasher.exe"
Pop-Location

# 6. Move hashed.json to updater/iw3sp-mod.json
Write-Host "Moving hashed.json to iw3sp-mod.json..."
$hashedJson = Join-Path $iw3spDir "hashed.json"
$destJson = Join-Path $updaterDir "iw3sp-mod.json"
Move-Item $hashedJson -Destination $destJson -Force

# 7. Cleanup - remove hasher from iw3sp-mod directory
Write-Host "Cleaning up..."
Remove-Item $hasherDest

Write-Host "Done!"
if (-not $env:CI) { Read-Host }
