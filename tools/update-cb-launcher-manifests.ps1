# Script: update-cb-launcher-manifests.ps1
# Fetches per-game manifest_v2.json from the CB CDN, writes them into both
# cb-launcher and cb-launcher-dev manifest folders, then re-hashes both
# launcher dirs to refresh updater/cb-launcher.json and cb-launcher-dev.json.

$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$rootDir = Split-Path -Parent $scriptDir
$updaterDir = Join-Path $rootDir "updater"
$hasherExe = Join-Path $scriptDir "update-hasher.exe"

$launchers = @(
    @{ Name = "cb-launcher";     Dir = (Join-Path $updaterDir "cb-launcher") },
    @{ Name = "cb-launcher-dev"; Dir = (Join-Path $updaterDir "cb-launcher-dev") }
)
$manifestDirs = $launchers | ForEach-Object { Join-Path $_.Dir "manifest" }

foreach ($dir in $manifestDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Game key (CDN slug) -> output filename stem.
# h2m on the CDN is named hmw locally.
$games = [ordered]@{
    "aw"     = "aw"
    "bo1"    = "bo1"
    "bo2"    = "bo2"
    "bo3"    = "bo3"
    "bo4"    = "bo4"
    "cod4"   = "cod4"
    "ghosts" = "ghosts"
    "h2m"    = "hmw"
    "iw"     = "iw"
    "mw2"    = "mw2"
    "mw2r"   = "mw2r"
    "mw3"    = "mw3"
    "mwr"    = "mwr"
    "waw"    = "waw"
    "cod1"    = "cod1"
    "coduo"    = "coduo"
    "cod2"    = "cod2"
	"ww2"    = "ww2"
}

$total = $games.Count
$success = 0
$i = 0

foreach ($entry in $games.GetEnumerator()) {
    $i++
    $game = $entry.Key
    $outName = $entry.Value
    # h2m lives at /h2m on the CDN; everything else is /{game}_game_files.
    $cdnPath = if ($game -eq "h2m") { "h2m" } else { "${game}_game_files" }
    $cacheBust = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $url = "https://cdn-na.cbservers.xyz/${cdnPath}/manifest_v2.json?${cacheBust}"

    Write-Host ("[{0}/{1}] {2} -> {3}.json" -f $i, $total, $game, $outName)

    $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ("cbmanifest_{0}_{1}.json" -f $outName, [System.Guid]::NewGuid().ToString("N"))

    try {
        Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing

        # Validate it's actually JSON (catches HTML 404 pages).
        $null = Get-Content -Raw -LiteralPath $tempFile | ConvertFrom-Json

        foreach ($dir in $manifestDirs) {
            $dest = Join-Path $dir ("{0}.json" -f $outName)
            Copy-Item -LiteralPath $tempFile -Destination $dest -Force
        }
        $success++
    }
    catch {
        Write-Host ("ERROR: {0} failed: {1}" -f $game, $_.Exception.Message) -ForegroundColor Red
    }
    finally {
        if (Test-Path -LiteralPath $tempFile) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ("Manifests fetched: {0}/{1}." -f $success, $total)

# Hash each launcher dir and produce updater/{launcher}.json
foreach ($launcher in $launchers) {
    $name = $launcher.Name
    $dir = $launcher.Dir

    Write-Host ("Hashing {0}..." -f $name)

    $hasherDest = Join-Path $dir "update-hasher.exe"
    Copy-Item $hasherExe -Destination $hasherDest -Force

    Push-Location $dir
    try {
        & ".\update-hasher.exe"
    }
    finally {
        Pop-Location
    }

    $hashedJson = Join-Path $dir "hashed.json"
    $destJson = Join-Path $updaterDir ("{0}.json" -f $name)
    Move-Item $hashedJson -Destination $destJson -Force

    Remove-Item $hasherDest -Force
}

Write-Host "Done!"
Read-Host
