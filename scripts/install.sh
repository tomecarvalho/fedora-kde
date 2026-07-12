#!/usr/bin/env bash

OH_MY_ZSH_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh"

BLEX_MONO_NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/IBMPlexMono.zip"

US_PT_KEYBOARD_LAYOUT_GITHUB_SUFFIX="tomecarvalho/us-pt-keyboard-layout.git"

VIDEOS_DIR="$HOME/Videos"
SHOWS_DIR="$VIDEOS_DIR/shows"
MOVIES_DIR="$VIDEOS_DIR/movies"
JELLYFIN_MEDIA_DIR="/mnt/media"
JELLYFIN_SHOWS_DIR="$JELLYFIN_MEDIA_DIR/shows"
JELLYFIN_MOVIES_DIR="$JELLYFIN_MEDIA_DIR/movies"

set -euo pipefail

# Default, ordered list of descriptive step names
ALL_STEPS=(
  dnf_up
  rpm_fusion
  repos
  copr
  dnf_install
  dnf_uninstall
  flatpak_install
  snap_install
  codecs
  ca_bundle_symlink
  pipx_install
  vscode
  node
  cursor
  oh_my_zsh
  oh_my_zsh_plugins
  starship
  docker
  snapper
  blex_mono_nerd_font
  blex_mono_nerd_font_as_monospace
  aliases
  jellyfin
  stow_apply
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIASES_DIR="$SCRIPT_DIR/../aliases"
PKGS_DIR="$SCRIPT_DIR/../packages"
GENERAL_PKGS_DIR="$PKGS_DIR/general"
REMOVE_PKGS_DIR="$PKGS_DIR/remove"
STOW_DIR="$SCRIPT_DIR/../stow"

VIDEOS_DIR="$HOME/Videos"
SHOWS_DIR="$VIDEOS_DIR/shows"
MOVIES_DIR="$VIDEOS_DIR/movies"
JELLYFIN_MEDIA_DIR="/mnt/media"
JELLYFIN_SHOWS_DIR="$JELLYFIN_MEDIA_DIR/shows"
JELLYFIN_MOVIES_DIR="$JELLYFIN_MEDIA_DIR/movies"

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

repos() {
  echo "[repos] Enable additional repositories"

  local repos_file="$GENERAL_PKGS_DIR/repos.txt"
  local repos=($(util_read_package_list "$repos_file"))

  if [[ ${#repos[@]} -eq 0 ]]; then
    echo "[repos] No additional repositories to enable"
    return
  fi

  echo "[repos] Enabling ${#repos[@]} additional repository(ies)..."
  for repo in "${repos[@]}"; do
    sudo dnf config-manager addrepo --from-repofile="$repo"
  done
}

copr() {
  echo "[copr] Enable COPR repositories"
  
  local copr_file="$GENERAL_PKGS_DIR/copr.txt"
  local repos=($(util_read_package_list "$copr_file"))

  if [[ ${#repos[@]} -eq 0 ]]; then
    echo "[copr] No COPR repositories to enable"
    return
  fi

  echo "[copr] Enabling ${#repos[@]} COPR repository(ies)..."

  for repo in "${repos[@]}"; do
    sudo dnf copr enable -y "$repo"
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

  local prefix="[codecs]"
  
  echo "$prefix Switch to full ffmpeg"
  sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing

  echo "$prefix Install additional codecs"
  sudo dnf up -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin

  echo "$prefix Install packages for DVD"
  sudo dnf in -y rpmfusion-free-release-tainted
  sudo dnf in -y libdvdcss

  echo "$prefix Install various firmwares from nonfree tainted"
  sudo dnf in -y rpmfusion-nonfree-release-tainted
  sudo dnf --repo=rpmfusion-nonfree-tainted in -y "*-firmware"

  # Fix H265/E-AC-3 unable to be played by deleting GStreamer cache.
  # See: https://discussion.fedoraproject.org/t/how-to-play-h265-videos-and-e-ac-3-audio/146600/7
  echo "$prefix Delete GStreamer registry cache to fix H265/E-AC-3 playback"
  rm ~/.cache/gstreamer-1.0/registry.x86_64.bin
}

# Symlink the system CA bundle to the location expected by some tools, if not already set up.
ca_bundle_symlink() {
  local prefix="[ca_bundle_symlink]"

  echo "$prefix Set up /etc/pki/tls/certs/ca-bundle.crt symlink"

  local target="/etc/pki/tls/certs/ca-bundle.crt"
  local source="/etc/ssl/certs/ca-bundle.crt"

  # If target already exists, exit.
  if [[ -e "$target" ]]; then
    echo "$prefix $target already exists, skipping symlink setup"
    return
  fi

  # If source doesn't exist, warn and exit.
  if [[ ! -e "$source" ]]; then
    echo "$prefix Warning: source CA bundle not found at $source. Cannot create symlink at $target." >&2
    return 1
  fi

  sudo ln -s "$source" "$target"

  echo "$prefix Created symlink from $source to $target"
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
  local packages=($(util_read_package_list "$pkg_file"))

  if [[ ${#packages[@]} -eq 0 ]]; then
    echo "[snap_install] No packages to install"
    return
  fi

  echo "[snap_install] Enabling snapd service..."
  sudo systemctl enable --now snapd.socket
  sudo ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true

  echo "[snap_install] Waiting for snapd socket to become ready..."
  local retries=50
  until systemctl is-active --quiet snapd.socket; do
    if [[ $retries -le 0 ]]; then
      echo "[snap_install] snapd.socket did not become ready in time" >&2
      return 1
    fi

    sleep 0.1
    ((retries--))
  done

  echo "[snap_install] Installing ${#packages[@]} package(s) with snap..."
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

blex_mono_nerd_font() {
  echo "[blex_mono_nerd_font] Install Blex Mono Nerd Font"

  local font_name="BlexMonoNerdFont"
  local font_dir="/usr/local/share/fonts/$font_name"

  if fc-list | grep -q "$font_name"; then
    echo "[blex_mono_nerd_font] $font_name is already installed"
    return
  fi

  # Create the font directory, if needed
  sudo mkdir -p "$font_dir"

  # Download into a temporary ZIP file, unzip into the font directory, and clean up
  local tmp_zip
  tmp_zip="$(mktemp --suffix=.zip)"
  curl -L -o "$tmp_zip" "$BLEX_MONO_NERD_FONT_URL"
  sudo unzip -o "$tmp_zip" -d "$font_dir"
  rm -f "$tmp_zip"

  # Update font cache
  sudo fc-cache -fv

  echo "[blex_mono_nerd_font] Installed $font_name to $font_dir"
}

blex_mono_nerd_font_as_monospace() {
  echo "[blex_mono_nerd_font_as_monospace] Set Blex Mono Nerd Font Mono as the monospace font system-wide"

  mkdir -p ~/.config/fontconfig/conf.d

  local font_name="BlexMono Nerd Font Mono"

  cat > ~/.config/fontconfig/conf.d/99-monospace-blex-mono-nerd-font-mono.conf <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>${font_name}</family>
    </prefer>
  </alias>
</fontconfig>
EOF

  sudo fc-cache -fv

  echo "[blex_mono_nerd_font_as_monospace] Set ${font_name} as the monospace font"
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

jellyfin() {
  echo "[jellyfin] Set up Jellyfin media server"

  # Create user "shows" and "movies" directories in Videos, if needed
  mkdir -p "$SHOWS_DIR"
  mkdir -p "$MOVIES_DIR"

  # Create directories for Jellyfin media
  sudo mkdir -p "$JELLYFIN_SHOWS_DIR"
  sudo mkdir -p "$JELLYFIN_MOVIES_DIR"

  # Ensure fstab entries exist (bind mounts)
  FSTAB_LINE_SHOWS="$SHOWS_DIR $JELLYFIN_SHOWS_DIR none bind 0 0"
  FSTAB_LINE_MOVIES="$MOVIES_DIR $JELLYFIN_MOVIES_DIR none bind 0 0"

  grep -qsF "$FSTAB_LINE_SHOWS" /etc/fstab || \
    echo "$FSTAB_LINE_SHOWS" | sudo tee -a /etc/fstab

  grep -qsF "$FSTAB_LINE_MOVIES" /etc/fstab || \
    echo "$FSTAB_LINE_MOVIES" | sudo tee -a /etc/fstab

  # Mount everything from fstab (applies immediately)
  sudo mount -a

  # Give jellyfin user read + traverse access via ACL (cleaner than chmod o+x)
  if id jellyfin &>/dev/null; then
    sudo setfacl -R -m u:jellyfin:rx "$SHOWS_DIR" "$MOVIES_DIR"
    sudo setfacl -m u:jellyfin:x "$VIDEOS_DIR" "$HOME"
  else
    echo "[jellyfin] Warning: jellyfin user not found, skipping ACL setup"
  fi

  echo "[jellyfin] Done"
}

stow_apply() {
  local prefix="[stow_apply]"

  echo "$prefix Symlink stow-managed dotfiles to home directory"

  local stow_bin
  stow_bin="$(type -P stow || true)"

  if [[ -z "$stow_bin" ]]; then
    echo "$prefix GNU Stow is not installed. Install it first and re-run this step." >&2
    return
  fi

  if [[ ! -d "$STOW_DIR" ]]; then
    echo "$prefix Stow directory not found at $STOW_DIR" >&2
    return 1
  fi

  local -a packages=()
  local package

  while IFS= read -r package; do
    [[ -n "$package" ]] && packages+=("$package")
  done < <(find "$STOW_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

  if [[ ${#packages[@]} -eq 0 ]]; then
    echo "$prefix No stow packages found in $STOW_DIR"
    return
  fi

  echo "$prefix Stowing ${#packages[@]} package(s) from $STOW_DIR into $HOME"

  for package in "${packages[@]}"; do
    local package_target="$HOME"

    if [[ "$package" == .* ]]; then
      package_target="$HOME/$package"
    fi

    echo "$prefix Stowing package: $package"
    "$stow_bin" --restow --dir "$STOW_DIR" --target "$package_target" "$package"
  done
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