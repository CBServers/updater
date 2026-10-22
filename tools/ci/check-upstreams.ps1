# Script: check-upstreams.ps1
# Fingerprints the upstream sources of every automated client and lists the
# ones that need a rebuild: the fingerprint differs from the last recorded one
# in tools/upstream/<client>.json, the client is not in tools/upstream/hold.txt,
# and no PR (open, merged or closed) was ever opened for that fingerprint.
# In CI the list goes to the "clients" step output as the update job's matrix.
# A client whose upstreams can't be reached is reported and skipped, and the
# script fails at the end so the run is flagged without blocking the others.

param(
    [string]$Client = "all",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$toolsDir = Split-Path -Parent $scriptDir
$stateDir = Join-Path $toolsDir "upstream"

$ghHeaders = @{ "User-Agent" = "PowerShell" }
if ($env:GITHUB_TOKEN) { $ghHeaders["Authorization"] = "Bearer $env:GITHUB_TOKEN" }

function Get-Sha256 {
    param([string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

# Upstream APIs occasionally fail for a moment (even a spurious 404), so retry before giving up
function Invoke-WithRetry {
    param([scriptblock]$Action, [int]$Attempts = 3)
    for ($attempt = 1; ; $attempt++) {
        try {
            return & $Action
        }
        catch {
            if ($attempt -ge $Attempts) { throw }
            $delay = 10 * $attempt
            Write-Host ("  attempt {0} failed ({1}), retrying in {2}s" -f $attempt, ($_.Exception.Message -replace '\s+', ' '), $delay)
            Start-Sleep -Seconds $delay
        }
    }
}

# Several clients share upstreams (the CoD4x repos, alterware), so fetch each once
$releaseCache = @{}
function Get-ReleaseSource {
    param([string]$Repo)
    if (-not $releaseCache.ContainsKey($Repo)) {
        $release = Invoke-WithRetry { Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $ghHeaders }
        $assets = $release.assets | Sort-Object name | ForEach-Object {
            if ($_.digest) { "$($_.name)=$($_.digest)" } else { "$($_.name)=$($_.id):$($_.size)" }
        }
        $releaseCache[$Repo] = [ordered]@{
            name    = $Repo
            kind    = "release"
            version = $release.tag_name
            url     = $release.html_url
            key     = Get-Sha256 ((@($release.tag_name) + $assets) -join "`n")
        }
    }
    $releaseCache[$Repo]
}

function Get-ManifestSource {
    param([string]$Name, [string]$Url)
    $content = (Invoke-WithRetry { Invoke-WebRequest -Uri $Url -UseBasicParsing }).Content
    if ($content -is [byte[]]) { $content = [System.Text.Encoding]::UTF8.GetString($content) }
    $hash = Get-Sha256 $content
    [ordered]@{ name = $Name; kind = "manifest"; version = $hash.Substring(0, 8); url = $Url; key = $hash }
}

function Get-FileSource {
    param([string]$Name, [string]$Url)
    $headers = (Invoke-WithRetry { Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing }).Headers
    $modified = "$($headers['Last-Modified'])"
    $version = [DateTimeOffset]::Parse($modified, [System.Globalization.CultureInfo]::InvariantCulture).ToString("yyyy-MM-dd")
    $key = Get-Sha256 ("{0}|{1}|{2}" -f $headers['ETag'], $modified, $headers['Content-Length'])
    [ordered]@{ name = $Name; kind = "file"; version = $version; url = $Url; key = $key }
}

function Get-Iw3xSource {
    $url = "http://74.208.200.240/manifest.json"
    $manifest = Invoke-WithRetry { Invoke-RestMethod -Uri $url }
    # Only the client and assets are mirrored; "generated" and the launcher would cause empty rebuilds
    $mirrored = [ordered]@{ client = $manifest.client; assets = $manifest.assets } | ConvertTo-Json -Depth 5 -Compress
    [ordered]@{ name = "iw3x manifest"; kind = "release"; version = "client v$($manifest.client.version)"; url = $url; key = Get-Sha256 $mirrored }
}

# Client name = updater/<client> folder = updater/<client>.json. The first source names the PR.
$clients = [ordered]@{
    "alt-launchers" = @{ Script = "update-alt-launchers.ps1"; Sources = {
        Get-ReleaseSource "alterware/alterware-launcher"
        Get-FileSource "plutonium.exe" "https://cdn.plutonium.pw/updater/plutonium.exe" } }
    "cod1x" = @{ Script = "update-cod1x.ps1"; Sources = {
        Get-ReleaseSource "xtnded/codextended-client" } }
    "cod2x" = @{ Script = "update-cod2x.ps1"; Sources = {
        Get-ReleaseSource "callofduty2x/CoD2x" } }
    "cod4x-mp" = @{ Script = "update-cod4x-mp.ps1"; Sources = {
        Get-ReleaseSource "callofduty4x/CoD4x_Client_pub"
        Get-ReleaseSource "callofduty4x/CoD4x-mss"
        Get-ReleaseSource "callofduty4x/CoD4x-launcher" } }
    "h2-mod" = @{ Script = "update-h2-mod.ps1"; Sources = {
        Get-ManifestSource "h2-mod files-dev.json" "https://h2-mod.alicent.cat/files-dev.json" } }
    "iw3sp-mod" = @{ Script = "update-iw3sp-mod.ps1"; Sources = {
        Get-ManifestSource "iw3sp-mod files.json" "https://jerryalt.codeberg.page/files.json"
        Get-ReleaseSource "callofduty4x/CoD4x_Client_pub"
        Get-ReleaseSource "callofduty4x/CoD4x-mss"
        Get-ReleaseSource "callofduty4x/CoD4x-launcher" } }
    "iw3x" = @{ Script = "update-iw3x.ps1"; Sources = {
        Get-Iw3xSource } }
    "iw4x" = @{ Script = "update-iw4x.ps1"; Sources = {
        Get-ReleaseSource "iw4x/iw4x-client"
        Get-ReleaseSource "iw4x/iw4x-rawfiles"
        Get-ReleaseSource "alterware/alterware-launcher" } }
}

$holds = @()
$holdFile = Join-Path $stateDir "hold.txt"
if (Test-Path $holdFile) {
    $holds = Get-Content $holdFile | ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ }
}

$selected = if ($Client -and $Client -ne "all") { @($Client) } else { @($clients.Keys) }
$pending = @()
$failed = @()
$summary = @("| Client | Status |", "| --- | --- |")

foreach ($name in $selected) {
    if (-not $clients.Contains($name)) {
        throw "Unknown client '$name'"
    }

    if ($holds -contains $name -and -not $Force) {
        $status = "on hold (tools/upstream/hold.txt)"
    }
    else {
        try {
            $sources = @(& $clients[$name].Sources)
            $fingerprint = (Get-Sha256 (($sources | ForEach-Object { $_.key }) -join "`n")).Substring(0, 12)
            $branch = "bot/$name/$fingerprint"

            $statePath = Join-Path $stateDir "$name.json"
            $state = if (Test-Path $statePath) { Get-Content -Raw $statePath | ConvertFrom-Json } else { $null }

            $proposed = $null
            if (-not $Force -and $state.fingerprint -ne $fingerprint) {
                $proposed = Invoke-WithRetry {
                    $prs = gh pr list --state all --head $branch --json number,state
                    if ($LASTEXITCODE) { throw "gh pr list failed for $branch" }
                    $prs | ConvertFrom-Json
                }
            }

            if (-not $Force -and $state.fingerprint -eq $fingerprint) {
                $status = "up to date"
            }
            elseif ($proposed) {
                $pr = @($proposed)[0]
                $status = "already proposed in #$($pr.number) ($($pr.state.ToLowerInvariant()))"
            }
            else {
                $primary = $sources[0]
                $oldPrimary = @($state.sources) | Where-Object { $_.name -eq $primary.name } | Select-Object -First 1
                $title = if ($primary.kind -eq "release" -and $oldPrimary.key -ne $primary.key) { "update $name to $($primary.version)" } else { "update $name" }

                $status = "**update needed** ($fingerprint)"
                $pending += [ordered]@{
                    client      = $name
                    script      = $clients[$name].Script
                    fingerprint = $fingerprint
                    branch      = $branch
                    title       = $title
                    sources     = ConvertTo-Json -InputObject $sources -Depth 3 -Compress
                }
            }
        }
        catch {
            $failed += $name
            $status = "**check failed**: " + ($_.Exception.Message -replace '\s+', ' ' -replace '\|', '\|')
        }
    }

    Write-Host ("{0}: {1}" -f $name, $status)
    $summary += "| $name | $status |"
}

$matrixJson = ConvertTo-Json -InputObject @($pending) -Depth 4 -Compress
if ($env:GITHUB_OUTPUT) {
    "clients=$matrixJson" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}
if ($env:GITHUB_STEP_SUMMARY) {
    $summary | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
}
if (-not $env:CI) {
    Write-Host $matrixJson
}

# Fail only after the outputs are written, so the clients that did check out still get updated
if ($failed) {
    throw "Upstream check failed for: $($failed -join ', ')"
}
