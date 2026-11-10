[CmdletBinding()]
param(
    [string]$BucketPath = (Join-Path $PSScriptRoot '..\bucket')
)

$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $BucketPath 'sally.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Missing manifest: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

if ($manifest.version -notmatch '^\d+(\.\d+){1,3}$') {
    throw "Invalid or missing version: '$($manifest.version)'"
}
if ($manifest.homepage -ne 'https://get-sally.app/') {
    throw 'Unexpected Sally homepage.'
}
if ($manifest.checkver.github -ne 'https://github.com/0xeb/sally') {
    throw 'checkver.github must point to the official Sally repository.'
}
if ($manifest.bin -ne 'sally.exe') {
    throw "Expected bin to be 'sally.exe'."
}

$expected = @{
    '64bit' = 'x64'
    '32bit' = 'x86'
    'arm64' = 'ARM64'
}

foreach ($arch in $expected.Keys) {
    $entry = $manifest.architecture.($arch)
    if (-not $entry) { throw "Missing architecture block: $arch" }
    if ($entry.url -notmatch [regex]::Escape("Sally-v$($manifest.version)-$($expected[$arch]).zip")) {
        throw "Unexpected $arch download URL: $($entry.url)"
    }
    if ($entry.hash -notmatch '^[a-fA-F0-9]{64}$') {
        throw "The $arch SHA-256 is not initialized. Run .\scripts\Update-SallyManifest.ps1 first."
    }
}

foreach ($arch in $expected.Keys) {
    $url = $manifest.autoupdate.architecture.($arch).url
    if ($url -notmatch [regex]::Escape("Sally-v`$version-$($expected[$arch]).zip")) {
        throw "Invalid autoupdate URL for $arch."
    }
}

if ($manifest.autoupdate.hash.url -ne 'https://github.com/0xeb/sally/releases/download/v$version/Sally-v$version-SHA256SUMS.txt') {
    throw 'Unexpected autoupdate checksum URL.'
}

Write-Host "PASS: sally.json is valid and all three architecture hashes are initialized." -ForegroundColor Green
Write-Host "Current version: $($manifest.version)"
