#!/bin/bash

source "$RIG_INSTALL/helpers/logging.sh"

log_section "rofimoji"

mkdir -p "$HOME/.local/share/applications" "$HOME/.config/fuzzel"

# KDE runs the picker in a transient unit with KillMode=control-group, which
# kills the forked wl-copy that owns the clipboard. Run it in a scope so the
# selection survives.
rm -f "$HOME/.local/share/applications/rofimoji.desktop"
cat > "$HOME/.local/share/applications/rofimoji.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=rofimoji
Comment=Pick emojis, GIFs, and other Unicode characters
Exec=systemd-run --user --scope --collect --quiet -p KillMode=process rofimoji
Icon=insert-smiley
Terminal=false
Categories=Utility;
EOF

rm -f "$HOME/.config/fuzzel/fuzzel.ini"
cat > "$HOME/.config/fuzzel/fuzzel.ini" <<'EOF'
# Fuzzel theme matching the Fedora Dark KDE palette.
[colors]
background=141618ff
text=fcfcfcff
prompt=fcfcfcff
input=fcfcfcff
match=6568b2ff
selection=4c4f83ff
selection-text=ffffffff
selection-match=6568b2ff
counter=fcfcfcff
border=6568b2ff
EOF

if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 >/dev/null 2>&1 || true
fi

log_success "rofimoji launcher and fuzzel theme installed"