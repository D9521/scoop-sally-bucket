[CmdletBinding()]
param(
    [string]$BucketPath = (Join-Path $PSScriptRoot '..\bucket')
)

$ErrorActionPreference = 'Stop'

function Read-Manifest([string]$Name) {
    $path = Join-Path $BucketPath "$Name.json"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing manifest: $path"
    }
    return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
}

# Sally
$sally = Read-Manifest 'sally'

if ($sally.version -notmatch '^\d+(\.\d+){1,3}$') {
    throw "Invalid Sally version: '$($sally.version)'"
}
if ($sally.homepage -ne 'https://get-sally.app/') {
    throw 'Unexpected Sally homepage.'
}
if ($sally.checkver.github -ne 'https://github.com/0xeb/sally') {
    throw 'checkver.github must point to the official Sally repository.'
}
if ($sally.bin -ne 'sally.exe') {
    throw "Expected Sally bin to be 'sally.exe'."
}

$sallyArchitectures = @{
    '64bit' = 'x64'
    '32bit' = 'x86'
    'arm64' = 'ARM64'
}
foreach ($arch in $sallyArchitectures.Keys) {
    $entry = $sally.architecture.($arch)
    if (-not $entry) { throw "Sally is missing architecture block: $arch" }
    if ($entry.url -notmatch [regex]::Escape("Sally-v$($sally.version)-$($sallyArchitectures[$arch]).zip")) {
        throw "Unexpected Sally $arch download URL: $($entry.url)"
    }
    if ($entry.hash -notmatch '^[a-fA-F0-9]{64}$') {
        throw "Sally $arch SHA-256 is not initialized. Run .\scripts\Update-SallyManifest.ps1 first."
    }
    $autoUrl = $sally.autoupdate.architecture.($arch).url
    if ($autoUrl -notmatch [regex]::Escape("Sally-v`$version-$($sallyArchitectures[$arch]).zip")) {
        throw "Invalid Sally autoupdate URL for $arch."
    }
}
if ($sally.autoupdate.hash.url -ne 'https://github.com/0xeb/sally/releases/download/v$version/Sally-v$version-SHA256SUMS.txt') {
    throw 'Unexpected Sally autoupdate checksum URL.'
}

# RPG Maker VX Ace RTP
$rtp = Read-Manifest 'rpg-vx-ace-rtp'

if ($rtp.version -ne '1.00') {
    throw "Unexpected RPG Maker VX Ace RTP version: '$($rtp.version)'"
}
if ($rtp.homepage -ne 'https://www.rpgmakerweb.com/run-time-package') {
    throw 'Unexpected RTP homepage.'
}
if ($rtp.url -ne 'https://assets.rpgmakerweb.com/RPGVXAce_RTP.zip') {
    throw 'RTP must download directly from the official RPG Maker website.'
}
if ($rtp.hash -notmatch '^[a-fA-F0-9]{64}$') {
    throw 'RTP SHA-256 is not initialized. Run .\scripts\Initialize-RtpManifest.ps1 first.'
}
if ($rtp.innosetup -ne $true) {
    throw 'RTP installer must be identified as Inno Setup.'
}
if ($rtp.installer.file -ne 'RPGVXAce_RTP100\Setup.exe') {
    throw 'Unexpected RTP installer path.'
}
$requiredArgs = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-')
foreach ($arg in $requiredArgs) {
    if ($rtp.installer.args -notcontains $arg) {
        throw "RTP installer is missing required argument: $arg"
    }
}
if (($rtp.pre_install -join ' ') -notmatch '\$global') {
    throw 'RTP must block per-user installation and require a global install.'
}
if (($rtp.uninstaller.script -join ' ') -notmatch 'unins000\.exe') {
    throw 'RTP uninstaller script does not reference the vendor uninstaller.'
}

Write-Host 'PASS: Sally manifest is valid and initialized.' -ForegroundColor Green
Write-Host 'PASS: RPG Maker VX Ace RTP manifest is valid, uses the official URL, has a pinned SHA-256, and requires global installation.' -ForegroundColor Green
