# fedora-kde

Configuration and post-install scripts for [Fedora Linux KDE Plasma Desktop Edition](https://fedoraproject.org/kde/). Initial version: 43.

## Aliases

Public aliases reside in [aliases/.aliases](aliases/.aliases) and are meant to be sourced from shell configs.

| Alias          | Command                                                    | Description                                                                               |
| -------------- | ---------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `cb`           | `wl-copy`                                                  | Copy text to the clipboard from the terminal.                                             |
| `cursor`       | `/usr/bin/cursor --no-sandbox`                             | Allows launching Cursor to edit a file by running `cursor filename`.                      |
| `docker-start` | `sudo systemctl start docker`                              | Start the Docker service.                                                                 |
| `docker-stop`  | `sudo systemctl stop docker`                               | Stop the Docker service.                                                                  |
| `update`       | `sudo dnf up -y && flatpak update -y && sudo snap refresh` | Update system packages, Flatpaks, and Snap packages.                                      |
| `konsave-push` | `scripts/konsave-push.sh`                                  | Save the current Plasma config, export it, commit the updated `config.knsv`, and push it. |
| `konsave-pull` | `scripts/konsave-pull.sh`                                  | Fetch the tracked Plasma config, import `config.knsv`, and apply it.                      |

## Autostart Scripts

Autostart helpers reside in [autostart/](autostart/). They are intended for scripts that should run automatically when Plasma starts (defined in _System Settings > Autostart_).

| Script                                    | Description                                                                     |
| ----------------------------------------- | ------------------------------------------------------------------------------- |
| [add-ssh-keys](autostart/add-ssh-keys.sh) | Adds matching SSH private keys to the agent when a matching `.pub` file exists. |

## Konsave

[Konsave](https://github.com/Prayag2/konsave) is a useful utility that saves Plasma configurations as `knsv` files, eliminating the need to manually recreate the user's desired configuration through the GUI. Unfortunately, due to Plasma's limitations, configuration files are binary, not plaintext.

The versioned Plasma configuration resides in [konsave/config.knsv](konsave/config.knsv).

Helper scripts are available and aliased to conveniently update the versioned configuration, or fetch and apply it. See the _Scripts_ section below.

## Packages

Package lists contain system packages (DNF), Flatpaks and Snaps.

| Package List                           | Description                                                   |
| -------------------------------------- | ------------------------------------------------------------- |
| [packages/general/](packages/general/) | General packages to install on any Fedora KDE Plasma machine. |
| [packages/work/](packages/work/)       | Packages that are only necessary for work.                    |
| [packages/remove/](packages/remove/)   | Bloat to remove from a standard installation.                 |

## Scripts

| Script                                        | Description                                                                                                     |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| [install](scripts/install.sh)                 | General installation script. Supports step parameter to run specific steps in isolation.                        |
| [install-work](scripts/install-work.sh)       | Work-specific installation script. Supports step parameter to run specific steps in isolation.                  |
| [konsave-push](scripts/konsave-push.sh)       | Exports the current Plasma config, commits the updated `config.knsv`, and pushes it. Aliased to `konsave-push`. |
| [konsave-pull](scripts/konsave-pull.sh)       | Imports the tracked `config.knsv` and applies it. Aliased to `konsave-pull`.                                    |
| [nvidia-drivers](scripts/nvidia-drivers.sh)   | Helps set up NVIDIA GPU drivers.                                                                                |
| [secure-boot-key](scripts/secure-boot-key.sh) | Helps with Secure Boot key setup.                                                                               |
| [utils](scripts/utils.sh)                     | Contains utility functions used by other scripts.                                                               |

## Shortcuts

Keyboard shortcuts are stored in [shortcuts/shortcuts.kksrc](shortcuts/shortcuts.kksrc).

They can be exported and imported at _System Settings > Keyboard > Shortcuts_.
