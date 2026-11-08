#!/usr/bin/env bash
# Install cliamp-react for the current user.
#
#   ./install.sh              # everything: borders daemon + Omarchy bar plugin
#   ./install.sh --no-bar     # borders only (skip the bar plugin)
#   ./install.sh --no-restart # don't restart the shell at the end
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_DIR="$HOME/.config/cliamp-react"
SYSTEMD_DIR="$HOME/.config/systemd/user"
PLUGIN_ID="io.github.iampoul.cliamp-react"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
BAR_STATE_FILE="$CONFIG_DIR/previous-bar-background"

WITH_BAR=1
RESTART=1
for arg in "$@"; do
  case "$arg" in
    --no-bar) WITH_BAR=0 ;;
    --no-restart) RESTART=0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

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
  mkdir -p "$HOME/.config/omarchy/hooks/theme-set.d"
  install -m755 "$HERE/cliamp-react-palette" \
    "$HOME/.config/omarchy/hooks/theme-set.d/cliamp-react-palette"
  echo "installed theme-set hook"
fi

if (( WITH_BAR )) && [[ -d "$HOME/.config/omarchy" ]]; then
  echo "installing Omarchy bar plugin $PLUGIN_ID"
  mkdir -p "$PLUGIN_DIR"
  install -m644 "$HERE/bar/manifest.json" "$PLUGIN_DIR/manifest.json"
  install -m644 "$HERE/bar/Service.qml" "$PLUGIN_DIR/Service.qml"
  install -m644 "$HERE/bar/BarBackground.qml" "$PLUGIN_DIR/BarBackground.qml"
  install -m644 "$HERE/bar/BarWidget.qml" "$PLUGIN_DIR/BarWidget.qml"
  install -m644 "$HERE/bar/Spectrum.js" "$PLUGIN_DIR/Spectrum.js"

  omarchy plugin validate "$PLUGIN_DIR"

  # Remember the user's bar look so `cliamp-react-ctl bar off` can restore it.
  if [[ ! -f "$BAR_STATE_FILE" ]]; then
    previous=$(jq -r '.bar.background // "opaque"' "$HOME/.config/omarchy/shell.json" 2>/dev/null || echo "opaque")
    [[ "$previous" == "null" ]] && previous="opaque"
    printf '%s\n' "$previous" > "$BAR_STATE_FILE"
  fi

  omarchy shell shell rescanPlugins
  omarchy plugin enable "$PLUGIN_ID" --section centerBegin
  # Transparent bar: our Bottom-layer panel becomes the entire bar background,
  # so the spectrum fills the whole strip behind every widget.
  omarchy bar background none
  echo "enabled bar plugin; bar background set to none (was $(cat "$BAR_STATE_FILE"))"

  if (( RESTART )); then
    omarchy restart shell
    echo "restarted Omarchy shell"
  fi
elif (( WITH_BAR )); then
  echo "no ~/.config/omarchy found; skipped the bar plugin" >&2
fi

systemctl --user daemon-reload
systemctl --user enable --now cliamp-react.service

echo
echo "cliamp-react installed. Start cliamp and play something."
echo "  ${BIN}/cliamp-react-ctl status"
echo "  config: $CONFIG_DIR/config.toml"
