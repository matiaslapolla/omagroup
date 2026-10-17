#!/usr/bin/env bash
# Install omagroup into the Omarchy shell and put the CLI on PATH.
#
# Symlinks rather than copies, so editing this checkout hot-reloads the
# running shell — the plugin loader watches ~/.config/omarchy/plugins/.
set -euo pipefail

PLUGIN_ID="matiaslapolla.omagroup"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$(dirname "$DEST")" "$BIN_DIR"

if [[ "$SRC" != "$(readlink -f "$DEST" 2>/dev/null)" ]]; then
  if [[ -e "$DEST" && ! -L "$DEST" ]]; then
    echo "error: $DEST exists and is not a symlink; remove it first" >&2
    exit 1
  fi
  ln -sfn "$SRC" "$DEST"
  echo "linked $DEST -> $SRC"
fi

ln -sfn "$SRC/bin/omagroup" "$BIN_DIR/omagroup"
echo "linked $BIN_DIR/omagroup"

if ! command -v omarchy-shell >/dev/null 2>&1; then
  echo "warning: omarchy-shell not found; open a new session to pick the plugin up" >&2
  exit 0
fi

omarchy-shell shell rescanPlugins >/dev/null
omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1 \
  || omarchy-shell shell enablePlugin "$PLUGIN_ID" true >/dev/null
echo "enabled $PLUGIN_ID"
