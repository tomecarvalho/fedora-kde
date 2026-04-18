#!/usr/bin/env bash

OH_MY_ZSH_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh"

IBM_PLEX_MONO_NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/IBMPlexMono.zip"

US_PT_KEYBOARD_LAYOUT_GITHUB_SUFFIX="tomecarvalho/us-pt-keyboard-layout.git"

set -euo pipefail

# Default, ordered list of descriptive step names
ALL_STEPS=(
  dnf_up
  rpm_fusion
  copr
  dnf_install
  dnf_uninstall
  flatpak_install
  snap_install
  pipx_install
  vscode
  node
  cursor
  oh_my_zsh
  oh_my_zsh_plugins
  starship
  docker
  snapper
  ibm_plex_mono_nerd_font
  ibm_plex_mono_nerd_font_as_monospace
  ibm_plex_sans_as_sans_serif
  aliases
  stow
  apply_kanagawa_wave
  apply_kanagawa_lotus
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIASES_DIR="$SCRIPT_DIR/../aliases"
PKGS_DIR="$SCRIPT_DIR/../packages"
GENERAL_PKGS_DIR="$PKGS_DIR/general"
REMOVE_PKGS_DIR="$PKGS_DIR/remove"
STOW_DIR="$SCRIPT_DIR/../stow"

source "$SCRIPT_DIR/utils.sh"

dnf_up() {
  echo "[dnf_up] Update packages"
  sudo dnf up -y --refresh
}

rpm_fusion() {
  echo "[rpm_fusion] Enable RPM Fusion Free and Nonfree"


  local fedora_version
  fedora_version="$(rpm -E %fedora)"

  sudo dnf in -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$fedora_version.noarch.rpm
  sudo dnf in -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$fedora_version.noarch.rpm
}

copr() {
  echo "[copr] Enable COPR repositories"
  
  local copr_file="$GENERAL_PKGS_DIR/copr.txt"
  local repos=($(read_package_list "$copr_file"))

  echo "[copr] Enabling ${#repos[@]} COPR repository(ies)..."

  for repo in "${repos[@]}"; do
    sudo dnf copr enable -y "$repo"
  done
}

repofiles() {
  echo "[repofiles] Enable repositories from repofiles"

  local repos_file="$GENERAL_PKGS_DIR/repofiles.txt"
  local repos=($(read_package_list "$repos_file"))

  echo "[repofiles] Enabling ${#repos[@]} additional repository(ies)..."

  for repo in "${repos[@]}"; do
    sudo dnf config-manager addrepo --from-repofile="$repo"
  done
}

dnf_install() {
  echo "[dnf_install] Install DNF packages"
  
  local pkg_file="$GENERAL_PKGS_DIR/dnf.txt"
  local packages=($(read_package_list "$pkg_file"))

  echo "[dnf_install] Installing ${#packages[@]} packages with dnf..."
  sudo dnf in -y "${packages[@]}"
}

dnf_uninstall() {
  echo "[dnf_uninstall] Uninstall unnecessary DNF packages"

  local pkg_file="$REMOVE_PKGS_DIR/dnf.txt"
  local packages=($(read_package_list "$pkg_file"))

  if [[ ${#packages[@]} -eq 0 ]]; then
    echo "[dnf_uninstall] No packages to uninstall"
    return
  fi

  echo "[dnf_uninstall] Uninstalling ${#packages[@]} packages with dnf..."
  sudo dnf rm -y "${packages[@]}"
}

codecs() {
  # https://rpmfusion.org/Howto/Multimedia
  echo "[codecs] Switch to full ffmpeg"
  sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing

  echo "[codecs] Install additional multimedia codecs"
  sudo dnf up -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin

  echo "[codecs] Enable RPM Fusion Free Tainted and install package for DVD"
  sudo dnf in -y rpmfusion-free-release-tainted
  sudo dnf in -y libdvdcss

  echo "[codecs] Enable RPM Fusion Non-free Tainted and install various firmwares"
  sudo dnf in -y rpmfusion-nonfree-release-tainted
  sudo dnf --repo=rpmfusion-nonfree-tainted in -y "*-firmware"
}

flatpak_install() {
  echo "[flatpak_install] Enable Flathub"
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo  

  echo "[flatpak_install] Install Flatpak packages"

  local pkg_file="$GENERAL_PKGS_DIR/flatpak.txt"
  local packages=($(read_package_list "$pkg_file"))

  if [[ ${#packages[@]} -eq 0 ]]; then
    echo "[flatpak_install] No packages to install"
    return
  fi

  echo "[flatpak_install] Installing ${#packages[@]} packages with flatpak..."
  for package in "${packages[@]}"; do
    flatpak install -y flathub "$package"
  done
}

snap_install() {
  echo "[snap_install] Install Snap packages"

  local pkg_file="$GENERAL_PKGS_DIR/snap.txt"
  local packages=($(read_package_list "$pkg_file"))

  if [[ ${#packages[@]} -eq 0 ]]; then
    echo "[snap_install] No packages to install"
    return
  fi

  echo "[snap_install] Enabling snapd service..."
  sudo systemctl enable --now snapd.socket
  sudo ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true

  echo "[snap_install] Installing ${#packages[@]} packages with snap..."
  for package in "${packages[@]}"; do
    sudo snap install "$package"
  done
}

pipx_install() {
  echo "[pipx_install] Ensure pipx is in PATH"
  pipx ensurepath

  local pkg_file="$GENERAL_PKGS_DIR/pipx.txt"
  local packages=($(read_package_list "$pkg_file"))

  if [[ ${#packages[@]} -eq 0 ]]; then
    echo "[pipx_install] No packages to install"
    return
  fi

  echo "[pipx_install] Installing ${#packages[@]} package(s) with pipx..."
  for package in "${packages[@]}"; do
    pipx install "$package"
  done
}

vscode() {
  if command -v code &> /dev/null; then
    echo "[vscode] VS Code is already installed"
    return
  fi

  echo "[vscode] Add VS Code repository and install Code"
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
  echo "[vscode] Install VS Code"
  sudo dnf in -y code
}

oh_my_zsh() {
  echo "[oh_my_zsh] Install oh-my-zsh"

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    echo "oh-my-zsh is already installed at $HOME/.oh-my-zsh"
  else
    sh -c "$(curl -fsSL $OH_MY_ZSH_INSTALL_URL)"
  fi
}

oh_my_zsh_plugins() {
  local plugins="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"

  echo "[oh_my_zsh_plugins] Install zsh-nvm"
  git clone https://github.com/lukechilds/zsh-nvm "$plugins/zsh-nvm"

  echo "[oh_my_zsh_plugins] Install zsh-autosuggestions"
  git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins/zsh-autosuggestions"
}

starship() {
  echo "[starship] Install starship prompt"

  if ! command -v starship &> /dev/null; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y
  fi
}

node() {
  echo "[node] Removing Node packages and installing NVM, PNPM"
  sudo dnf remove -y nodejs nodejs-docs nodejs-full-i18n nodejs-npm

  # Install NVM if not already installed in ~/.nvm
  if [[ -d "$HOME/.nvm" ]]; then
    echo "[node] NVM is already installed"
  else
    echo "[node] Installing NVM"
    curl -o- "$NVM_INSTALL_URL" | bash
  fi

  # Load NVM
  local nvm_dir="$HOME/.nvm"
  [ -s "$nvm_dir/nvm.sh" ] && \. "$nvm_dir/nvm.sh"

  echo "[node] Installing latest LTS version of Node via NVM"
  nvm install --lts

  echo "[node] Setting LTS as default Node version"
  nvm use --lts
  nvm alias default node

  echo "[node] Installing PNPM globally via NPM"
  npm install -g pnpm

  echo "[node] Set up PNPM global packages directory"
  pnpm setup
}

cursor() {
  echo "[cursor] Add Cursor repository"
  sudo tee /etc/yum.repos.d/cursor.repo << 'EOF'
[cursor]
name=Cursor
baseurl=https://downloads.cursor.com/yumrepo
enabled=1
gpgcheck=1
gpgkey=https://downloads.cursor.com/keys/anysphere.asc
EOF
  
  echo "[cursor] Install Cursor"
  sudo dnf in -y cursor
}

docker() {
  echo "[docker] Install Docker Engine and configure user permissions"

  sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
  sudo dnf in -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl start docker
  sudo groupadd docker
  sudo usermod -aG docker $USER
}

snapper() {
  echo "[snapper] Configure snapper for Btrfs snapshots"

  # Create a snapper config for the root filesystem
  if sudo snapper list | grep -q "^root[[:space:]]"; then
    echo "[snapper] Snapper config for root already exists"
  else
    echo "[snapper] Creating snapper config for root"
    sudo snapper -c root create-config /
  fi

  # Set up automatic snapshots via systemd timers
  echo "[snapper] Enabling snapper-timeline.timer and snapper-cleanup.timer"
  sudo systemctl enable --now snapper-timeline.timer
  sudo systemctl enable --now snapper-cleanup.timer
}

ibm_plex_mono_nerd_font() {
  echo "[ibm_plex_mono_nerd_font] Install IBM Plex Mono Nerd Font"

  local font_name="IBMPlexMonoNerdFont"
  local font_dir="/usr/local/share/fonts/$font_name"

  local matched_mono_family
  matched_mono_family="$(fc-match -f '%{family}\n' 'IBM Plex Mono Nerd Font' 2>/dev/null || true)"
  if [[ "${matched_mono_family,,}" == *"ibm plex mono nerd font"* ]]; then
    echo "$font_name is already installed"
    return
  fi

  # Create the font directory, if needed
  sudo mkdir -p "$font_dir"

  # Download into a temporary ZIP file, unzip, and clean up the temp file
  local tmp_zip
  tmp_zip="$(mktemp --suffix=.zip)"
  curl -L -o "$tmp_zip" "$IBM_PLEX_MONO_NERD_FONT_URL"
  sudo unzip -o "$tmp_zip" -d "$font_dir"
  rm "$tmp_zip"

  # Update font cache
  sudo fc-cache -fv

  echo "[ibm_plex_mono_nerd_font] Installed $font_name to $font_dir"
}

ibm_plex_mono_nerd_font_as_monospace() {
  echo "[ibm_plex_mono_nerd_font_as_monospace] Set IBM Plex Mono Nerd Font as the monospace font system-wide"

  mkdir -p ~/.config/fontconfig/conf.d

  cat > ~/.config/fontconfig/conf.d/99-monospace-ibm-plex-mono.conf <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>Blex Mono Nerd Font Mono</family>
    </prefer>
  </alias>
</fontconfig>
EOF

  sudo fc-cache -fv

  echo "[ibm_plex_mono_nerd_font_as_monospace] Set IBM Plex Mono Nerd Font Mono as the monospace font"
}

ibm_plex_sans_as_sans_serif() {
  echo "[ibm_plex_sans_as_sans_serif] Set IBM Plex Sans as the sans-serif font system-wide"

  local matched_sans_family
  matched_sans_family="$(fc-match -f '%{family}\n' 'IBM Plex Sans' 2>/dev/null || true)"
  if [[ "${matched_sans_family,,}" != *"ibm plex sans"* ]]; then
    echo "[ibm_plex_sans_as_sans_serif] IBM Plex Sans is not installed. Please install it manually first and re-run this step."
    echo "You can download it from https://fonts.google.com/specimen/IBM+Plex+Sans"
    return
  fi

  mkdir -p ~/.config/fontconfig/conf.d

  cat > ~/.config/fontconfig/conf.d/99-sans-serif-ibm-plex-sans.conf <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>IBM Plex Sans</family>
    </prefer>
  </alias>
</fontconfig>
EOF

  sudo fc-cache -fv

  echo "[ibm_plex_sans_as_sans_serif] Set IBM Plex Sans as the sans-serif font"
}

aliases() {
  echo "[aliases] Symlink aliases/.aliases to ~/.aliases"

  local target="$HOME/.aliases"
  local source="$ALIASES_DIR/.aliases"

  if [[ -L "$target" ]]; then
    if [[ "$(readlink "$target")" == "$source" ]]; then
      echo "[aliases] Alias file is already correctly symlinked"
      return
    else
      echo "[aliases] Alias file is a symlink to the wrong location. Removing."
      rm "$target"
    fi
  elif [[ -e "$target" ]]; then
    echo "[aliases] Alias file already exists and is not a symlink. Please remove or rename $target and re-run this step."
    return
  fi

  ln -s "$source" "$target"
  echo "[aliases] Symlinked $source to $target"
}

stow() {
  echo "[stow] Restow all Kanagawa packages via GNU Stow"

  if ! command -v stow &> /dev/null; then
    echo "[stow] GNU Stow is not installed. Install it first and re-run this step." >&2
    return
  fi

  local package
  for package in kanagawa-wave kanagawa-lotus; do
    local package_dir="$STOW_DIR/$package"
    if [[ ! -d "$package_dir" ]]; then
      echo "[stow] Missing package directory: $package_dir" >&2
      continue
    fi

    command stow --dir="$STOW_DIR" --target="$HOME" --restow "$package"
    echo "[stow] Applied package: $package"
  done
}

apply_kanagawa_theme() {
  local theme_name="$1"
  local package="$theme_name"
  local color_scheme_name="$theme_name"
  local konsole_scheme_name="$theme_name"
  local kwrite_theme_name
  kwrite_theme_name="$(printf '%s' "$theme_name" | awk -F'-' '{for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2)} 1 {print}')"

  if ! command -v stow &> /dev/null; then
    echo "[apply_kanagawa_theme] GNU Stow is not installed. Install it first and re-run this step." >&2
    return
  fi

  local package_dir="$STOW_DIR/$package"
  if [[ ! -d "$package_dir" ]]; then
    echo "[apply_kanagawa_theme] Missing package directory: $package_dir" >&2
    return
  fi

  command stow --dir="$STOW_DIR" --target="$HOME" --restow "$package"
  echo "[apply_kanagawa_theme] Applied package: $package"

  if command -v plasma-apply-colorscheme &> /dev/null; then
    echo "[apply_kanagawa_theme] Applying colour scheme: $color_scheme_name"
    plasma-apply-colorscheme "$color_scheme_name"
  else
    echo "[apply_kanagawa_theme] plasma-apply-colorscheme not found; apply '$color_scheme_name' manually in System Settings."
  fi

  if [[ -f "$HOME/.config/konsolerc" ]]; then
    local default_profile
    default_profile="$(awk -F'=' '/^DefaultProfile=/{print $2; exit}' "$HOME/.config/konsolerc")"

    if [[ -n "$default_profile" ]]; then
      local profile_path="$HOME/.local/share/konsole/$default_profile"

      if command -v kwriteconfig6 &> /dev/null; then
        kwriteconfig6 --file "$profile_path" --group Appearance --key ColorScheme "$konsole_scheme_name"
        echo "[apply_kanagawa_theme] Applied Konsole colour scheme '$konsole_scheme_name' to $default_profile"
      elif command -v kwriteconfig5 &> /dev/null; then
        kwriteconfig5 --file "$profile_path" --group Appearance --key ColorScheme "$konsole_scheme_name"
        echo "[apply_kanagawa_theme] Applied Konsole colour scheme '$konsole_scheme_name' to $default_profile"
      else
        echo "[apply_kanagawa_theme] kwriteconfig not found; set Konsole profile colour scheme to '$konsole_scheme_name' manually."
      fi
    else
      echo "[apply_kanagawa_theme] Could not detect Konsole default profile; set '$konsole_scheme_name' manually in Konsole settings."
    fi
  else
    echo "[apply_kanagawa_theme] Konsole config not found; skipping Konsole colour scheme auto-apply."
  fi

  if command -v kwriteconfig6 &> /dev/null; then
    kwriteconfig6 --file "$HOME/.config/kwriterc" --group "KTextEditor Renderer" --key "Auto Color Theme Selection" false
    kwriteconfig6 --file "$HOME/.config/kwriterc" --group "KTextEditor Renderer" --key "Color Theme" "$kwrite_theme_name"
    echo "[apply_kanagawa_theme] Applied KWrite colour theme '$kwrite_theme_name'"
  elif command -v kwriteconfig5 &> /dev/null; then
    kwriteconfig5 --file "$HOME/.config/kwriterc" --group "KTextEditor Renderer" --key "Auto Color Theme Selection" false
    kwriteconfig5 --file "$HOME/.config/kwriterc" --group "KTextEditor Renderer" --key "Color Theme" "$kwrite_theme_name"
    echo "[apply_kanagawa_theme] Applied KWrite colour theme '$kwrite_theme_name'"
  else
    echo "[apply_kanagawa_theme] kwriteconfig not found; set KWrite Color Theme to '$kwrite_theme_name' manually."
  fi
}

apply_kanagawa_wave() {
  echo "[apply_kanagawa_wave] Apply Kanagawa Wave to Plasma, Konsole and KWrite"
  apply_kanagawa_theme "kanagawa-wave"
}

apply_kanagawa_lotus() {
  echo "[apply_kanagawa_lotus] Apply Kanagawa Lotus to Plasma, Konsole and KWrite"
  apply_kanagawa_theme "kanagawa-lotus"
}

us_pt_keyboard_layout() {
  echo "[us_pt_keyboard_layout] Install the us-pt keyboard layout"

  # Check if us-pt-keyboard-layout is cloned in home
  local layout_dir="$HOME/us-pt-keyboard-layout"

  # If not cloned, attempt cloning via SSH, or, as a fallback, via HTTPS
  if [[ ! -d "$layout_dir" ]]; then
    echo "[us_pt_keyboard_layout] Attempting to clone us-pt-keyboard-layout via SSH..."

    if ! git clone "git@github.com:$US_PT_KEYBOARD_LAYOUT_GITHUB_SUFFIX" "$layout_dir"; then
      echo "[us_pt_keyboard_layout] Failed to clone via SSH. Attempting via HTTPS..."

      if ! git clone "https://github.com/$US_PT_KEYBOARD_LAYOUT_GITHUB_SUFFIX" "$layout_dir"; then
        echo "[us_pt_keyboard_layout] Failed to clone us-pt-keyboard-layout via HTTPS."
        return
      fi
    fi
  fi

  local install="$layout_dir/linux/install.sh"

  # Run the install script
  if [[ -f "$install" ]]; then
    echo "[us_pt_keyboard_layout] Running install script at $install"
    sudo bash "$install"
  else
    echo "[us_pt_keyboard_layout] Install script not found at $layout_dir/install.sh"
  fi
}

usage() {
  cat <<EOF
Usage: $0 [-s "step1,step2" | -s "name1,name2"] [-l]

Options:
  -s, --steps   Comma-separated list of steps to run. Accepts either descriptive names or (deprecated) numbers.
                Steps run in the default order; duplicates are ignored.
                Examples: -s "dnf_up" or -s "2,3"
  -l, --list    List all available steps in order.
  -h, --help    Show this help message.

Available steps (in order):
$(
  i=1
  for name in "${ALL_STEPS[@]}"; do
    printf "  %2d) %s\n" "$i" "$name"
    ((i++))
  done
)
EOF
}

# Parse args
STEPS_ARG=""
LIST_ONLY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--steps)
      if [[ -n "${2-}" ]]; then
        STEPS_ARG="$2"
        shift 2
        continue
      else
        echo "Error: --steps requires an argument" >&2
        usage
        exit 2
      fi
      ;;
    -l|--list)
      LIST_ONLY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "$LIST_ONLY" == true ]]; then
  usage
  exit 0
fi

# Build ordered list of steps to run (names)
declare -a RUN_STEPS=()
if [[ -z "$STEPS_ARG" ]]; then
  RUN_STEPS=("${ALL_STEPS[@]}")
else
  declare -A requested=()
  IFS=',' read -ra raw <<< "$STEPS_ARG"
  for token in "${raw[@]}"; do
    # trim whitespace
    step=$(echo "$token" | xargs)
    if [[ -z "$step" ]]; then
      continue
    fi
    if [[ "$step" =~ ^[0-9]+$ ]]; then
      idx=$((10#$step))
      if (( idx < 1 || idx > ${#ALL_STEPS[@]} )); then
        echo "Invalid step number: $step" >&2
        exit 2
      fi
      name="${ALL_STEPS[$((idx-1))]}"
      requested["$name"]=1
    else
      # Validate name is in ALL_STEPS
      valid=false
      for name in "${ALL_STEPS[@]}"; do
        if [[ "$name" == "$step" ]]; then
          valid=true
          requested["$name"]=1
          break
        fi
      done
      if [[ "$valid" != true ]]; then
        echo "Invalid step name: $step" >&2
        exit 2
      fi
    fi
  done
  # Maintain default order and dedupe
  for name in "${ALL_STEPS[@]}"; do
    if [[ -n "${requested[$name]+x}" ]]; then
      RUN_STEPS+=("$name")
    fi
  done
fi

# Dispatch by name with validation
for s in "${RUN_STEPS[@]}"; do
  if declare -F "$s" > /dev/null; then
    "$s"
  else
    echo "Unknown step function: $s" >&2
    exit 3
  fi
done