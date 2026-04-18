#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_SRC="$SCRIPT_DIR/../themes/plasma/kanagawa/kanagawa-wave"
COLOR_SRC="$THEME_SRC/colors"

THEME_DST_DIR="$HOME/.local/share/plasma/desktoptheme"
THEME_DST="$THEME_DST_DIR/kanagawa-wave"
COLOR_DST_DIR="$HOME/.local/share/color-schemes"
COLOR_DST="$COLOR_DST_DIR/Kanagawa Wave.colors"
ARCHIVE_DIR="$HOME/.local/share/plasma/desktoptheme-archive"

if [[ ! -d "$THEME_SRC" ]]; then
  echo "Theme source not found: $THEME_SRC" >&2
  exit 1
fi

if [[ ! -f "$COLOR_SRC" ]]; then
  echo "Color scheme source not found: $COLOR_SRC" >&2
  exit 1
fi

mkdir -p "$THEME_DST_DIR" "$COLOR_DST_DIR"

# No backups: replace the installed desktop theme in place.
rm -rf "$THEME_DST"
cp -a "$THEME_SRC" "$THEME_DST"
cp -f "$COLOR_SRC" "$COLOR_DST"

# Remove old backup folders so Plasma does not show duplicate theme entries.
find "$THEME_DST_DIR" -maxdepth 1 -mindepth 1 -type d -name 'kanagawa-wave.bak.*' -exec rm -rf {} +
if [[ -d "$ARCHIVE_DIR" ]]; then
  find "$ARCHIVE_DIR" -maxdepth 1 -mindepth 1 -type d -name 'kanagawa-wave.bak.*' -exec rm -rf {} +
fi

echo "Installed desktop theme: kanagawa-wave"
echo "Installed color scheme: Kanagawa Wave"
echo "Installed theme dir: $THEME_DST"
echo "Installed color file: $COLOR_DST"
