# install.ps1 — dsh-toolkit installer for DeepSeek Harness 0.2.x.
#
# Installs the two supported bundles (MsgRail + Workspace Launcher) through the
# `dsh` CLI when it is on PATH. It never patches a Harness package and never
# touches archives/vision-bridge (retired / not ported).
#
# Usage:
#   .\install.ps1                 # use $env:DSH_PROFILE, else "desktop"
#   .\install.ps1 -Profile web
#   .\install.ps1 -NoInstall      # print manual steps only

param(
    [string]$Profile = $(if ($env:DSH_PROFILE) { $env:DSH_PROFILE } else { 'desktop' }),
    [switch]$NoInstall
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$bundles = @(
    (Join-Path $repoRoot 'components\msgrail\plugin\dsh-msgrail'),
    (Join-Path $repoRoot 'components\workspace-launcher\plugin\dsh-workspace-launcher')
)

function Write-Step([string]$msg) { Write-Host "[dsh-toolkit] $msg" -ForegroundColor Cyan }

foreach ($bundle in $bundles) {
    if (-not (Test-Path $bundle)) { throw "bundle directory not found: $bundle" }
}

Write-Step "target profile: $Profile"
$bundles | ForEach-Object { Write-Step "bundle: $_" }

if ($NoInstall) {
    Write-Step 'manual steps:'
    Write-Host @"
1) Harness → Plugins → install from folder, once per directory:
$(($bundles | ForEach-Object { "     $_" }) -join "`n")
2) Enable both bundles and reload the page.

archives is retired (DSH 0.2 has native archive support); vision-bridge is not
ported to 0.2.x. Nothing else needs installing.
"@
    exit 0
}

$dsh = Get-Command dsh -ErrorAction SilentlyContinue
if ($null -eq $dsh) {
    Write-Step 'the `dsh` CLI is not on PATH (Desktop installs usually are not).'
    Write-Step 'Use Plugins → install from folder, then enable these directories:'
    $bundles | ForEach-Object { Write-Host "  $_" }
    Write-Step 'archives: retired; vision-bridge: not ported to 0.2.x.'
    exit 0
}

foreach ($bundle in $bundles) {
    Write-Step "installing $bundle"
    & $dsh.Source plugin --profile $Profile add $bundle
    if ($LASTEXITCODE -ne 0) { throw "dsh plugin add failed for $bundle (exit $LASTEXITCODE)" }
}

Write-Step 'installed MsgRail + Workspace Launcher. Reload the page.'
