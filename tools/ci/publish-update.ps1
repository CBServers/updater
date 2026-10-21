# Script: publish-update.ps1
# Runs in CI after a client's update script. Records the new upstream state in
# tools/upstream/<client>.json, then either opens a PR from
# bot/<client>/<fingerprint> for approval (closing older bot PRs for that
# client), or pushes straight to main when only the state file changed.

param(
    [Parameter(Mandatory)][string]$Client,
    [Parameter(Mandatory)][string]$Fingerprint,
    [Parameter(Mandatory)][string]$Branch,
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$SourcesJson,
    [string]$Reviewer
)

$ErrorActionPreference = "Stop"

$rootDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $rootDir

$folder = "updater/$Client"
$manifestPath = "updater/$Client.json"
$statePath = "tools/upstream/$Client.json"

function Invoke-Git {
    git @args
    if ($LASTEXITCODE) { throw "git $($args -join ' ') failed with exit code $LASTEXITCODE" }
}

function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1MB) { "{0:N1} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { "{0:N1} KB" -f ($Bytes / 1KB) }
    else { "$Bytes B" }
}

function Get-ManifestEntries {
    param([string]$Json)
    $entries = @{}
    foreach ($entry in ($Json | ConvertFrom-Json)) {
        if ($entry -is [array]) { $entries[$entry[0]] = $entry }
    }
    $entries
}

# 1. CI checks out LFS files as pointers; one surviving means the hasher hashed the pointer
$pointers = Get-ChildItem $folder -File -Recurse | Where-Object {
    $_.Length -lt 1024 -and [System.IO.File]::ReadAllText($_.FullName).StartsWith("version https://git-lfs.github.com/spec/v1")
}
if ($pointers) {
    throw "LFS pointer files were not replaced by the update script: $($pointers.FullName -join ', ')"
}

# 2. Record the new upstream state
$sources = @($SourcesJson | ConvertFrom-Json)
$oldState = if (Test-Path $statePath) { Get-Content -Raw $statePath | ConvertFrom-Json } else { $null }
New-Item -ItemType Directory -Path (Split-Path -Parent $statePath) -Force | Out-Null
$stateJson = [ordered]@{ fingerprint = $Fingerprint; sources = $sources } | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText((Join-Path $rootDir $statePath), ($stateJson -replace "`r`n", "`n") + "`n")

# 3. Stage the client's files
Invoke-Git config user.name "github-actions[bot]"
Invoke-Git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
Invoke-Git lfs install --local
Invoke-Git add -A -- $folder $manifestPath $statePath

git diff --cached --quiet -- $folder $manifestPath
$contentChanged = $LASTEXITCODE -ne 0
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "Nothing changed for $Client."
    exit 0
}

if (-not $contentChanged) {
    # Upstream moved but the mirrored files are identical: record it on main so it isn't rebuilt every hour
    Invoke-Git commit -m "record $Client upstream state"
    $commit = git rev-parse HEAD
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        git push origin HEAD:refs/heads/main
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Recorded $Client upstream state on main (no file changes)."
            exit 0
        }
        Start-Sleep -Seconds (5 * $attempt)
        Invoke-Git fetch --depth=1 origin main
        Invoke-Git checkout --force -B state-update FETCH_HEAD
        Invoke-Git cherry-pick $commit
    }
    throw "Could not push the $Client state to main"
}

# 4. Describe the update: upstream versions, then the manifest diff players will download
$sourceRows = foreach ($source in $sources) {
    $before = @($oldState.sources) | Where-Object { $_.name -eq $source.name } | Select-Object -First 1
    $was = if ($before) { $before.version } else { "-" }
    $changed = if ($before.key -eq $source.key) { "no" } else { "**yes**" }
    "| $($source.name) | $was | [$($source.version)]($($source.url)) | $changed |"
}

$oldManifest = git show "HEAD:$manifestPath" 2>$null
$old = if ($LASTEXITCODE -eq 0) { Get-ManifestEntries ($oldManifest -join "`n") } else { @{} }
$new = Get-ManifestEntries (Get-Content -Raw $manifestPath)
$fileRows = foreach ($path in (@($old.Keys) + @($new.Keys) | Sort-Object -Unique)) {
    $before = $old[$path]
    $after = $new[$path]
    if (-not $before) { "| added | ``$path`` | | $(Format-Size $after[1]) |" }
    elseif (-not $after) { "| removed | ``$path`` | $(Format-Size $before[1]) | |" }
    elseif ($before[2] -ne $after[2]) { "| changed | ``$path`` | $(Format-Size $before[1]) | $(Format-Size $after[1]) |" }
}
$fileRows = @($fileRows)

$body = @(
    "Automated mirror update for **$Client**."
    ""
    "### Upstream"
    "| Source | Was | Now | Changed |"
    "| --- | --- | --- | --- |"
    $sourceRows
    ""
    "### Files players will download ($($fileRows.Count))"
)
if ($fileRows) {
    $body += "| | File | Was | Now |"
    $body += "| --- | --- | --- | --- |"
    $body += $fileRows | Select-Object -First 100
    if ($fileRows.Count -gt 100) { $body += "", "...and $($fileRows.Count - 100) more." }
}
else {
    $body += "No manifest entries changed."
}
$body += @(
    ""
    "**Merge** to ship this to players. **Close** to skip this version; it won't be proposed again, and the next upstream release opens a new PR."
    "If it turns out broken after merging, use **Revert** on this PR. To pause $Client updates entirely, add it to ``tools/upstream/hold.txt``."
)
$bodyFile = Join-Path ([System.IO.Path]::GetTempPath()) "pr-body-$Client.md"
[System.IO.File]::WriteAllText($bodyFile, ($body -join "`n"))

# 5. Push the branch and open (or refresh) its PR
Invoke-Git switch -c $Branch
Invoke-Git commit -m $Title
Invoke-Git push --force origin "HEAD:refs/heads/$Branch"

$existing = @(gh pr list --state open --head $Branch --json url | ConvertFrom-Json)
if ($existing) {
    $prUrl = $existing[0].url
    gh pr edit $prUrl --title $Title --body-file $bodyFile
    if ($LASTEXITCODE) { throw "gh pr edit failed" }
}
else {
    $prUrl = gh pr create --base main --head $Branch --title $Title --body-file $bodyFile
    if ($LASTEXITCODE) { throw "gh pr create failed" }
}
Write-Host "PR: $prUrl"

if ($Reviewer) {
    gh pr edit $prUrl --add-reviewer $Reviewer
    if ($LASTEXITCODE) { Write-Host "::warning::Could not request a review from $Reviewer" }
}

# 6. An older bot PR for this client is now stale
$open = @(gh pr list --state open --json number,headRefName --limit 200 | ConvertFrom-Json)
foreach ($pr in $open) {
    if ($pr.headRefName -like "bot/$Client/*" -and $pr.headRefName -ne $Branch) {
        gh pr close $pr.number --comment "Superseded by $prUrl" --delete-branch
        if ($LASTEXITCODE) { Write-Host "::warning::Could not close superseded PR #$($pr.number)" }
    }
}

exit 0
