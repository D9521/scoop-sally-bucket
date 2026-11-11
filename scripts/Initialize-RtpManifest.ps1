[CmdletBinding()]
param(
    # Optional: use an already-downloaded ZIP instead of downloading again.
    [string]$ArchivePath = '',

    # Optional: override the manifest location. By default, this script expects
    # <bucket-root>\scripts\Initialize-RtpManifest.ps1 and
    # <bucket-root>\bucket\rpg-vx-ace-rtp.json.
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\bucket\rpg-vx-ace-rtp.json'),

    # Download a fresh copy even if the default temp ZIP already exists.
    [switch]$ForceDownload
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$downloadUrl = 'https://assets.rpgmakerweb.com/RPGVXAce_RTP.zip'
$defaultArchivePath = Join-Path $env:TEMP 'RPGVXAce_RTP.zip'
$downloadedByScript = $false

try {
    # Resolve the manifest path before doing any work.
    $ManifestPath = [System.IO.Path]::GetFullPath($ManifestPath)
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "Manifest not found: $ManifestPath`nRun this script from inside your bucket project, or pass -ManifestPath explicitly."
    }

    # Reuse the previous download by default. Pass -ForceDownload to refresh it.
    if ([string]::IsNullOrWhiteSpace($ArchivePath)) {
        $ArchivePath = $defaultArchivePath
        if ($ForceDownload -or -not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
            Write-Host 'Downloading the official RPG Maker VX Ace RTP archive...'
            Write-Host $downloadUrl

            # Windows PowerShell 5.1 may need TLS 1.2 selected explicitly.
            if ($PSVersionTable.PSVersion.Major -le 5) {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            }

            Invoke-WebRequest -Uri $downloadUrl -OutFile $ArchivePath -UseBasicParsing
            $downloadedByScript = $true
        }
        else {
            Write-Host "Reusing existing archive: $ArchivePath"
        }
    }
    else {
        $ArchivePath = [System.IO.Path]::GetFullPath($ArchivePath)
        if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
            throw "The specified archive does not exist: $ArchivePath"
        }
        Write-Host "Using supplied archive: $ArchivePath"
    }

    if ((Get-Item -LiteralPath $ArchivePath).Length -le 0) {
        throw "The downloaded ZIP is empty: $ArchivePath"
    }

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $zip = $null
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
        $files = @($zip.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) })

        # Do not hard-code the containing folder name. The official archive
        # currently uses RTP100/, while older packages may use another folder.
        $setupEntries = @($files | Where-Object {
            [string]::Equals($_.Name, 'Setup.exe', [System.StringComparison]::OrdinalIgnoreCase)
        })
        $dataEntries = @($files | Where-Object {
            [string]::Equals($_.Name, 'Setup-1.bin', [System.StringComparison]::OrdinalIgnoreCase)
        })

        if ($setupEntries.Count -ne 1 -or $dataEntries.Count -ne 1) {
            $entryList = ($zip.Entries | ForEach-Object { $_.FullName }) -join "`n  "
            throw "The ZIP must contain exactly one Setup.exe and one Setup-1.bin. Actual entries:`n  $entryList"
        }

        $setupEntry = $setupEntries[0]
        $dataEntry = $dataEntries[0]
        $setupDirectory = [System.IO.Path]::GetDirectoryName($setupEntry.FullName.Replace('/', '\'))
        $dataDirectory = [System.IO.Path]::GetDirectoryName($dataEntry.FullName.Replace('/', '\'))

        if (-not [string]::Equals($setupDirectory, $dataDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Setup.exe and Setup-1.bin are not in the same directory. Setup.exe: '$($setupEntry.FullName)'; Setup-1.bin: '$($dataEntry.FullName)'. No manifest changes were made."
        }

        if ($setupEntry.Length -le 0 -or $dataEntry.Length -le 0) {
            throw 'Setup.exe or Setup-1.bin is empty. No manifest changes were made.'
        }

        Write-Host "Validated installer files in '$setupDirectory'."
        Write-Host "  Setup.exe:   $($setupEntry.Length) bytes"
        Write-Host "  Setup-1.bin: $($dataEntry.Length) bytes"
    }
    finally {
        if ($null -ne $zip) {
            $zip.Dispose()
        }
    }

    # Hash the complete downloaded archive, not the extracted installer files.
    $sha256 = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host "Archive SHA-256: $sha256"

    # Update the manifest only after download, ZIP validation, and hashing succeed.
    $manifestText = [System.IO.File]::ReadAllText($ManifestPath, [System.Text.Encoding]::UTF8)
    $manifest = $manifestText | ConvertFrom-Json

    if ($null -eq $manifest) {
        throw "Manifest JSON is empty or invalid: $ManifestPath"
    }

    $hashProperty = $manifest.PSObject.Properties['hash']
    if ($null -eq $hashProperty) {
        $manifest | Add-Member -MemberType NoteProperty -Name 'hash' -Value $sha256
    }
    else {
        $manifest.hash = $sha256
    }

    $updatedJson = $manifest | ConvertTo-Json -Depth 100
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ManifestPath, ($updatedJson + [Environment]::NewLine), $utf8NoBom)

    Write-Host ''
    Write-Host 'Success: the RTP manifest has been updated.' -ForegroundColor Green
    Write-Host "Manifest: $ManifestPath"
    Write-Host "SHA-256:  $sha256"
}
catch {
    Write-Error $_
    throw
}
finally {
    # Only delete an archive that this run downloaded. A reused or user-supplied
    # archive is deliberately kept so it can be inspected or reused.
    if ($downloadedByScript -and (Test-Path -LiteralPath $ArchivePath)) {
        Remove-Item -LiteralPath $ArchivePath -Force -ErrorAction SilentlyContinue
    }
}
