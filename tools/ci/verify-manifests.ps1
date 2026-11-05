param(
    [string]$Root = "updater"
)

$ErrorActionPreference = "Stop"

$failures = [System.Collections.Generic.List[string]]::new()
$checked = 0

foreach ($manifest in Get-ChildItem -Path $Root -Filter *.json -File) {
    $folder = Join-Path $Root $manifest.BaseName
    $entries = Get-Content -Raw -LiteralPath $manifest.FullName | ConvertFrom-Json -NoEnumerate

    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        $failures.Add("$($manifest.Name): folder $folder is missing")
        continue
    }

    foreach ($entry in $entries) {
        if ($entry -isnot [array]) { continue }
        $name, $size, $hash = $entry[0], $entry[1], $entry[2]
        $path = Join-Path $folder $name
        $checked++

        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $failures.Add("$($manifest.Name): $name is missing")
            continue
        }

        $file = Get-Item -LiteralPath $path
        if ($file.Length -ne $size) {
            $failures.Add("$($manifest.Name): $name is $($file.Length) bytes, manifest says $size")
            continue
        }

        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA1).Hash
        if ($actual -ne $hash.ToUpperInvariant()) {
            $failures.Add("$($manifest.Name): $name hashes to $actual, manifest says $hash")
        }
    }
}

Write-Host "Checked $checked files"

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "::error::$_" }
    exit 1
}
