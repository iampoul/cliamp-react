#!/usr/bin/env bash
# Install cliamp-react for the current user.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_DIR="$HOME/.config/cliamp-react"
SYSTEMD_DIR="$HOME/.config/systemd/user"
HOOK_DIR="$HOME/.config/omarchy/hooks/theme-set.d"

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

systemctl --user daemon-reload
systemctl --user enable --now cliamp-react.service

echo
echo "cliamp-react installed. Start cliamp and play something."
echo "  ${BIN}/cliamp-react-ctl status"
echo "  config: $CONFIG_DIR/config.toml"
