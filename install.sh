#!/usr/bin/env bash
# Install cliamp-react for the current user.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_DIR="$HOME/.config/cliamp-react"
SYSTEMD_DIR="$HOME/.config/systemd/user"
HOOK_DIR="$HOME/.config/omarchy/hooks/theme-set.d"
PLUGIN_ID="io.github.iampoul.cliamp-react"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

mkdir -p "$BIN" "$CONFIG_DIR" "$SYSTEMD_DIR"

install -m755 "$HERE/cliamp-react" "$BIN/cliamp-react"
install -m755 "$HERE/cliamp-react-ctl" "$BIN/cliamp-react-ctl"
install -m755 "$HERE/cliamp-react-palette" "$BIN/cliamp-react-palette"
install -m644 "$HERE/cliamp-react.service" "$SYSTEMD_DIR/cliamp-react.service"

if [[ ! -f "$CONFIG_DIR/config.toml" ]]; then
  install -m644 "$HERE/config.toml.example" "$CONFIG_DIR/config.toml"
  echo "wrote $CONFIG_DIR/config.toml"
else
  echo "kept existing $CONFIG_DIR/config.toml"
fi

if [[ -d "$HOME/.config/omarchy" ]]; then
  mkdir -p "$HOOK_DIR"
  install -m755 "$HERE/cliamp-react-palette" "$HOOK_DIR/cliamp-react-palette"
  echo "installed theme-set hook"
fi

# Omarchy bar control plugin (bar pill + popup). Only when the shell exists.
if [[ -d "$HOME/.config/omarchy" && -d "$HERE/omarchy" ]]; then
  mkdir -p "$PLUGIN_DIR/i18n"
  install -m644 "$HERE/omarchy/manifest.json" "$PLUGIN_DIR/manifest.json"
  install -m644 "$HERE/omarchy/BarWidget.qml" "$PLUGIN_DIR/BarWidget.qml"
  install -m644 "$HERE/omarchy/Panel.qml" "$PLUGIN_DIR/Panel.qml"
  install -m644 "$HERE/omarchy/Model.js" "$PLUGIN_DIR/Model.js"
  install -m644 "$HERE/omarchy/i18n/en.json" "$PLUGIN_DIR/i18n/en.json"
  echo "installed Omarchy bar plugin $PLUGIN_ID at $PLUGIN_DIR"

  if command -v omarchy-shell >/dev/null 2>&1; then
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  fi
  if command -v omarchy >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    if ! omarchy plugin list --json 2>/dev/null |
      jq -e --arg id "$PLUGIN_ID" 'any(.[]; .id == $id and .enabled)' >/dev/null 2>&1; then
      omarchy plugin enable "$PLUGIN_ID" --section right ||
        echo "could not add $PLUGIN_ID to the bar; enable it with: omarchy plugin enable $PLUGIN_ID --section right" >&2
    fi
  fi
fi

systemctl --user daemon-reload
systemctl --user enable --now cliamp-react.service
# Pick up the freshly installed daemon/ctl even when the service was already up.
systemctl --user restart cliamp-react.service

echo
echo "cliamp-react installed. Start cliamp and play something."
echo "  ${BIN}/cliamp-react-ctl status"
echo "  ${BIN}/cliamp-react-ctl get        # effective border settings"
echo "  config: $CONFIG_DIR/config.toml"
echo "  overrides: $CONFIG_DIR/overrides.toml (written by the bar popup)"
