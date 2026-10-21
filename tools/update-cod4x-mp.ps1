# Script: update-cod4x-mp.ps1
# Updates the post-split CoD4x (MP) client in updater/cod4x-mp: client dll, iwd
# and fastfiles + miles32.dll from CoD4x_Client_pub, mss32.dll from CoD4x-mss,
# launcher.dll from CoD4x-launcher. iw3mp.exe has no upstream source and is
# maintained by hand in the folder; the script only checks it is present.
# Re-hashes with update-hasher.exe (SHA-1, plus dest column from the committed
# updater/cod4x-mp/dest.json sidecar).
#
# updater/cod4x.json + updater/cod4x/ are FROZEN (see updater/cod4x/README.md);
# this script must never touch them.

$ErrorActionPreference = "Stop"

# Define paths relative to script location
$scriptDir = $PSScriptRoot
$rootDir = Split-Path -Parent $scriptDir
$cod4xMpDir = Join-Path $rootDir "updater\cod4x-mp"
$updaterDir = Join-Path $rootDir "updater"
$hasherExe = Join-Path $scriptDir "update-hasher.exe"

# Authenticated in CI, where shared runner IPs hit the anonymous API rate limit
$ghHeaders = @{ "User-Agent" = "PowerShell" }
if ($env:GITHUB_TOKEN) { $ghHeaders["Authorization"] = "Bearer $env:GITHUB_TOKEN" }

if (-not (Test-Path (Join-Path $cod4xMpDir "dest.json"))) {
    Write-Host "ERROR: updater/cod4x-mp/dest.json sidecar is missing; the manifest would carry no dest column" -ForegroundColor Red
    if (-not $env:CI) { Read-Host }
    exit 1
}
if (-not (Test-Path (Join-Path $cod4xMpDir "iw3mp.exe"))) {
    Write-Host "ERROR: updater/cod4x-mp/iw3mp.exe is missing; it has no upstream source and must be placed by hand" -ForegroundColor Red
    if (-not $env:CI) { Read-Host }
    exit 1
}

# 1. Fetch CoD4x_Client_pub latest release
Write-Host "Fetching CoD4x_Client_pub latest release..."
$clientPubApi = "https://api.github.com/repos/callofduty4x/CoD4x_Client_pub/releases/latest"
$clientPubRelease = Invoke-RestMethod -Uri $clientPubApi -Headers $ghHeaders
Write-Host ("Upstream: CoD4x_Client_pub {0}" -f $clientPubRelease.tag_name)

$cod4xDllAsset = $clientPubRelease.assets | Where-Object { $_.name -match '^cod4x_[0-9]+\.dll$' } | Select-Object -First 1
$iwdAsset      = $clientPubRelease.assets | Where-Object { $_.name -eq "jcod4x_00.iwd" }          | Select-Object -First 1
$ambfixAsset   = $clientPubRelease.assets | Where-Object { $_.name -eq "cod4x_ambfix.ff" }         | Select-Object -First 1
$patchAsset    = $clientPubRelease.assets | Where-Object { $_.name -eq "cod4x_patch.ff" }          | Select-Object -First 1
$patchv2Asset  = $clientPubRelease.assets | Where-Object { $_.name -eq "cod4x_patchv2.ff" }        | Select-Object -First 1
$mssAsset      = $clientPubRelease.assets | Where-Object { $_.name -eq "mss" }                     | Select-Object -First 1

foreach ($required in @(
        @{ Asset = $cod4xDllAsset; Name = "cod4x_<ver>.dll" },
        @{ Asset = $iwdAsset;      Name = "jcod4x_00.iwd" },
        @{ Asset = $ambfixAsset;   Name = "cod4x_ambfix.ff" },
        @{ Asset = $patchAsset;    Name = "cod4x_patch.ff" },
        @{ Asset = $patchv2Asset;  Name = "cod4x_patchv2.ff" },
        @{ Asset = $mssAsset;      Name = "mss" })) {
    if (-not $required.Asset) {
        Write-Host ("ERROR: Could not find '{0}' asset in latest CoD4x_Client_pub release" -f $required.Name) -ForegroundColor Red
        if (-not $env:CI) { Read-Host }
        exit 1
    }
}

# Helper: download an extension-less zip asset, extract a single file into $cod4xMpDir
function Get-AssetFile {
    param(
        [string]$AssetUrl,
        [string]$TempZipName,
        [string]$FileToExtract
    )
    $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "cod4x-mp-$TempZipName"
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
    Copy-Item -Path $src -Destination (Join-Path $cod4xMpDir $FileToExtract) -Force

    Remove-Item $tempZip -Force
    Remove-Item $tempExtract -Recurse -Force
}

# 2. Client dll, version-namespaced (bin\cod4x_021\cod4x_021.dll)
$cod4xDllName   = $cod4xDllAsset.name
$cod4xDllStem   = [System.IO.Path]::GetFileNameWithoutExtension($cod4xDllName)
$cod4xDllSubDir = Join-Path $cod4xMpDir "bin\$cod4xDllStem"
New-Item -ItemType Directory -Path $cod4xDllSubDir -Force | Out-Null
Write-Host "Downloading $cod4xDllName..."
Invoke-WebRequest -Uri $cod4xDllAsset.browser_download_url -OutFile (Join-Path $cod4xDllSubDir $cod4xDllName)

# Prune older mirrored client versions so the manifest only ever carries the current one
Get-ChildItem (Join-Path $cod4xMpDir "bin") -Directory -Filter "cod4x_*" |
    Where-Object { $_.Name -ne $cod4xDllStem } |
    ForEach-Object {
        Write-Host ("Pruning old client version {0}..." -f $_.Name)
        Remove-Item $_.FullName -Recurse -Force
    }

# 3. iwd + fastfiles
$mainDir = Join-Path $cod4xMpDir "main"
New-Item -ItemType Directory -Path $mainDir -Force | Out-Null
Write-Host "Downloading jcod4x_00.iwd..."
Invoke-WebRequest -Uri $iwdAsset.browser_download_url -OutFile (Join-Path $mainDir "jcod4x_00.iwd")

$zoneDir = Join-Path $cod4xMpDir "zone"
New-Item -ItemType Directory -Path $zoneDir -Force | Out-Null
Write-Host "Downloading cod4x_ambfix.ff..."
Invoke-WebRequest -Uri $ambfixAsset.browser_download_url -OutFile (Join-Path $zoneDir "cod4x_ambfix.ff")
Write-Host "Downloading cod4x_patch.ff..."
Invoke-WebRequest -Uri $patchAsset.browser_download_url -OutFile (Join-Path $zoneDir "cod4x_patch.ff")
Write-Host "Downloading cod4x_patchv2.ff..."
Invoke-WebRequest -Uri $patchv2Asset.browser_download_url -OutFile (Join-Path $zoneDir "cod4x_patchv2.ff")

# 4. Miles proxy pair
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
Invoke-WebRequest -Uri $mss32Asset.browser_download_url -OutFile (Join-Path $cod4xMpDir "mss32.dll")

# 5. Fetch CoD4x-launcher latest release (launcher.dll)
Write-Host "Fetching CoD4x-launcher latest release..."
$launcherApi      = "https://api.github.com/repos/callofduty4x/CoD4x-launcher/releases/latest"
$launcherRelease  = Invoke-RestMethod -Uri $launcherApi -Headers $ghHeaders
$launcherDllAsset = $launcherRelease.assets | Where-Object { $_.name -eq "launcher.dll" } | Select-Object -First 1

if (-not $launcherDllAsset) {
    Write-Host "ERROR: Could not find 'launcher.dll' in latest CoD4x-launcher release" -ForegroundColor Red
    if (-not $env:CI) { Read-Host }
    exit 1
}

$binDir = Join-Path $cod4xMpDir "bin"
New-Item -ItemType Directory -Path $binDir -Force | Out-Null
Write-Host "Downloading launcher.dll..."
Invoke-WebRequest -Uri $launcherDllAsset.browser_download_url -OutFile (Join-Path $binDir "launcher.dll")

# 6. Copy hasher to cod4x-mp directory
Write-Host "Copying update-hasher.exe..."
$hasherDest = Join-Path $cod4xMpDir "update-hasher.exe"
Copy-Item $hasherExe -Destination $hasherDest

# 7. Run hasher in cod4x-mp directory
Write-Host "Running update-hasher.exe..."
Push-Location $cod4xMpDir
& ".\update-hasher.exe"
Pop-Location

# 8. Move hashed.json to updater/cod4x-mp.json
Write-Host "Moving hashed.json to cod4x-mp.json..."
$hashedJson = Join-Path $cod4xMpDir "hashed.json"
$destJson = Join-Path $updaterDir "cod4x-mp.json"
Move-Item $hashedJson -Destination $destJson -Force

# 9. Cleanup - remove hasher from cod4x-mp directory
Write-Host "Cleaning up..."
Remove-Item $hasherDest

Write-Host "Done!"
if (-not $env:CI) { Read-Host }
