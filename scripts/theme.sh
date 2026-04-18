#!/usr/bin/env bash

set -euo pipefail

# Theme family variant mappings
declare -A THEME_VARIANTS=(
  [kanagawa-light]="kanagawa-lotus"
  [kanagawa-dark]="kanagawa-wave"
)

# Theme to wallpaper path mappings (relative to HOME)
declare -A THEME_WALLPAPERS=(
  [kanagawa-lotus]=".local/share/wallpapers/kanagawa-lotus.jpg"
  [kanagawa-wave]=".local/share/wallpapers/kanagawa-wave.png"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_DIR="$SCRIPT_DIR/../stow"

# Normalize theme name from input arguments
# Supports both "kanagawa-lotus" and "kanagawa light" formats
normalize_theme_name() {
  local arg1="$1"
  local arg2="${2:-}"

  if [[ -z "$arg2" ]]; then
    # Single argument: direct theme ID (e.g., "kanagawa-lotus")
    echo "$arg1"
  else
    # Two arguments: family + variant (e.g., "kanagawa light")
    local key="${arg1}-${arg2}"
    if [[ -n "${THEME_VARIANTS[$key]:-}" ]]; then
      echo "${THEME_VARIANTS[$key]}"
    else
      echo "Error: Unknown theme '$key'. Available themes:" >&2
      for theme in "${!THEME_VARIANTS[@]}"; do
        echo "  $theme -> ${THEME_VARIANTS[$theme]}" >&2
      done
      return 1
    fi
  fi
}

apply_theme() {
  local theme_name="$1"
  local package="$theme_name"
  local color_scheme_name="$theme_name"
  local konsole_scheme_name="$theme_name"
  local wallpaper_rel_path="${THEME_WALLPAPERS[$theme_name]:-}"
  local wallpaper_path=""
  local kwrite_theme_name
  kwrite_theme_name="$(printf '%s' "$theme_name" | awk -F'-' '{for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2)} 1 {print}')"

  if [[ -n "$wallpaper_rel_path" ]]; then
    wallpaper_path="$HOME/$wallpaper_rel_path"
  fi

  if ! command -v stow &> /dev/null; then
    echo "[theme] GNU Stow is not installed. Install it first and re-run this step." >&2
    return 1
  fi

  local package_dir="$STOW_DIR/$package"
  if [[ ! -d "$package_dir" ]]; then
    echo "[theme] Missing package directory: $package_dir" >&2
    return 1
  fi

  command stow --dir="$STOW_DIR" --target="$HOME" --restow "$package"
  echo "[theme] Applied package: $package"

  if command -v plasma-apply-colorscheme &> /dev/null; then
    echo "[theme] Applying colour scheme: $color_scheme_name"
    plasma-apply-colorscheme "$color_scheme_name"
  else
    echo "[theme] plasma-apply-colorscheme not found; apply '$color_scheme_name' manually in System Settings."
  fi

  if [[ -z "$wallpaper_path" ]]; then
    echo "[theme] No wallpaper mapping found for theme '$theme_name'; skipping wallpaper auto-apply."
  elif [[ ! -f "$wallpaper_path" ]]; then
    echo "[theme] Wallpaper file not found: $wallpaper_path"
  elif command -v plasma-apply-wallpaperimage &> /dev/null; then
    plasma-apply-wallpaperimage "$wallpaper_path"
    echo "[theme] Applied wallpaper: $wallpaper_path"
  else
    echo "[theme] plasma-apply-wallpaperimage not found; set wallpaper manually to '$wallpaper_path'."
  fi

  if [[ -f "$HOME/.config/konsolerc" ]]; then
    local default_profile
    default_profile="$(awk -F'=' '/^DefaultProfile=/{print $2; exit}' "$HOME/.config/konsolerc")"

    if [[ -n "$default_profile" ]]; then
      local profile_path="$HOME/.local/share/konsole/$default_profile"

      if command -v kwriteconfig6 &> /dev/null; then
        kwriteconfig6 --file "$profile_path" --group Appearance --key ColorScheme "$konsole_scheme_name"
        echo "[theme] Applied Konsole colour scheme '$konsole_scheme_name' to $default_profile"
      elif command -v kwriteconfig5 &> /dev/null; then
        kwriteconfig5 --file "$profile_path" --group Appearance --key ColorScheme "$konsole_scheme_name"
        echo "[theme] Applied Konsole colour scheme '$konsole_scheme_name' to $default_profile"
      else
        echo "[theme] kwriteconfig not found; set Konsole profile colour scheme to '$konsole_scheme_name' manually."
      fi
    else
      echo "[theme] Could not detect Konsole default profile; set '$konsole_scheme_name' manually in Konsole settings."
    fi
  else
    echo "[theme] Konsole config not found; skipping Konsole colour scheme auto-apply."
  fi

  if command -v kwriteconfig6 &> /dev/null; then
    kwriteconfig6 --file "$HOME/.config/kwriterc" --group "KTextEditor Renderer" --key "Auto Color Theme Selection" false
    kwriteconfig6 --file "$HOME/.config/kwriterc" --group "KTextEditor Renderer" --key "Color Theme" "$kwrite_theme_name"
    echo "[theme] Applied KWrite colour theme '$kwrite_theme_name'"
  elif command -v kwriteconfig5 &> /dev/null; then
    kwriteconfig5 --file "$HOME/.config/kwriterc" --group "KTextEditor Renderer" --key "Auto Color Theme Selection" false
    kwriteconfig5 --file "$HOME/.config/kwriterc" --group "KTextEditor Renderer" --key "Color Theme" "$kwrite_theme_name"
    echo "[theme] Applied KWrite colour theme '$kwrite_theme_name'"
  else
    echo "[theme] kwriteconfig not found; set KWrite Color Theme to '$kwrite_theme_name' manually."
  fi
}

usage() {
  cat <<EOF
Usage: $0 <theme> [variant]

Apply a theme to Plasma, Konsole, and KWrite.

Supported formats:
  $0 kanagawa-lotus          # Direct theme ID
  $0 kanagawa-wave
  $0 kanagawa light          # Family + variant
  $0 kanagawa dark

Available themes:
EOF
  for theme_key in "${!THEME_VARIANTS[@]}"; do
    printf "  %-20s -> %s\n" "$theme_key" "${THEME_VARIANTS[$theme_key]}"
  done
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

theme_name=$(normalize_theme_name "$@") || exit 1
apply_theme "$theme_name"
