# rig — Fedora

Opinionated Fedora KDE setup. This repo installs packages,
wires up dotfiles, tunes performance, configures hardware, and provides a
small `rig` CLI for day-to-day maintenance.

## What it does

`./fedora-setup` runs a single end-to-end install:

- Updates DNF and enables repositories (RPM Fusion, Terra, selected COPRs).
- Installs packages from declarative lists in `packages/`.
- Installs Flatpak apps, Rust tools, Node packages, and web apps.
- Stows dotfiles from `~/dev/.dotfiles/home`.
- Configures Git, SSH, ZSH, KDE, fonts, and hardware support (ASUS / NVIDIA).
- Applies performance tuning (zram, sysctl, fstrim, oomd).
- Sets up services (PostgreSQL, Redis, Docker, Tailscale, NextDNS).
- Runs pending migrations from `migrations/`.

After the first run you use `rig <command>` for incremental changes.

## Quick start

```bash
cd ~/dev/.rig/unix/fedora
./fedora-setup
```

Then reload your shell or log out and back in.

## Configuration

Edit `config.json` before running `fedora-setup`:

```json
{
  "system": { "hostname": "fedora-laptop" },
  "git": {
    "user_name": "Your Name",
    "user_email": "your@email.com"
  },
  "rust": {
    "tools": ["bat", "eza", "ripgrep", "zoxide", "starship"]
  }
}
```

## Daily CLI (`rig`)

`rig` discovers every `rig-*` script in `libexec/` and `unix/common/libexec/`:

```bash
rig                         # list all commands
rig add tools mpv           # add a package to a list and install it
rig stow --all              # restow all dotfiles
rig stow config zsh         # restow selected packages
rig migrate                 # run pending migrations
rig ocr                     # capture a region and copy extracted text
rig llama list              # show the model chain and downloaded models
rig llama start             # run the API in the background on :8080
rig llama status            # report state, memory, and active model
rig llama stop              # stop the background server
```

## Running individual setup modules

```bash
./fedora-setup --only dotfiles/stow
./fedora-setup --only dotfiles/zsh
./fedora-setup --only packaging/base
./fedora-setup --only config/git
./fedora-setup --only config/hardware/asus
```

Use the full path if the filename is ambiguous. List modules with
`find install -name "*.sh" | grep -v all.sh`.

## Package management

### Declarative (recommended)

`rig add` adds the package to its list and installs it in one step:

```bash
rig add base fastfetch
rig add tools rofimoji
rig add flatpak com.spotify.Client
rig add rust eza
rig pkg-remove tools rofimoji    # uninstall AND remove from the list
```

To converge a machine that drifted (or install everything at once), re-run the
idempotent installer:

```bash
./fedora-setup --only packaging/base
./fedora-setup --only packaging/flatpak
```

### Manual edit

```bash
echo "fastfetch" >> packages/base.packages
./fedora-setup --only packaging/base
```

### Package lists

- `base.packages` — core CLI utilities
- `development.packages` — compilers, runtimes, dev tools
- `tools.packages` — user apps and desktop utilities
- `system.packages` — system libraries
- `flatpak.packages` — Flatpak apps
- `rust.packages` — Rust tools installed via cargo

## Dotfiles

Dotfiles live in `~/dev/.dotfiles/home` and are managed with GNU Stow.

```bash
rig stow --all
rig stow config zsh        # only these packages
rig stow -R config         # restow one package
rig stow --adopt config    # move existing files into the dotfiles repo
rig stow -d zsh            # unstow a package
```

Available stow packages: `cargo`, `config`, `local`, `Pictures`, `ssh`, `zsh`.

### KDE config symlinks

KDE Plasma files are symlinked from the repo to `~/.config/` by
`install/config/kde.sh`:

- `~/.config/kwinrc`
- `~/.config/kwinrulesrc`
- `~/.config/kdeglobals`
- `~/.config/kglobalshortcutsrc`
- `~/.config/plasmaparc`

Apply them with `./fedora-setup --only config/kde`.

## Features

### Encrypted local secrets

Machine-local secrets are stored in `~/.zsh/.env.age` and decrypted on
shell startup with `age`:

```bash
# One-time setup: generates ~/.config/age/key.txt and encrypts existing secrets
rig migrate

# Edit secrets
age --decrypt --identity ~/.config/age/key.txt ~/.zsh/.env.age > ~/.zsh/.env
# ... edit ~/.zsh/.env ...
age --encrypt --recipient "$(cat ~/.config/age/key.pub)" \
  -o ~/.zsh/.env.age ~/.zsh/.env
rm ~/.zsh/.env
```

### Emoji picker

`Meta+.` opens `rofimoji` using `fuzzel` as the selector and `wtype` to
insert the emoji. The default Plasma emoji shortcut is disabled during
migration; you may need to log out and back in for the binding to stick.

### OCR

`rig ocr` captures a region with Spectacle, runs it through Tesseract
(English, Kannada, and Hindi language packs), and copies the result to the
clipboard.

### Local LLMs

Local models use `llama-cpp` from the `sneed/llama-cpp-vulkan` COPR:

```bash
rig llama list
rig llama pull https://example.com/model.gguf
rig llama chat
rig llama start
rig llama status
rig llama stop
```

`rig llama start` runs the server in the background and returns when the API
answers on `http://127.0.0.1:8080/v1`. `rig llama server` does the same in the
foreground until you press Ctrl-C.

The model comes from the `.llama` block in `unix/fedora/config.json`. The
`model` key is an ordered list: entries are tried in order and the first usable
one wins, so a second entry acts as a fallback.

Models are stored in `~/.local/share/llama.cpp/models`. Models referenced as
Hugging Face repos are cached by llama.cpp under `~/.cache/huggingface`.

## Hibernation

The system uses zram swap by default. To enable hibernation, create a btrfs
swapfile equal to your RAM size and add the `resume` kernel parameter. See
migration `1786219610.sh` for the automated setup, or configure it manually
and run:

```bash
sudo dracut -f
sudo reboot
```

## Reset / re-run components

```bash
rig reset
```

Interactive menu for resetting ZSH, dotfiles, fonts, Git, NextDNS, services,
hardware, web apps, and Rust tools.

## Post-install checklist

1. Log out and back in for group changes (docker, etc.).
2. Reboot if NVIDIA drivers were installed.
3. Add your SSH key to GitHub: `cat ~/.ssh/id_ed25519.pub`.
4. Reload the shell: `exec zsh`.

## Troubleshooting

### Package install fails

```bash
dnf repolist
dnf makecache
```

### Git config issues

```bash
git config --list --show-origin
ls -la ~/.ssh/
```

### Services don't start

```bash
systemctl status <service-name>
journalctl -u <service-name>
```

## Notes

- All scripts are idempotent and safe to re-run.
- Shared scripts live in `unix/common/`.
- Migrations are tracked in `~/.local/state/rig/migrations/`.
- See the [main README](../../README.md) for the cross-platform overview.
