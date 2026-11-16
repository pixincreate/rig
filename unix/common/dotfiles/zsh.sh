#!/bin/bash

set -e

# Source platform detection helper
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/platform.sh"

setup_zsh() {
    local zsh_dir="${1:-$HOME/.zsh}"

    echo "Configuring ZSH"

    local local_file="$zsh_dir/local.zsh"
    local platform
    platform=$(detect_platform)

    echo "[INFO] Detected platform: $platform"

    # local.zsh is user-owned: rig only creates it once and never touches it
    # again, so the user is free to customise it.
    if [[ -f "$local_file" ]]; then
        echo "[INFO] $local_file already exists — leaving it untouched (user-owned)"
        return 0
    fi

    echo "[INFO] Creating platform-specific ZSH config: $local_file"

    case "$platform" in
        macos)
            cat > "$local_file" <<'EOF'
# macOS specific configurations
typeset -U PATH path
path=(
    $path
    $HOME/.yarn/bin
    $HOME/.config/yarn/global/node_modules/.bin
    $(brew --prefix)/opt/coreutils/libexec/gnubin
    $(brew --prefix)/opt/findutils/libexec/gnubin
    $(brew --prefix)/opt/gnu-getopt/bin
    $(brew --prefix)/opt/gnu-indent/libexec/gnubin
    $(brew --prefix)/opt/gnu-tar/libexec/gnubin
    $(brew --prefix)/opt/binutils/bin
    $(brew --prefix)/opt/homebrew/opt/openjdk@21/bin
    $(brew --prefix)/opt/homebrew/opt/openjdk@17/bin
    $(brew --prefix)/opt/llvm/bin
    $(brew --prefix)/opt/postgresql@18/bin
)

# Disable Homebrew auto updating packages
HOMEBREW_NO_AUTO_UPDATE=1

PQ_LIB_DIR="$(brew --prefix libpq)/lib"

export CPPFLAGS="-I$(brew --prefix)/opt/llvm/include"
export LDFLAGS="-L$(brew --prefix)/opt/llvm/lib"
export CC="$(brew --prefix)/opt/llvm/bin/clang"

# rig bin
export PATH="$HOME/dev/.rig/unix/macos/bin:$PATH"

# macOS aliases
alias flush-dns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'
alias show-hidden='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder'
alias hide-hidden='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder'

alias zed=zed-preview
EOF
            ;;

        fedora)
            cat > "$local_file" <<'EOF'
# rig bin
export PATH="$HOME/dev/.rig/unix/fedora/bin:$PATH"

# npm global packages
export PATH="$HOME/.npm-global/bin:$PATH"

# Fedora specific configurations
export SYS_HEALTH="${HOME}/dev/.rig/unix/fedora/health-check.sh"

alias cleanup="sudo dnf autoremove && flatpak uninstall --unused"
alias dnf-clean='sudo dnf autoremove && sudo dnf clean all'
alias trigger_secure_boot='sudo kmodgenca -a && sudo mokutil --import /etc/pki/akmods/certs/public_key.der'
alias zed=zed-preview

# Switch the discrete GPU mode on this ASUS laptop.
#
# Usage: gpu hybrid|integrated
#
# The switch rebinds the discrete GPU, so supergfxctl wants the graphical
# session to end first. The command disables that wait, so the session and
# the running work survive the switch.
#
# The oh-my-zsh git plugin defines `alias gpu='git push upstream'`. zsh
# expands aliases before it parses a function definition, so without this
# unalias the file fails with "defining function based on alias".
unalias gpu 2>/dev/null

gpu() {
  rig gpu mode "$@"
}

# Report which ASUS firmware features this laptop implements.
#
# Usage: gpu-caps
gpu-caps() {
  rig hw asus caps "$@"
}

# rig manages everything above this line. Add your own config below — rig will never edit it.
# Wayland backends
export GDK_BACKEND=wayland
export QT_QPA_PLATFORM=wayland
export MOZ_ENABLE_WAYLAND=1
export ELECTRON_OZONE_PLATFORM_HINT=wayland
export SDL_VIDEODRIVER=wayland
export CLUTTER_BACKEND=wayland
EOF
            ;;

        debian)
            cat > "$local_file" <<'EOF'
# Debian specific configurations
export LDFLAGS="-L/$(brew --prefix)/opt/binutils/lib"
export CPPFLAGS="-I/$(brew --prefix)/opt/binutils/include"

# WSL configurations (if applicable)
if [[ -n "$WSL_DISTRO_NAME" ]]; then
    export WINHOME=$(wslpath "$(cd /mnt/c && cmd.exe /C 'echo %USERPROFILE%' | tr -d '\\r')")
    alias studio='/mnt/d/Program\\ Files/IDE/Android\\ Studio/bin/studio64.exe'
fi
EOF
            ;;

        android)
            cat > "$local_file" <<'EOF'
# Termux storage
[[ ! -d ~/storage ]] && termux-setup-storage
# pkg aliases
alias pkg-update='pkg upgrade -y'
alias pkg-clean='pkg autoclean && pkg clean'

# Android/Termux specific configurations
alias backup_termux='tar -zcf /sdcard/backups/termux/termux-backup.tar.gz -C /data/data/com.termux/files ./home ./usr'
alias restore_termux='tar -zxf /sdcard/backups/termux/termux-backup.tar.gz -C /data/data/com.termux/files --recursive-unlink --preserve-permissions'
alias CONFIGS="${HOME}/dev/.dotfiles"
EOF
            ;;

        *)
            cat > "$local_file" <<'EOF'
# Generic Unix ZSH configuration

# Add your custom configurations here
EOF
            ;;
    esac

    cat >> "$local_file" <<'MARKER_EOF'

# rig manages everything above this line. Add your own config below — rig will never edit it.
MARKER_EOF

    echo "[SUCCESS] Platform-specific ZSH config created"

    # Change default shell to ZSH
    local zsh_path
    zsh_path=$(command -v zsh)

    if [[ "$SHELL" != "$zsh_path" ]]; then
        echo "[INFO] Current shell: $SHELL"
        echo "[INFO] ZSH path: $zsh_path"

        read -p "Change default shell to ZSH? [Y/n] " -n 1 -r
        echo

        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            if [[ "$platform" == "android" ]]; then
                # Termux doesn't use chsh
                echo "[INFO] On Termux, ZSH is automatically used"
            else
                # Ensure ZSH is in /etc/shells
                if ! grep -q "^$zsh_path$" /etc/shells 2>/dev/null; then
                    echo "[INFO] Adding ZSH to /etc/shells"
                    echo "$zsh_path" | sudo tee -a /etc/shells
                fi

                # Change shell
                if command -v chsh &>/dev/null; then
                    chsh -s "$zsh_path"
                    echo "[SUCCESS] Default shell changed to ZSH"
                    echo "[INFO] Please log out and log back in for changes to take effect"
                else
                    echo "[WARNING] chsh not available, cannot change default shell"
                fi
            fi
        else
            echo "[INFO] Keeping current shell: $SHELL"
        fi
    else
        echo "[INFO] Default shell is already ZSH"
    fi

    echo "[SUCCESS] ZSH configuration completed"
}
