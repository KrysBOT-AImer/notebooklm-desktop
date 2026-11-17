#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_DIR="$HOME/.local/bin"
APPS_DIR="$DATA_HOME/applications"
ICON_BASE="$DATA_HOME/icons/hicolor"
PIXMAPS_DIR="$DATA_HOME/pixmaps"

BIN_PATH="$BIN_DIR/notebooklm-desktop"
DESKTOP_PATH="$APPS_DIR/notebooklm-desktop.desktop"

mkdir -p "$BIN_DIR" "$APPS_DIR" "$PIXMAPS_DIR" "$ICON_BASE/scalable/apps"
for size in 16 24 32 48 64 128 256 512; do
  mkdir -p "$ICON_BASE/${size}x${size}/apps"
  cp "$APP_DIR/assets/icons/icon-${size}.png" "$ICON_BASE/${size}x${size}/apps/notebooklm-desktop.png"
done
cp "$APP_DIR/assets/icon.svg" "$ICON_BASE/scalable/apps/notebooklm-desktop.svg"
cp "$APP_DIR/assets/icon.png" "$PIXMAPS_DIR/notebooklm-desktop.png"

cat > "$BIN_PATH" <<EOF
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$APP_DIR"
ELECTRON_BIN="\$APP_DIR/node_modules/.bin/electron"

if [[ ! -x "\$ELECTRON_BIN" ]]; then
  echo "Error: Electron binary not found at \$ELECTRON_BIN" >&2
  echo "Run 'npm install' inside \$APP_DIR first." >&2
  exit 1
fi

exec "\$ELECTRON_BIN" "\$APP_DIR" "\$@"
EOF
chmod +x "$BIN_PATH"

cat > "$DESKTOP_PATH" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=NotebookLM
GenericName=AI Research & Notebook Assistant
Comment=Google NotebookLM Desktop App
Exec=$BIN_PATH %U
Icon=notebooklm-desktop
Terminal=false
StartupNotify=true
StartupWMClass=NotebookLM
Categories=Office;Utility;Network;
Keywords=notebooklm;gemini;google;ai;notes;research;
Actions=Toggle;Quit;

[Desktop Action Toggle]
Name=Show / Hide Window
Exec=$BIN_PATH --toggle

[Desktop Action Quit]
Name=Quit NotebookLM
Exec=$BIN_PATH --quit
EOF

if [[ ! -f "$ICON_BASE/index.theme" ]]; then
  rm -f "$ICON_BASE/icon-theme.cache"
else
  gtk-update-icon-cache -f -t "$ICON_BASE" 2>/dev/null || true
fi
update-desktop-database "$APPS_DIR" 2>/dev/null || true
kbuildsycoca6 --noincremental 2>/dev/null || kbuildsycoca5 --noincremental 2>/dev/null || true

echo "Installed CLI launcher: $BIN_PATH"
echo "Installed desktop entry: $DESKTOP_PATH"
echo "Installed multi-size icons into: $ICON_BASE"
