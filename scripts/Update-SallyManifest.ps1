[CmdletBinding()]
param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\bucket\sally.json')
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = '0xeb/sally'
$api = "https://api.github.com/repos/$repo/releases/latest"
$headers = @{
    'User-Agent' = 'scoop-sally-bucket-maintainer'
    'Accept'     = 'application/vnd.github+json'
}

Write-Host "Querying the latest Sally release..." -ForegroundColor Cyan
$release = Invoke-RestMethod -Uri $api -Headers $headers -Method Get
$version = ([string]$release.tag_name) -replace '^[vV]', ''

if ($version -notmatch '^\d+(\.\d+){1,3}$') {
    throw "Unexpected Sally release tag: $($release.tag_name)"
}

$checksumName = "Sally-v$version-SHA256SUMS.txt"
$checksumAsset = $release.assets | Where-Object { $_.name -eq $checksumName } | Select-Object -First 1
if (-not $checksumAsset) {
    throw "The release does not contain the expected checksum asset '$checksumName'. No manifest changes were made."
}

$tempChecksum = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString() + '.txt')
try {
    Write-Host "Downloading publisher checksums: $checksumName"
    Invoke-WebRequest -Uri $checksumAsset.browser_download_url -Headers $headers -OutFile $tempChecksum -UseBasicParsing
    $checksumText = [IO.File]::ReadAllText($tempChecksum)

    $architectures = @(
        @{ Key = '64bit'; AssetSuffix = 'x64' },
        @{ Key = '32bit'; AssetSuffix = 'x86' },
        @{ Key = 'arm64'; AssetSuffix = 'ARM64' }
    )

    $resolved = @{}
    foreach ($arch in $architectures) {
        $assetName = "Sally-v$version-$($arch.AssetSuffix).zip"
        $asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
        if (-not $asset) {
            throw "The release is missing expected runtime asset '$assetName'. No manifest changes were made."
        }

        $escapedName = [regex]::Escape($assetName)
        $patterns = @(
            "(?im)^\s*([a-f0-9]{64})\s+\*?$escapedName\s*$",
            "(?im)^\s*SHA256\s*\(\s*$escapedName\s*\)\s*=\s*([a-f0-9]{64})\s*$"
        )

        $hash = $null
        foreach ($pattern in $patterns) {
            $match = [regex]::Match($checksumText, $pattern)
            if ($match.Success) {
                $hash = $match.Groups[1].Value.ToLowerInvariant()
                break
            }
        }

        if (-not $hash) {
            throw "Could not find a SHA-256 entry for '$assetName' in '$checksumName'. No manifest changes were made."
        }

        $resolved[$arch.Key] = @{
            Url  = $asset.browser_download_url
            Hash = $hash
        }
    }

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "Manifest not found: $ManifestPath"
    }

    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    $manifest.version = $version

    foreach ($arch in $architectures) {
        $entry = $manifest.architecture.($arch.Key)
        if (-not $entry) {
            throw "Manifest is missing architecture '$($arch.Key)'."
        }
        $entry.url = $resolved[$arch.Key].Url
        $entry.hash = $resolved[$arch.Key].Hash
    }

    $json = $manifest | ConvertTo-Json -Depth 30
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Resolve-Path $ManifestPath).Path, ($json + [Environment]::NewLine), $utf8NoBom)

    Write-Host ""
    Write-Host "Updated Sally manifest to v$version with publisher SHA-256 checksums:" -ForegroundColor Green
    foreach ($arch in $architectures) {
        Write-Host ("  {0}: {1}" -f $arch.Key, $resolved[$arch.Key].Hash)
    }
    Write-Host ""
    Write-Host "Next: run .\scripts\Test-Bucket.ps1, then commit the updated manifest."
}
finally {
    Remove-Item -LiteralPath $tempChecksum -Force -ErrorAction SilentlyContinue
}
