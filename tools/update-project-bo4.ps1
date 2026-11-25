# Script: update-project-bo4.ps1
# Rebuilds updater/project-bo4 from two sources: the CB fork's launcher release
# (CBServers/shield-launcher, project-bo4-launcher.zip) and the game content
# upstream's launcher downloads (NotNierPea/shield-launcher "content" release,
# manifest.json plus <sha256>.bin parts). BlackOps4.exe comes out of the
# manifest's exe.zip and upstream's own launcher entry is skipped. Then
# generates hashes and updates the manifest.

param(
    # A local project-bo4-launcher.zip to use instead of the latest release, for testing
    [string]$LauncherZip
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptDir = $PSScriptRoot
$rootDir = Split-Path -Parent $scriptDir
$updaterDir = Join-Path $rootDir "updater"
$boDir = Join-Path $updaterDir "project-bo4"
$hasherExe = Join-Path $scriptDir "update-hasher.exe"

$launcherRepo = "CBServers/shield-launcher"
$launcherAsset = "project-bo4-launcher.zip"
$contentManifestUrl = "https://github.com/NotNierPea/shield-launcher/releases/download/content/manifest.json"

# Authenticated in CI, where shared runner IPs hit the anonymous API rate limit
$ghHeaders = @{ "User-Agent" = "PowerShell" }
if ($env:GITHUB_TOKEN) { $ghHeaders["Authorization"] = "Bearer $env:GITHUB_TOKEN" }

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "project-bo4-update"

function Fail {
    param([string]$Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    if (-not $env:CI) { Read-Host }
    exit 1
}

# Manifest paths are relative to the game folder, which updater/project-bo4 mirrors
function Resolve-GamePath {
    param([string]$RelPath)
    if ([string]::IsNullOrWhiteSpace($RelPath) -or $RelPath -match '(^|[\\/])\.\.([\\/]|$)' -or $RelPath -match '^[\\/]' -or $RelPath -match ':') {
        Fail "Unsafe path in the content manifest: '$RelPath'"
    }
    Join-Path $boDir ($RelPath -replace '/', '\')
}

function Get-Sha256File {
    param([string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Invoke-Download {
    param([string]$Url, [string]$OutFile, [hashtable]$Headers = @{ "User-Agent" = "PowerShell" })
    for ($attempt = 1; ; $attempt++) {
        try {
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -Headers $Headers -UseBasicParsing
            return
        }
        catch {
            if ($attempt -ge 4) { throw }
            Write-Host ("  attempt {0} failed ({1}), retrying" -f $attempt, ($_.Exception.Message -replace '\s+', ' '))
            Start-Sleep -Seconds (10 * $attempt)
        }
    }
}

# Joins the file's parts in order, checking every part and the whole file against the manifest
function Get-ContentFile {
    param($Entry, [string]$BaseUrl, [string]$Dest)
    New-Item -ItemType Directory -Path (Split-Path -Parent $Dest) -Force | Out-Null
    $out = [System.IO.File]::Create($Dest)
    try {
        foreach ($part in $Entry.parts) {
            $partFile = Join-Path $tempDir "$($part.sha256).bin"
            Invoke-Download -Url "$BaseUrl$($part.sha256).bin" -OutFile $partFile
            if ((Get-Item -LiteralPath $partFile).Length -ne [int64]$part.size -or (Get-Sha256File $partFile) -ne $part.sha256) {
                Fail "Part $($part.sha256) of $($Entry.path) does not match the manifest"
            }
            $in = [System.IO.File]::OpenRead($partFile)
            try { $in.CopyTo($out) } finally { $in.Dispose() }
            Remove-Item -LiteralPath $partFile -Force
        }
    }
    finally {
        $out.Dispose()
    }
    if ((Get-Item -LiteralPath $Dest).Length -ne [int64]$Entry.size -or (Get-Sha256File $Dest) -ne $Entry.sha256) {
        Fail "$($Entry.path) does not match the manifest after joining its parts"
    }
}

if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# 1. Start from an empty folder: every file comes from the two releases, and CI checks LFS files out as pointers
Write-Host "Clearing updater/project-bo4..."
if (Test-Path $boDir) { Remove-Item $boDir -Recurse -Force }
New-Item -ItemType Directory -Path $boDir -Force | Out-Null

# 2. The CB launcher build: Launch Project BO4.exe, Shield_Launcher.exe, images and sounds
if ($LauncherZip) {
    Write-Host "Using local $LauncherZip..."
    Expand-Archive -Path $LauncherZip -DestinationPath $boDir -Force
}
else {
    Write-Host "Fetching $launcherRepo latest release..."
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$launcherRepo/releases/latest" -Headers $ghHeaders
    $asset = $release.assets | Where-Object { $_.name -eq $launcherAsset } | Select-Object -First 1
    if (-not $asset) { Fail "$launcherAsset not found in $launcherRepo release $($release.tag_name)" }

    Write-Host ("Downloading {0} from {1}..." -f $launcherAsset, $release.tag_name)
    $zipFile = Join-Path $tempDir $launcherAsset
    Invoke-Download -Url $asset.browser_download_url -OutFile $zipFile
    Expand-Archive -Path $zipFile -DestinationPath $boDir -Force
    Remove-Item $zipFile -Force
}
if (-not (Test-Path (Join-Path $boDir "project-bo4\launcher\Shield_Launcher.exe"))) {
    Fail "$launcherAsset has no project-bo4/launcher/Shield_Launcher.exe"
}

# 3. Upstream's game content manifest
Write-Host "Fetching the content manifest..."
$manifestFile = Join-Path $tempDir "manifest.json"
Invoke-Download -Url $contentManifestUrl -OutFile $manifestFile
$manifest = Get-Content -Raw $manifestFile | ConvertFrom-Json
if ($manifest.schema -ne 1) { Fail "Unsupported content manifest schema $($manifest.schema)" }
$baseUrl = if ($manifest.base_url) { $manifest.base_url.TrimEnd('/') + '/' } else { $contentManifestUrl.Substring(0, $contentManifestUrl.LastIndexOf('/') + 1) }
Write-Host ("Content {0}: {1} file(s)" -f $manifest.version, @($manifest.files).Count)

# 4. Download each file; exe.zip only gives BlackOps4.exe and packages are unzipped into their folder
$files = @($manifest.files)
for ($i = 0; $i -lt $files.Count; $i++) {
    $entry = $files[$i]
    Write-Host ("[{0}/{1}] {2} ({3:N1} MB)" -f ($i + 1), $files.Count, $entry.path, ($entry.size / 1MB))

    if ($entry.path -eq "project-bo4/launcher/exe.zip") {
        $zipFile = Join-Path $tempDir "exe.zip"
        Get-ContentFile -Entry $entry -BaseUrl $baseUrl -Dest $zipFile
        $exeDir = Join-Path $tempDir "exe"
        Expand-Archive -Path $zipFile -DestinationPath $exeDir -Force
        $exe = Join-Path $exeDir "BlackOps4.exe"
        if (-not (Test-Path $exe)) { Fail "exe.zip has no BlackOps4.exe" }
        Move-Item $exe -Destination (Join-Path $boDir "BlackOps4.exe") -Force
        Remove-Item $zipFile, $exeDir -Recurse -Force
        continue
    }

    if ($entry.extract) {
        $zipFile = Join-Path $tempDir "package.zip"
        Get-ContentFile -Entry $entry -BaseUrl $baseUrl -Dest $zipFile
        $folder = Resolve-GamePath $entry.extract
        if (Test-Path $folder) { Remove-Item $folder -Recurse -Force }
        Expand-Archive -Path $zipFile -DestinationPath $folder -Force
        Remove-Item $zipFile -Force
        foreach ($packaged in @($entry.entries)) {
            $packagedPath = Join-Path $folder ($packaged.path -replace '/', '\')
            if (-not (Test-Path -LiteralPath $packagedPath) -or (Get-Item -LiteralPath $packagedPath).Length -ne [int64]$packaged.size) {
                Fail "$($entry.extract)/$($packaged.path) is missing or the wrong size after unzipping"
            }
        }
        continue
    }

    Get-ContentFile -Entry $entry -BaseUrl $baseUrl -Dest (Resolve-GamePath $entry.path)
}

if (@($manifest.remove).Count) {
    Write-Host ("Upstream removes {0} file(s), not shipped here: {1}" -f @($manifest.remove).Count, (@($manifest.remove) -join ', '))
}
if (-not (Test-Path (Join-Path $boDir "BlackOps4.exe"))) { Fail "The content manifest has no exe.zip, so there is no BlackOps4.exe" }

Remove-Item $tempDir -Recurse -Force

# 5. Copy hasher to project-bo4 directory
Write-Host "Copying update-hasher.exe..."
$hasherDest = Join-Path $boDir "update-hasher.exe"
Copy-Item $hasherExe -Destination $hasherDest

# 6. Run hasher in project-bo4 directory
Write-Host "Running update-hasher.exe..."
Push-Location $boDir
& ".\update-hasher.exe"
Pop-Location

# 7. Move hashed.json to updater/project-bo4.json
Write-Host "Moving hashed.json to project-bo4.json..."
Move-Item (Join-Path $boDir "hashed.json") -Destination (Join-Path $updaterDir "project-bo4.json") -Force

# 8. Cleanup - remove hasher from project-bo4 directory
Write-Host "Cleaning up..."
Remove-Item $hasherDest

Write-Host "Done!"
if (-not $env:CI) { Read-Host }
