#!/bin/bash
# Installs Antigravity IDE 2.8.0 from the verified staged extract.
# Run with: sudo bash ~/Downloads/install-antigravity-ide.sh
set -euo pipefail

SRC="/home/ren/Downloads/agi-stage-2.8.0/Antigravity IDE"
DST="/opt/antigravity-ide"
BAK="/opt/antigravity-ide.bak-2.6.0"

[ "$(id -u)" -eq 0 ] || { echo "Run with sudo"; exit 1; }
[ -x "$SRC/antigravity-ide" ] || { echo "Staged build missing at $SRC"; exit 1; }

if [ -d "$DST" ]; then
    rm -rf "$BAK"
    mv "$DST" "$BAK"
fi

cp -a "$SRC" "$DST"
chown -R root:root "$DST"
chmod 4755 "$DST/chrome-sandbox"

# CLI symlink
ln -sf "$DST/antigravity-ide" /usr/local/bin/antigravity-ide

# Install icon and system-wide .desktop entry
ICON_DIR="/usr/share/icons/hicolor/512x512/apps"
mkdir -p "$ICON_DIR"
if [ -f "$DST/resources/app/resources/linux/code.png" ]; then
    cp "$DST/resources/app/resources/linux/code.png" "$ICON_DIR/antigravity-ide.png"
    chmod 644 "$ICON_DIR/antigravity-ide.png"
fi

cat <<EOF > /usr/share/applications/antigravity-ide.desktop
[Desktop Entry]
Name=Antigravity IDE
Comment=AI-powered IDE platform
GenericName=Text Editor
Exec=$DST/antigravity-ide %F
Icon=antigravity-ide
Type=Application
StartupNotify=true
StartupWMClass=antigravity-ide
Categories=Development;IDE;TextEditor;
MimeType=text/plain;inode/directory;
Actions=new-empty-window;
Keywords=antigravity;ide;code;editor;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=$DST/antigravity-ide --new-window %F
Icon=antigravity-ide
EOF
chmod 644 /usr/share/applications/antigravity-ide.desktop

update-desktop-database /usr/share/applications 2>/dev/null || true
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true

echo "Installed:"
grep ideVersion "$DST/resources/app/product.json"
