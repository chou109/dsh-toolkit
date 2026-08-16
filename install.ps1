# install.ps1 — dsh-toolkit unified installer (Windows).
#
# Installs all four components into a local DeepSeek Harness (dsh) web profile:
#   1. vision-bridge     — paste-image auto-vision: patches @deepseek-ai/dsh-host-apiproxy
#                          (drop the "model does not support images" rejection) and
#                          @deepseek-ai/dsh-llm-pi-ai (project image blocks to a path
#                          placeholder the agent feeds to its vision tool).
#   2. workspace-launcher— open the workspace in File Explorer / VS Code / terminal,
#                          or copy its path: plugin package + patch to
#                          @deepseek-ai/dsh-client-ui-workspace (workspace row menu).
#   3. msgrail           — message-history rail UI: plugin package + layout patch to
#                          @deepseek-ai/dsh-client-ui-layout (shell.history column).
#   4. archives          — archived-sessions sidebar panel: plugin package only.
#
# Usage:
#   .\install.ps1            # install everything (idempotent) and restart the harness
#   .\install.ps1 -NoRestart # install only
#   .\install.ps1 -Uninstall # remove everything and restart
#
# Requirements: git (for the patch-based components), node (for the msgrail
# layout patch). Every patched file is re-verified by content afterwards — some
# git versions silently skip patches on non-ASCII paths, so exit code alone is
# not trusted.

param(
    [switch]$NoRestart,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$dshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }
$profiles = Join-Path $dshHome 'profiles'
$cordis = Join-Path $profiles 'web\cordis.patch.yml'

function Write-Step([string]$msg) { Write-Host "[dsh-toolkit] $msg" -ForegroundColor Cyan }
function Write-Bad([string]$msg) { Write-Host "[dsh-toolkit] ERROR: $msg" -ForegroundColor Red }

# ---------- helpers ----------

function Invoke-GitApply {
    # Apply (-R reverses) a patch to a target file with LF-safe settings, then
    # re-verify by content via $Check (scriptblock returning $true when patched).
    param([hashtable]$T, [switch]$Reverse)
    $file = $T.File
    $patch = $T.Patch
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) { Write-Bad "git is required for $($T.Name) — install git and retry."; exit 1 }
    Push-Location (Split-Path $file)
    if ($Reverse) { git -c core.autocrlf=false apply --unsafe-paths --directory=(Split-Path $file) -R $patch }
    else { git -c core.autocrlf=false apply --unsafe-paths --directory=(Split-Path $file) $patch }
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { Write-Bad "git apply failed for $($T.Name) — the installed package version may differ. See README (For AI: Debugging)."; exit 1 }
    $c = [System.IO.File]::ReadAllText($file)
    $ok = & $T.Check $c
    if (-not $ok) {
        Write-Bad "$($T.Name): git apply exited 0 but the file did not change (known non-ASCII-path quirk on Windows). Apply patch manually or move dsh to an ASCII path."
        exit 1
    }
}

function Update-CordisEntry {
    # Ensure a `- insert: { id, name }` block exists in cordis.patch.yml (idempotent).
    param([string]$Id, [string]$Name, [string]$Comment)
    if (-not (Test-Path $cordis)) { Write-Bad "cordis patch file not found: $cordis"; exit 1 }
    $y = Get-Content $cordis -Raw
    if ($y -match [regex]::Escape("$Id`:")) { Write-Step "cordis entry '$Id' already present, skipping"; return }
    $entry = "`n# $Comment`n- insert:`n    - id: $Id`n      name: '$Name'`n"
    Add-Content -Path $cordis -Value $entry -Encoding utf8
    Write-Step "cordis entry '$Id' added"
}

function Remove-CordisEntry {
    param([string]$Id)
    if (-not (Test-Path $cordis)) { return }
    $y = Get-Content $cordis -Raw
    $pattern = "(?m)^# [^\r\n]*$([regex]::Escape($Id))[^\r\n]*\r?\n- insert:\r?\n\s+- id: $([regex]::Escape($Id))\r?\n\s+name: '[^']*'\r?\n"
    if ($y -match $pattern) {
        $y = [regex]::Replace($y, $pattern, '')
        Set-Content -Path $cordis -Value $y -Encoding utf8 -NoNewline
        Write-Step "cordis entry '$Id' removed"
    }
}

# ---------- component table ----------

$pluginDirs = @(
    @{ Name = 'workspace-launcher'; Src = Join-Path $repoRoot 'components\workspace-launcher\plugin\dsh-workspace-launcher'; Dst = Join-Path $profiles 'node_modules\dsh-workspace-launcher'; CordisId = 'workspace-launcher'; CordisName = 'dsh-workspace-launcher'; Comment = 'dsh-toolkit: open the workspace in File Explorer / VS Code / terminal, or copy its path' },
    @{ Name = 'msgrail';           Src = Join-Path $repoRoot 'components\msgrail\plugin\dsh-msgrail';           Dst = Join-Path $profiles 'node_modules\dsh-msgrail';           CordisId = 'msgrail';           CordisName = 'dsh-msgrail';           Comment = 'dsh-toolkit: full-history message rail on the left of the chat' },
    @{ Name = 'archives';          Src = Join-Path $repoRoot 'components\archives\plugin\dsh-archives';          Dst = Join-Path $profiles 'node_modules\dsh-archives';          CordisId = 'archives';          CordisName = 'dsh-archives';          Comment = 'dsh-toolkit: archived sessions at the sidebar foot' }
)

$patches = @(
    @{
        Name  = 'dsh-host-apiproxy (vision-bridge)'
        File  = Join-Path $profiles 'node_modules\@deepseek-ai\dsh-host-apiproxy\lib\index.js'
        Patch = Join-Path $repoRoot 'components\vision-bridge\patches\dsh-host-apiproxy.patch'
        Check = { param($c) -not $c.Contains('MODEL_DOES_NOT_SUPPORT_IMAGES') }   # patch REMOVES this string
    },
    @{
        Name  = 'dsh-llm-pi-ai (vision-bridge)'
        File  = Join-Path $profiles 'node_modules\@deepseek-ai\dsh-llm-pi-ai\lib\index.js'
        Patch = Join-Path $repoRoot 'components\vision-bridge\patches\dsh-llm-pi-ai.patch'
        Check = { param($c) $c.Contains('projectImageBlocksToText') }              # patch ADDS this function
    },
    @{
        Name  = 'dsh-client-ui-workspace (workspace-launcher)'
        File  = Join-Path $profiles 'node_modules\@deepseek-ai\dsh-client-ui-workspace\lib\client.js'
        Patch = Join-Path $repoRoot 'components\workspace-launcher\patches\dsh-client-ui-workspace.patch'
        # Deployment marker matches the patched bundle (original id kept for compat).
        Check = { param($c) $c.Contains('dsh-workspace-open: reveal the workspace folder') }
    }
)

$layoutClient = Join-Path $profiles 'node_modules\@deepseek-ai\dsh-client-ui-layout\lib\client.js'
$layoutMarker = 'dsh-session-history (patched)'

# ---------- uninstall ----------

if ($Uninstall) {
    foreach ($p in $pluginDirs) {
        if (Test-Path $p.Dst) { Remove-Item $p.Dst -Recurse -Force; Write-Step "removed plugin $($p.Name)" }
        Remove-CordisEntry $p.CordisId
    }
    foreach ($t in $patches) {
        if (-not (Test-Path $t.File)) { Write-Step "skip $($t.Name): file missing"; continue }
        $c = [System.IO.File]::ReadAllText($t.File)
        if (& $t.Check $c) { Invoke-GitApply $t -Reverse; Write-Step "reverted $($t.Name)" }
        else { Write-Step "$($t.Name) not patched, nothing to undo" }
    }
    if (Test-Path $layoutClient) {
        $lc = [System.IO.File]::ReadAllText($layoutClient)
        if ($lc.Contains($layoutMarker)) {
            Write-Step "msgrail layout is patched — restore $layoutClient manually (reinstall @deepseek-ai/dsh-client-ui-layout@0.1.0-rc.6) or reverse the patch-layout.mjs edits."
        }
    }
    Write-Step "uninstall done. Restart the harness (start-dsh.bat) to apply."
    exit 0
}

# ---------- 1. vision-bridge patches ----------

foreach ($t in $patches) {
    if (-not (Test-Path $t.File)) { Write-Bad "$($t.Name) target not found: $($t.File)"; exit 1 }
    $c = [System.IO.File]::ReadAllText($t.File)
    if (& $t.Check $c) { Write-Step "$($t.Name) already patched, skipping" }
    else { Invoke-GitApply $t; Write-Step "$($t.Name) patched" }
}

# ---------- 2. plugin packages + cordis ----------

foreach ($p in $pluginDirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $p.Dst 'lib') | Out-Null
    Copy-Item (Join-Path $p.Src 'package.json') (Join-Path $p.Dst 'package.json') -Force
    Copy-Item (Join-Path $p.Src 'lib\index.js') (Join-Path $p.Dst 'lib\index.js') -Force
    Copy-Item (Join-Path $p.Src 'lib\client.js') (Join-Path $p.Dst 'lib\client.js') -Force
    Write-Step "plugin $($p.Name) copied -> $($p.Dst)"
    Update-CordisEntry $p.CordisId $p.CordisName $p.Comment
}

# ---------- 3. msgrail layout patch ----------

if (-not (Test-Path $layoutClient)) {
    Write-Bad "dsh-client-ui-layout not found at $layoutClient — msgrail needs the layout patch; skipping it would leave the rail without a column."
    exit 1
}
$layoutRaw = [System.IO.File]::ReadAllText($layoutClient)
if ($layoutRaw.Contains($layoutMarker)) {
    Write-Step "msgrail layout already patched, skipping"
} else {
    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) { Write-Bad "node is required for the msgrail layout patch."; exit 1 }
    & node (Join-Path $repoRoot 'components\msgrail\scripts\patch-layout.mjs') $layoutClient
    if ($LASTEXITCODE -ne 0) { Write-Bad "msgrail layout patch failed — the installed dsh-client-ui-layout version may differ."; exit 1 }
    $layoutRaw2 = [System.IO.File]::ReadAllText($layoutClient)
    if (-not $layoutRaw2.Contains($layoutMarker)) { Write-Bad "msgrail layout patch reported success but the file did not change."; exit 1 }
    Write-Step "msgrail layout patched"
}

# ---------- 4. restart ----------

if ($NoRestart) {
    Write-Step "installed. Restart the harness (close the 'DeepSeek Harness Server' window and run start-dsh.bat), then hard-refresh the browser (Ctrl+F5)."
} else {
    Write-Step "restarting the dsh web harness..."
    $node = Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -match 'dsh web' }
    foreach ($p in $node) { taskkill /F /T /PID $p.ProcessId 2>$null | Out-Null }
    Start-Sleep -Seconds 2
    Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', 'npx -y @deepseek-ai/dsh web --host 127.0.0.1 --port 3080' -WindowStyle Minimized
    Write-Step "harness restarting (http://127.0.0.1:3080). Hard-refresh the browser (Ctrl+F5) once it is back."
}
Write-Step "dsh-toolkit installed."
