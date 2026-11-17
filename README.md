# Rig

```text
██████  ██  ██████
██   ██ ██ ██
██████  ██ ██   ███
██   ██ ██ ██    ██
██   ██ ██  ██████
```

Automated system setup for Fedora Linux and macOS.

## Quick Start

### One-line Installer

```bash
eval "$(curl -fsSL \
  https://raw.githubusercontent.com/pixincreate/rig/main/unix/setup)"
```

The installer automatically:

- Detect your platform (Fedora or macOS)
- Clone the dotfiles repository to `~/dev/.dotfiles`
- Clone this repository to `~/dev/.rig`
- Prompt you for Git name/email, NextDNS config, etc.
- Run the complete setup

### Configuration

Settings are read from `config.json` first. Edit before running:

```bash
vim unix/fedora/config.json  # or unix/macos/config.json
```

```json
{
  "git": {
    "user_name": "Your Name",
    "user_email": "your@email.com"
  },
  "secureboot": true
}
```

**Optional**: Override via environment variables:

```bash
export RIG_GIT_NAME='Your Name'
export RIG_GIT_EMAIL='your@email.com'
export RIG_NEXTDNS_ID='abc123'
export RIG_SECUREBOOT='true'  # Fedora only
eval "$(curl -fsSL \
  https://raw.githubusercontent.com/pixincreate/rig/main/unix/setup)"
```

### Manual Installation

```bash
# macOS
git clone https://github.com/pixincreate/dotfiles.git ~/.dotfiles
git clone https://github.com/pixincreate/rig.git ~/.rig
cd ~/.rig/unix/macos
./macos-setup

# Fedora
git clone https://github.com/pixincreate/dotfiles.git ~/.dotfiles
git clone https://github.com/pixincreate/rig.git ~/.rig
cd ~/.rig/unix/fedora
./fedora-setup
```

## Unified CLI

Rig includes a unified CLI dispatcher on both Fedora and macOS. Run it from
anywhere after setup:

```bash
rig                    # List all available commands with descriptions
rig add base neovim    # Add neovim to base list AND install it
rig drift              # Dry-run: show declared packages missing from this system
rig drift --apply      # Converge by re-running the idempotent packaging modules
rig pkg-manage         # Interactive package manager
rig stow --all         # Stow all dotfiles
rig install skillset   # Install rig skill to skillset repo
rig webapp-install "ChatGPT" "https://chat.openai.com" "icon.png"
```

The dispatcher uses multi-word prefix routing (inspired by omarchy):
`rig install skillset` dispatches to `rig-install-skillset`. Run `rig` without
arguments to see all available commands.

Each platform has its own dispatcher (`unix/fedora/bin/rig` and
`unix/macos/bin/rig`) which discovers `rig-*` scripts in `libexec/` plus
shared commands from `unix/common/libexec/`.

## Running Individual Components

Both macOS and Fedora support running specific modules:

```bash
./macos-setup --only <module-path>    # macOS
./fedora-setup --only <module-path>   # Fedora
```

### macOS Modules

```bash
./macos-setup --only dotfiles/stow        # Stow all packages
./macos-setup --only dotfiles/zsh         # Configure ZSH
./macos-setup --only dotfiles/fonts       # Install fonts
./macos-setup --only packaging/homebrew   # Install Homebrew
./macos-setup --only packaging/brew       # Install brew packages
./macos-setup --only packaging/cask       # Install cask apps
./macos-setup --only config/git           # Git & SSH
./macos-setup --only config/nextdns       # NextDNS
```

### Fedora Modules

```bash
./fedora-setup --only dotfiles/stow
./fedora-setup --only dotfiles/zsh
./fedora-setup --only packaging/base      # Base packages
./fedora-setup --only packaging/flatpak   # Flatpak apps
./fedora-setup --only packaging/rust      # Rust tools
./fedora-setup --only config/git
./fedora-setup --only config/kde          # KDE Plasma defaults
./fedora-setup --only config/services     # Enable services
./fedora-setup --only config/performance  # Performance (zram, timeout)
./fedora-setup --only config/secureboot   # Secure Boot setup
./fedora-setup --only config/hardware/asus  # ASUS laptop (sleep, GPU power)
./fedora-setup --only config/hardware/nvidia  # NVIDIA drivers
./fedora-setup --only external/skillset   # External repo (skillset)
```

## Dotfiles Management

### Selective Stowing

```bash
# Stow all packages
rig stow --all

# Stow specific packages
rig stow config zsh          # Only config and zsh

# Adopt existing files (resolve conflicts)
rig stow --adopt config      # Move existing files into dotfiles repo and stow

# Restow (useful after updates)
rig stow -R config           # Restow config
rig stow -R --all            # Restow all
```

### Manual Stow

```bash
cd ~/.dotfiles
stow --no-folding --restow --target=$HOME home/config
stow --no-folding --restow --target=$HOME home/zsh
```

## Package Management

### Declarative (Recommended)

```bash
# macOS
rig add brew neovim             # Add CLI tool to list AND install it
rig add cask firefox            # Add GUI app to list AND install it
rig pkg-remove cask firefox     # Uninstall AND remove from the list

# Fedora
rig add base neovim             # Add to base packages AND install
rig add flatpak com.spotify.Client    # Add Flatpak AND install
rig pkg-remove base neovim      # Uninstall AND remove from the list

# Converge a machine that drifted from its lists
rig drift                       # Dry-run: report what is missing
rig drift --apply               # Re-run idempotent packaging modules to fix it
```

`rig add` (alias of `rig pkg-add`) edits the package list and immediately
installs anything missing, in one step. `rig drift` works both ways: it
reports declared packages missing from the system AND installed packages
absent from the lists (report-only — nothing is auto-uninstalled; declare
extras with `rig pkg-add` or remove them with `rig pkg-remove`).

### Interactive

```bash
rig pkg-manage
```

## Reset/Re-run Components

```bash
rig reset
```

Interactive menu to reset specific components.

## Web Applications (Fedora only)

```bash
# Install
rig webapp-install "App Name" "https://example.com" "icon.png"

# Remove
rig webapp-remove ChatGPT  # Specific app
```

## Structure

```text

.
├── unix/
│   ├── setup              # Common entry point (OS detection)
│   ├── common/            # Cross-platform scripts
│   │   ├── libexec/       # Shared CLI commands
│   │   ├── helpers/       # Logging, common functions, package backends
│   │   ├── dotfiles/      # Stow, fonts, zsh
│   │   ├── config/        # Git, NextDNS, Rust
│   │   └── external/      # External git repos (skillset)
│   ├── fedora/            # Fedora-specific setup
│   │   ├── bin/           # rig dispatcher
│   │   ├── libexec/       # Platform-specific commands (webapps, migrate)
│   │   ├── install/
│   │   │   ├── config/    # System config (KDE, hardware)
│   │   │   ├── dotfiles/  # Dotfiles management
│   │   │   └── external/  # External repos
│   │   └── packages/      # Package lists
│   └── macos/             # macOS-specific setup
│       ├── bin/           # rig dispatcher
├── windows/               # Windows configuration (see windows/README.md)
├── default/               # Default configs (skills, wallpapers)
└── docs/                  # Documentation
```

## Features

### Common (Both Platforms)

- **Git & SSH**: ed25519 keys with automatic configuration
- **Shell**: ZSH with zgenom plugin manager
- **Dotfiles**: GNU Stow for symlink management
- **Fonts**: Iosevka, CaskaydiaCove Nerd Font, Meslo Nerd Font,
  JetBrains Mono, Inter, Geist
- **Rust**: Rustup with configurable cargo tools
- **NextDNS**: Automated DNS configuration

### Fedora-Specific

- **KDE Plasma**: Keybindings, Krohnkite tiling, theme defaults,
  KDE config symlink management
- **KDE Config**: Config files (`kwinrc`, `kdeglobals`,
  `kglobalshortcutsrc`, `kwinrulesrc`, `plasmaparc`) are symlinked
  via `kde.sh` so changes stay tracked in the repo
- **Package Management**: DNF optimization, Flatpak, Rust tools
- **Repositories**: RPM Fusion, COPR, Terra
- **Web Applications**: Twitter, ChatGPT (incognito), Grok (incognito)
- **Hardware Support**: ASUS laptops, NVIDIA drivers
- **Performance**: zram, fstrim, systemd-oomd
- **Services**: PostgreSQL, Redis, Docker
- **Security**: Firmware updates, Secure Boot

### macOS-Specific

- **Package Management**: Homebrew, Cask, Rust tools
- **Applications**: CLI tools and GUI applications
- **System**: Hostname and system preferences

## Declarative Configuration

Each platform has a `config.json` for declarative configuration:

- `unix/macos/config.json` - macOS configuration
- `unix/fedora/config.json` - Fedora configuration

## Logs

Setup logs are stored at `~/.local/state/rig/install.log`.

Check logs if something fails:

```bash
tail -50 ~/.local/state/rig/install.log
```

## Documentation

- **[Fedora Setup Guide](unix/fedora/README.md)** - Fedora-specific
  documentation
- **[macOS Setup Guide](unix/macos/README.md)** - macOS-specific documentation

## License

Copyright 2026 pixincreate.
Licensed under the [Apache License, Version 2.0](LICENSE).
Individual files and third-party material can specify different terms.
Material published under CC0 1.0 Universal remains available under CC0.
This includes unchanged material in later versions.
