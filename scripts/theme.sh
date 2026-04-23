#!/usr/bin/env bash

set -euo pipefail

# Theme family variant mappings
declare -A THEME_VARIANTS=(
  [kanagawa-light]="kanagawa-lotus"
  [kanagawa-dark]="kanagawa-wave"
)

# Default light/dark aliases
declare -A THEME_DEFAULT_ALIASES=(
  [light]="kanagawa-lotus"
  [dark]="kanagawa-wave"
)

# Current KDE scheme to opposite theme mappings
declare -A THEME_TOGGLES=(
  [kanagawa-lotus]="kanagawa-wave"
  [kanagawa-wave]="kanagawa-lotus"
)

# Theme to wallpaper path mappings (relative to HOME)
declare -A THEME_WALLPAPERS=(
  [kanagawa-lotus]=".local/share/wallpapers/kanagawa-lotus.jpg"
  [kanagawa-wave]=".local/share/wallpapers/kanagawa-wave.png"
)

# Theme to VS Code theme name mappings
declare -A THEME_VSCODE_THEMES=(
  [kanagawa-wave]="Kanagawa Wave"
  [kanagawa-lotus]="Kanagawa Lotus"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_DIR="$SCRIPT_DIR/../stow"

# Normalize theme name from input arguments
# Supports both "kanagawa-lotus" and "kanagawa light" formats
normalize_theme_name() {
  local arg1="$1"
  local arg2="${2:-}"

  if [[ -z "$arg2" ]]; then
    # Single argument: direct theme ID or alias (e.g., "kanagawa-lotus" or "dark")
    if [[ -n "${THEME_DEFAULT_ALIASES[$arg1]:-}" ]]; then
      echo "${THEME_DEFAULT_ALIASES[$arg1]}"
    else
      echo "$arg1"
    fi
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

get_active_kde_color_scheme() {
  local kdeglobals_path="$HOME/.config/kdeglobals"

  if [[ ! -f "$kdeglobals_path" ]]; then
    echo "Error: KDE globals file not found at '$kdeglobals_path'." >&2
    return 1
  fi

  awk -F'=' '
    $0 == "[General]" { in_general = 1; next }
    /^\[/ && $0 != "[General]" { in_general = 0 }
    in_general && $1 == "ColorScheme" {
      print $2
      exit
    }
  ' "$kdeglobals_path"
}

toggle_theme() {
  local active_theme
  active_theme="$(get_active_kde_color_scheme)" || return 1

  local next_theme="${THEME_TOGGLES[$active_theme]:-}"
  if [[ -z "$next_theme" ]]; then
    echo "Error: Active KDE color scheme '$active_theme' is not one of the supported Kanagawa themes." >&2
    echo "Supported schemes: ${!THEME_TOGGLES[*]}" >&2
    return 1
  fi

  apply_theme "$next_theme"
}

update_editor_theme_setting() {
  local settings_path="$1"
  local editor_name="$2"
  local vscode_theme_name="$3"

  if [[ ! -f "$settings_path" ]]; then
    return 0
  fi

  local tmp_path
  tmp_path="$(mktemp)"

  if ! THEME_NAME="$vscode_theme_name" perl -0777 -pe '
      my $theme = $ENV{THEME_NAME};
      my $scan = $_;

      # Remove comments only for matching checks.
      $scan =~ s{\/\*.*?\*\/}{}gs;
      $scan =~ s{^\s*//.*$}{}gm;

      if ($scan =~ /"window\.autoDetectColorScheme"\s*:\s*true\b/) {
        # Auto-detect explicitly enabled: keep file unchanged.
        print STDERR "AUTO_DETECT_ON\n";
        $_ = $_;
        next;
      }

      my $theme_escaped = $theme;
      $theme_escaped =~ s/([\\"])/\\$1/g;

      if ($_ =~ /"workbench\.colorTheme"\s*:\s*"(?:\\.|[^"\\])*"/) {
        s/("workbench\.colorTheme"\s*:\s*")((?:\\.|[^"\\])*)(")/${1}${theme_escaped}${3}/;
      } else {
        if ($_ =~ /^\s*\{\s*\}\s*$/s) {
          $_ = "{\n  \"workbench.colorTheme\": \"$theme_escaped\",\n}\n";
        } else {
          my $insert = "\n  \"workbench.colorTheme\": \"$theme_escaped\",";
          s/(\s*}\s*$)/$insert$1/s;
        }
      }
    ' "$settings_path" > "$tmp_path" 2>"$tmp_path.stderr"; then
    rm -f "$tmp_path" "$tmp_path.stderr"
    echo "[theme] Could not process '$settings_path'; skipping $editor_name settings update."
    return 0
  fi

  if grep -q '^AUTO_DETECT_ON$' "$tmp_path.stderr"; then
    rm -f "$tmp_path" "$tmp_path.stderr"
    echo "[theme] $editor_name settings unchanged (auto-detect enabled)."
    return 0
  fi

  rm -f "$tmp_path.stderr"

  if cmp -s "$settings_path" "$tmp_path"; then
    rm -f "$tmp_path"
    echo "[theme] $editor_name settings unchanged (theme already set)."
    return 0
  fi

  mv "$tmp_path" "$settings_path"
  echo "[theme] Set $editor_name workbench.colorTheme to '$vscode_theme_name'."
}

apply_theme() {
  local theme_name="$1"
  local package="$theme_name"
  local color_scheme_name="$theme_name"
  local konsole_scheme_name="$theme_name"
  local vscode_theme_name="${THEME_VSCODE_THEMES[$theme_name]:-}"
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

  if [[ -z "$vscode_theme_name" ]]; then
    echo "[theme] No VS Code theme mapping found for '$theme_name'; skipping VS Code and Cursor updates."
  else
    update_editor_theme_setting "$HOME/.config/Code/User/settings.json" "VS Code" "$vscode_theme_name"
    update_editor_theme_setting "$HOME/.config/Cursor/User/settings.json" "Cursor" "$vscode_theme_name"
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
  $0 light                   # Alias -> kanagawa-lotus
  $0 dark                    # Alias -> kanagawa-wave
  $0 toggle                  # Switch between kanagawa-lotus and kanagawa-wave

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

if [[ "$1" == "toggle" ]]; then
  if [[ $# -ne 1 ]]; then
    echo "Error: 'toggle' does not take additional arguments." >&2
    exit 1
  fi

  toggle_theme
  exit $?
fi

theme_name=$(normalize_theme_name "$@") || exit 1
apply_theme "$theme_name"
