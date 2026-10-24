#!/usr/bin/env bash
# install.sh — dsh-toolkit installer for DeepSeek Harness 0.2.x.
#
# Installs the two supported bundles (MsgRail + Workspace Launcher) through the
# `dsh` CLI when it is on PATH. It never patches a Harness package and never
# touches archives/vision-bridge (retired / not ported).

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
profile="${DSH_PROFILE:-desktop}"
bundles=(
  "$repo_root/components/msgrail/plugin/dsh-msgrail"
  "$repo_root/components/workspace-launcher/plugin/dsh-workspace-launcher"
)

step() { printf '[dsh-toolkit] %s\n' "$1"; }

for bundle in "${bundles[@]}"; do
  [ -d "$bundle" ] || { echo "bundle directory not found: $bundle" >&2; exit 1; }
done

step "target profile: $profile"
for bundle in "${bundles[@]}"; do step "bundle: $bundle"; done

if ! command -v dsh >/dev/null 2>&1; then
  step "the 'dsh' CLI is not on PATH."
  cat <<EOF
Install from the Harness Plugin Manager instead:
  1) Plugins → install from folder, once per directory:
$(printf '     %s\n' "${bundles[@]}")
  2) Enable both bundles and reload the page.

archives is retired (DSH 0.2 has native archive support); vision-bridge is not
ported to 0.2.x. Nothing else needs installing.
EOF
  exit 0
fi

for bundle in "${bundles[@]}"; do
  step "installing $bundle"
  dsh plugin --profile "$profile" add "$bundle"
done

step "installed MsgRail + Workspace Launcher. Reload the page."
