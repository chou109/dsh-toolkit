#!/usr/bin/env bash
# install.sh — dsh-toolkit unified installer (macOS / Linux).
# Installs all four components: vision-bridge (patches), workspace-launcher
# (plugin + patch), msgrail (plugin + layout patch), archives (plugin).
#
# Usage:
#   ./install.sh            # install everything (idempotent)
#   ./install.sh --uninstall

set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PROFILE="$DSH_HOME/profiles"
CORDIS="$PROFILE/web/cordis.patch.yml"

log() { printf '[dsh-toolkit] %s\n' "$*"; }
die() { printf '[dsh-toolkit] ERROR: %s\n' "$*" >&2; exit 1; }

declare -A PATCHES=(
  [host-apiproxy]="$PROFILE/node_modules/@deepseek-ai/dsh-host-apiproxy/lib/index.js"
  [llm-pi-ai]="$PROFILE/node_modules/@deepseek-ai/dsh-llm-pi-ai/lib/index.js"
  [client-ui-workspace]="$PROFILE/node_modules/@deepseek-ai/dsh-client-ui-workspace/lib/client.js"
)

declare -A PLUGINS=(
  [workspace-launcher]="$REPO/components/workspace-launcher/plugin/dsh-workspace-launcher"
  [msgrail]="$REPO/components/msgrail/plugin/dsh-msgrail"
  [archives]="$REPO/components/archives/plugin/dsh-archives"
)

LAYOUT_CLIENT="$PROFILE/node_modules/@deepseek-ai/dsh-client-ui-layout/lib/client.js"
LAYOUT_MARKER='dsh-session-history (patched)'

patched() { # patched <key>
  case "$1" in
    host-apiproxy)        grep -q 'MODEL_DOES_NOT_SUPPORT_IMAGES' "${PATCHES[$1]}" ;;  # patched => ABSENT
    llm-pi-ai)            grep -q 'projectImageBlocksToText' "${PATCHES[$1]}" ;;       # patched => PRESENT
    client-ui-workspace)  grep -q 'dsh-workspace-open: reveal the workspace folder' "${PATCHES[$1]}" ;;
  esac
}

apply_patch() { # apply_patch <key> <reverse?>
  local name="$1" rev="${2:-}" f="${PATCHES[$1]}"
  local patch
  case "$name" in
    host-apiproxy)        patch="$REPO/components/vision-bridge/patches/dsh-host-apiproxy.patch" ;;
    llm-pi-ai)            patch="$REPO/components/vision-bridge/patches/dsh-llm-pi-ai.patch" ;;
    client-ui-workspace)  patch="$REPO/components/workspace-launcher/patches/dsh-client-ui-workspace.patch" ;;
  esac
  if [[ -n "$rev" ]]; then
    ( cd "$(dirname "$f")" && git -c core.autocrlf=false apply --unsafe-paths --directory="$(dirname "$f")" -R "$patch" )
  else
    ( cd "$(dirname "$f")" && git -c core.autocrlf=false apply --unsafe-paths --directory="$(dirname "$f")" "$patch" )
  fi
}

cordis_has() { grep -q -- "- id: $1" "$CORDIS" 2>/dev/null; }

cordis_add() { # cordis_add <id> <name> <comment>
  cordis_has "$1" && return 0
  cat >> "$CORDIS" <<EOF

# $3
- insert:
    - id: $1
      name: '$2'
EOF
  log "cordis entry '$1' added"
}

cordis_remove() { # cordis_remove <id>
  cordis_has "$1" || return 0
  python3 - "$CORDIS" "$1" <<'PY'
import re, sys
path, pid = sys.argv[1], sys.argv[2]
src = open(path, encoding="utf-8").read()
pat = re.compile(r"(?m)^#[^\r\n]*" + re.escape(pid) + r"[^\r\n]*\r?\n- insert:\r?\n\s+- id: " + re.escape(pid) + r"\r?\n\s+name: '[^']*'\r?\n")
open(path, "w", encoding="utf-8", newline="").write(pat.sub("", src))
PY
  log "cordis entry '$1' removed"
}

if [[ "${1:-}" == "--uninstall" ]]; then
  for k in "${!PLUGINS[@]}"; do
    rm -rf "$PROFILE/node_modules/${k#workspace-}"
  done
  rm -rf "$PROFILE/node_modules/dsh-workspace-launcher" "$PROFILE/node_modules/dsh-msgrail" "$PROFILE/node_modules/dsh-archives"
  for k in workspace-launcher msgrail archives; do cordis_remove "$k"; done
  for k in "${!PATCHES[@]}"; do
    [[ -f "${PATCHES[$k]}" ]] || continue
    if patched "$k"; then apply_patch "$k" -R; log "reverted $k"; fi
  done
  if [[ -f "$LAYOUT_CLIENT" ]] && grep -qF "$LAYOUT_MARKER" "$LAYOUT_CLIENT"; then
    log "msgrail layout is patched — reinstall @deepseek-ai/dsh-client-ui-layout@0.1.0-rc.6 to restore it."
  fi
  log "uninstall done; restart the harness to apply"
  exit 0
fi

command -v git >/dev/null || die "git is required for the patch-based components."
command -v node >/dev/null || die "node is required for the msgrail layout patch."

for k in "${!PATCHES[@]}"; do
  [[ -f "${PATCHES[$k]}" ]] || die "$k target not found: ${PATCHES[$k]}"
  if patched "$k"; then log "$k already patched, skipping"; else
    apply_patch "$k"
    patched "$k" || die "$k: git apply exited 0 but the file did not change (non-ASCII path quirk). Apply patch manually."
    log "$k patched"
  fi
done

for k in workspace-launcher msgrail archives; do
  src="${PLUGINS[$k]}"; dst="$PROFILE/node_modules/$k"
  mkdir -p "$dst/lib"
  cp "$src/package.json" "$dst/package.json"
  cp "$src/lib/index.js" "$dst/lib/index.js"
  cp "$src/lib/client.js" "$dst/lib/client.js"
  log "plugin $k copied -> $dst"
done
cordis_add workspace-launcher dsh-workspace-launcher 'dsh-toolkit: open the workspace in File Explorer / VS Code / terminal, or copy its path'
cordis_add msgrail dsh-msgrail 'dsh-toolkit: full-history message rail on the left of the chat'
cordis_add archives dsh-archives 'dsh-toolkit: archived sessions at the sidebar foot'

if [[ -f "$LAYOUT_CLIENT" ]] && grep -qF "$LAYOUT_MARKER" "$LAYOUT_CLIENT"; then
  log "msgrail layout already patched, skipping"
else
  node "$REPO/components/msgrail/scripts/patch-layout.mjs" "$LAYOUT_CLIENT"
  grep -qF "$LAYOUT_MARKER" "$LAYOUT_CLIENT" || die "msgrail layout patch reported success but the file did not change."
  log "msgrail layout patched"
fi

log "installed. Restart the harness (run 'dsh web --host 127.0.0.1 --port 3080' again) and hard-refresh the browser."
