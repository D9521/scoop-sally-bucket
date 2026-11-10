param(
    [String]$Upstream = "D9521/scoop-sally-bucket:main"
)

if ($Upstream -match 'D9521') {
    throw "Edit bin/auto-pr.ps1 and replace D9521 with your GitHub account name."
}

if (!$env:SCOOP_HOME) {
    $env:SCOOP_HOME = Convert-Path (scoop prefix scoop)
}

$autoPr = Join-Path $env:SCOOP_HOME 'bin\auto-pr.ps1'
$manifestDir = Join-Path $PSScriptRoot '..\bucket'

& $autoPr -Dir $manifestDir -Upstream $Upstream @Args
