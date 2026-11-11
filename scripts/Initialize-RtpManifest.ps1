[CmdletBinding()]
param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\bucket\rpg-vx-ace-rtp.json')
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

$downloadUrl = 'https://assets.rpgmakerweb.com/RPGVXAce_RTP.zip'
$tempZip = Join-Path ([IO.Path]::GetTempPath()) ("RPGVXAce_RTP-" + [guid]::NewGuid().ToString('N') + '.zip')

try {
    Write-Host 'Downloading the official RPG Maker VX Ace RTP archive...' -ForegroundColor Cyan
    Write-Host $downloadUrl

    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing

    $file = Get-Item -LiteralPath $tempZip
    if ($file.Length -lt 100MB) {
        throw "The downloaded file is unexpectedly small ($($file.Length) bytes). It may be an error page, not the RTP ZIP."
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($tempZip)
    try {
        $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
        $setupFound = $entryNames | Where-Object { $_ -match '(^|/)RPGVXAce_RTP100/Setup\.exe$' } | Select-Object -First 1
        $payloadFound = $entryNames | Where-Object { $_ -match '(^|/)RPGVXAce_RTP100/Setup-1\.bin$' } | Select-Object -First 1

        if (-not $setupFound -or -not $payloadFound) {
            throw "The ZIP does not contain the expected RPGVXAce_RTP100/Setup.exe and Setup-1.bin entries. No manifest changes were made."
        }
    }
    finally {
        $archive.Dispose()
    }

    $hash = (Get-FileHash -LiteralPath $tempZip -Algorithm SHA256).Hash.ToLowerInvariant()

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "Manifest not found: $ManifestPath"
    }

    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    if ($manifest.url -ne $downloadUrl) {
        throw "Manifest URL differs from the official URL. Refusing to update: $($manifest.url)"
    }

    $manifest.version = '1.00'
    $manifest.hash = $hash

    $json = $manifest | ConvertTo-Json -Depth 30
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Resolve-Path -LiteralPath $ManifestPath).Path, ($json + [Environment]::NewLine), $utf8NoBom)

    Write-Host ''
    Write-Host 'RPG Maker VX Ace RTP manifest initialized.' -ForegroundColor Green
    Write-Host "Archive size: $($file.Length) bytes"
    Write-Host "SHA-256:      $hash"
    Write-Host ''
    Write-Host 'Next: run .\scripts\Test-Bucket.ps1 and review git diff before committing.'
}
finally {
    Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
}
