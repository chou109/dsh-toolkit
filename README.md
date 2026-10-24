# dsh-toolkit — DeepSeek Harness 0.2.x enhancement pack

Two plug-and-play client plugins for **DeepSeek Harness 0.2.1-rc.2**, installed as
normal bundles — **no patches, no edited Harness files**:

| Component | Version | What it adds |
|---|---|---|
| **MsgRail** (`dsh-msgrail`) | 2.0.0 | Full-history rail of *your* messages below the composer: hover to preview, click to jump |
| **Workspace Launcher** (`dsh-workspace-launcher`) | 2.0.0 | Session-header menu: open the workspace in Explorer / VS Code / terminal, or copy its path |

> 中文版见 [README.zh.md](README.zh.md)。

## What changed in 0.2.x

The 1.x toolkit was patch-based: it edited `dsh-client-ui-layout`,
`dsh-client-ui-workspace`, `dsh-host-apiproxy`, and `dsh-llm-pi-ai`. DSH 0.2
builds every client package as a dynamic bundle, so editing installed files is
unsafe and no longer needed. Both surviving components now contribute through
documented slots and host routes.

| Old component | 0.2.x status |
|---|---|
| **msgrail** | ✅ Ported to 2.0.0 — `conversation.composer.dock`, session `eventSource`, no layout patch |
| **workspace-launcher** | ✅ Ported to 2.0.0 — Session-header action, no workspace-client patch |
| **archives** | ⛔ **Retired** — DSH 0.2 has native archive/unarchive (row menu + view filter). Nothing to install |
| **vision-bridge** | ⏸ **Not ported** — its two Host patches target 0.1.x packages. Use the harness's own image-capable route or a vision MCP; see `components/vision-bridge/` for the historical patches |

## Requirements

- DeepSeek Harness **0.2.1-rc.2** (Desktop or `dsh web`)
- Nothing else: no `git`, no `node` build step for the plugins themselves

## Install

### Plugin Manager (Desktop, recommended)

1. Plugins → install from folder.
2. Choose `components/msgrail/plugin/dsh-msgrail`.
3. Repeat for `components/workspace-launcher/plugin/dsh-workspace-launcher`.
4. Enable both; reload the page.

### CLI

```bash
dsh plugin --profile <profile> add /absolute/path/to/components/msgrail/plugin/dsh-msgrail
dsh plugin --profile <profile> add /absolute/path/to/components/workspace-launcher/plugin/dsh-workspace-launcher
```

### Script

```powershell
.\install.ps1                 # Windows: installs/links both bundles
```

```bash
./install.sh                  # macOS / Linux
```

The scripts never patch a Harness package. If the `dsh` CLI is unavailable they
print the Plugin Manager steps instead.

## Verify

1. **MsgRail** — open a conversation with a message from you; a tick strip appears
   below the composer. Hover → preview; click → transcript scrolls.
2. **Workspace Launcher** — the Session header shows “Open workspace”; the menu
   opens Explorer / VS Code / a terminal and copies the path.

## Uninstall

Disable or remove the two bundles in Plugin Manager (or the `insert` rows in
`cordis.patch.yml`) and reload. Because nothing was patched, no restore step is
needed.

## Why the patches are gone

A 0.1.x patch survived only until the next Harness update and could corrupt an
installed bundle if the surrounding code changed. The 0.2 plugin contract
(`dsh.bundle.patch` + `dsh.client` + slot services) is stable across releases and
is the only supported extension point. If a future release changes a slot or a
service signature, the plugin fails visibly in its own slot instead of breaking
the shell.

## Repository layout

```
components/
  msgrail/plugin/dsh-msgrail/                     bundle (manifest + patch + client)
  workspace-launcher/plugin/dsh-workspace-launcher/
  archives/                                       retired 0.1.x reference
  vision-bridge/                                  0.1.x patches (not ported)
install.ps1 / install.sh                          bundle-only installer
```

## License

MIT.
