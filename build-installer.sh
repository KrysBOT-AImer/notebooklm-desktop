#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

APP_NAME="notebooklm-desktop"
APP_TITLE="NotebookLM"
VERSION="$(node -p "require('./package.json').version")"
ARCH="$(uname -m)"

if [[ "$ARCH" != "x86_64" ]]; then
  echo "Warning: building for host architecture '$ARCH'." >&2
fi

ELECTRON_DIST="$ROOT_DIR/node_modules/electron/dist"
if [[ ! -d "$ELECTRON_DIST" || ! -x "$ELECTRON_DIST/electron" ]]; then
  echo "Error: Electron runtime not found at $ELECTRON_DIST" >&2
  echo "Run 'npm install' first." >&2
  exit 1
fi

BUILD_ROOT="$ROOT_DIR/build"
STAGE_DIR="$BUILD_ROOT/$APP_NAME"
DIST_DIR="$ROOT_DIR/dist"
TARBALL_NAME="${APP_NAME}-${VERSION}-linux-${ARCH}.tar.gz"
RUN_NAME="${APP_NAME}-${VERSION}-linux-${ARCH}.run"
TARBALL_PATH="$DIST_DIR/$TARBALL_NAME"
RUN_PATH="$DIST_DIR/$RUN_NAME"

cleanup() {
  rm -rf "$BUILD_ROOT"
}
trap cleanup EXIT

rm -rf "$BUILD_ROOT"
mkdir -p "$STAGE_DIR" "$DIST_DIR"

echo "[1/5] Staging standalone Electron runtime..."
cp -a "$ELECTRON_DIST/." "$STAGE_DIR/"
rm -f "$STAGE_DIR/resources/default_app.asar"
mv "$STAGE_DIR/electron" "$STAGE_DIR/${APP_NAME}-bin"
chmod 755 "$STAGE_DIR/${APP_NAME}-bin"

echo "[2/5] Copying application bundle into resources/app..."
APP_BUNDLE="$STAGE_DIR/resources/app"
mkdir -p "$APP_BUNDLE/assets/icons"

node -e '
const fs = require("fs");
const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
const prodPkg = {
  name: pkg.name,
  productName: pkg.productName || "NotebookLM",
  desktopName: pkg.desktopName || "notebooklm-desktop.desktop",
  version: pkg.version,
  description: pkg.description,
  main: pkg.main || "main.js",
  license: pkg.license || "MIT"
};
fs.writeFileSync(process.argv[1], JSON.stringify(prodPkg, null, 2) + "\n");
' "$APP_BUNDLE/package.json"

cp "$ROOT_DIR/main.js" "$APP_BUNDLE/main.js"
cp "$ROOT_DIR/preload.js" "$APP_BUNDLE/preload.js"
cp "$ROOT_DIR/assets/icon.png" "$APP_BUNDLE/assets/icon.png"
cp "$ROOT_DIR/assets/tray-icon.png" "$APP_BUNDLE/assets/tray-icon.png"
cp "$ROOT_DIR/assets/icon.svg" "$APP_BUNDLE/assets/icon.svg"
cp "$ROOT_DIR/assets/icons/"*.png "$APP_BUNDLE/assets/icons/"

echo "[3/5] Writing portable install.sh and uninstall.sh..."
cat > "$STAGE_DIR/install.sh" <<'INSTALL_EOF'
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="notebooklm-desktop"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE=""
for arg in "$@"; do
  case "$arg" in
    --user) MODE="user" ;;
    --system) MODE="system" ;;
    -h|--help)
      cat <<USAGE
Usage: $(basename "$0") [--user | --system]

Options:
  --user     Install for current user (~/.local/share/$APP_NAME) [default]
  --system   Install system-wide (/opt/$APP_NAME, requires root/sudo)
  -h, --help Show this help
USAGE
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then
    MODE="system"
  else
    MODE="user"
  fi
fi

if [[ "$MODE" == "system" && "$(id -u)" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo bash "$0" --system
  else
    echo "Error: --system installation requires root privileges (sudo not found)." >&2
    exit 1
  fi
fi

if [[ "$MODE" == "system" ]]; then
  INSTALL_DIR="/opt/$APP_NAME"
  BIN_DIR="/usr/local/bin"
  APPS_DIR="/usr/share/applications"
  ICON_BASE="/usr/share/icons/hicolor"
  PIXMAPS_DIR="/usr/share/pixmaps"
else
  DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
  INSTALL_DIR="$DATA_HOME/$APP_NAME"
  BIN_DIR="$HOME/.local/bin"
  APPS_DIR="$DATA_HOME/applications"
  ICON_BASE="$DATA_HOME/icons/hicolor"
  PIXMAPS_DIR="$DATA_HOME/pixmaps"
fi

BIN_PATH="$BIN_DIR/$APP_NAME"
DESKTOP_PATH="$APPS_DIR/$APP_NAME.desktop"
ICON_SVG_DIR="$ICON_BASE/scalable/apps"

echo "Installing NotebookLM Desktop ($MODE mode) to $INSTALL_DIR..."

if [[ -x "$BIN_PATH" ]]; then
  "$BIN_PATH" --quit >/dev/null 2>&1 || true
fi

mkdir -p "$BIN_DIR" "$APPS_DIR" "$ICON_SVG_DIR" "$PIXMAPS_DIR"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -a "$SCRIPT_DIR/." "$INSTALL_DIR/"

chmod 755 "$INSTALL_DIR/${APP_NAME}-bin" "$INSTALL_DIR/install.sh" "$INSTALL_DIR/uninstall.sh"
if [[ "$MODE" == "system" && -f "$INSTALL_DIR/chrome-sandbox" ]]; then
  chown root:root "$INSTALL_DIR/chrome-sandbox"
  chmod 4755 "$INSTALL_DIR/chrome-sandbox"
fi

cat > "$BIN_PATH" <<LAUNCHER_EOF
#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$INSTALL_DIR"

if [[ "\${1:-}" == "--uninstall" ]]; then
  shift
  exec bash "\$INSTALL_DIR/uninstall.sh" "\$@"
fi

exec "\$INSTALL_DIR/${APP_NAME}-bin" "\$@"
LAUNCHER_EOF
chmod 755 "$BIN_PATH"

for size in 16 24 32 48 64 128 256 512; do
  mkdir -p "$ICON_BASE/${size}x${size}/apps"
  cp "$INSTALL_DIR/resources/app/assets/icons/icon-${size}.png" "$ICON_BASE/${size}x${size}/apps/${APP_NAME}.png"
done
cp "$INSTALL_DIR/resources/app/assets/icon.svg" "$ICON_SVG_DIR/${APP_NAME}.svg"
cp "$INSTALL_DIR/resources/app/assets/icon.png" "$PIXMAPS_DIR/${APP_NAME}.png"

cat > "$DESKTOP_PATH" <<DESKTOP_EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=NotebookLM
GenericName=AI Research & Notebook Assistant
Comment=Google NotebookLM Desktop App
Exec=$BIN_PATH %U
Icon=$APP_NAME
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
DESKTOP_EOF
chmod 644 "$DESKTOP_PATH"

update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
if [[ -f "$ICON_BASE/index.theme" ]]; then
  gtk-update-icon-cache -f -t "$ICON_BASE" >/dev/null 2>&1 || true
else
  rm -f "$ICON_BASE/icon-theme.cache"
fi
xdg-desktop-menu forceupdate >/dev/null 2>&1 || true
if [[ "$MODE" == "user" ]]; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || kbuildsycoca5 --noincremental >/dev/null 2>&1 || true
fi

echo "NotebookLM Desktop installed successfully!"
echo "  App bundle : $INSTALL_DIR"
echo "  CLI binary : $BIN_PATH"
echo "  Desktop    : $DESKTOP_PATH"
if [[ "$MODE" == "user" && ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "  Note: Add '$BIN_DIR' to your PATH to run '$APP_NAME' from any terminal."
fi
INSTALL_EOF
chmod 755 "$STAGE_DIR/install.sh"

cat > "$STAGE_DIR/uninstall.sh" <<'UNINSTALL_EOF'
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="notebooklm-desktop"
MODE=""
PURGE=false

for arg in "$@"; do
  case "$arg" in
    --user) MODE="user" ;;
    --system) MODE="system" ;;
    --purge) PURGE=true ;;
    --uninstall) ;;
    -h|--help)
      cat <<USAGE
Usage: $(basename "$0") [--user | --system] [--purge]

Options:
  --user     Uninstall per-user installation
  --system   Uninstall system-wide (/opt/$APP_NAME) installation
  --purge    Also remove saved config, cache, and login session (~/.config/$APP_NAME)
  -h, --help Show this help
USAGE
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

if [[ -z "$MODE" ]]; then
  if [[ -d "$DATA_HOME/$APP_NAME" || -f "$HOME/.local/bin/$APP_NAME" || -f "$DATA_HOME/applications/$APP_NAME.desktop" ]]; then
    MODE="user"
  elif [[ -d "/opt/$APP_NAME" || -f "/usr/local/bin/$APP_NAME" || -f "/usr/share/applications/$APP_NAME.desktop" ]]; then
    MODE="system"
  else
    MODE="user"
  fi
fi

if [[ "$MODE" == "system" && "$(id -u)" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    ARGS=("--system")
    if [[ "$PURGE" == true ]]; then
      ARGS+=("--purge")
    fi
    exec sudo bash "$0" "${ARGS[@]}"
  else
    echo "Error: --system uninstallation requires root privileges (sudo not found)." >&2
    exit 1
  fi
fi

if [[ "$MODE" == "system" ]]; then
  INSTALL_DIR="/opt/$APP_NAME"
  BIN_PATH="/usr/local/bin/$APP_NAME"
  APPS_DIR="/usr/share/applications"
  ICON_BASE="/usr/share/icons/hicolor"
  PIXMAPS_DIR="/usr/share/pixmaps"
else
  INSTALL_DIR="$DATA_HOME/$APP_NAME"
  BIN_PATH="$HOME/.local/bin/$APP_NAME"
  APPS_DIR="$DATA_HOME/applications"
  ICON_BASE="$DATA_HOME/icons/hicolor"
  PIXMAPS_DIR="$DATA_HOME/pixmaps"
fi

if [[ -x "$BIN_PATH" ]]; then
  "$BIN_PATH" --quit >/dev/null 2>&1 || true
fi
pkill -f "[${APP_NAME:0:1}]${APP_NAME:1}-bin" >/dev/null 2>&1 || true

rm -rf "$INSTALL_DIR"
rm -f "$BIN_PATH"
rm -f "$APPS_DIR/${APP_NAME}.desktop"
for size in 16 24 32 48 64 128 256 512; do
  rm -f "$ICON_BASE/${size}x${size}/apps/${APP_NAME}.png"
done
rm -f "$ICON_BASE/scalable/apps/${APP_NAME}.svg"
rm -f "$PIXMAPS_DIR/${APP_NAME}.png"

update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
if [[ -f "$ICON_BASE/index.theme" ]]; then
  gtk-update-icon-cache -f -t "$ICON_BASE" >/dev/null 2>&1 || true
else
  rm -f "$ICON_BASE/icon-theme.cache"
fi
xdg-desktop-menu forceupdate >/dev/null 2>&1 || true
if [[ "$MODE" == "user" ]]; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || kbuildsycoca5 --noincremental >/dev/null 2>&1 || true
fi

if [[ "$PURGE" == true ]]; then
  rm -rf "$CONFIG_HOME/$APP_NAME"
  echo "Removed user data at $CONFIG_HOME/$APP_NAME"
fi

echo "NotebookLM Desktop ($MODE) uninstalled."
UNINSTALL_EOF
chmod 755 "$STAGE_DIR/uninstall.sh"

echo "[4/5] Creating portable tarball ($TARBALL_NAME)..."
rm -f "$DIST_DIR/${APP_NAME}-1.0.0-"* "$TARBALL_PATH" "$RUN_PATH"
tar --owner=0 --group=0 --numeric-owner -czf "$TARBALL_PATH" -C "$BUILD_ROOT" "$APP_NAME"

PAYLOAD_SHA256="$(sha256sum "$TARBALL_PATH" | awk '{print $1}')"

echo "[5/5] Building self-extracting universal installer ($RUN_NAME)..."
cat > "$RUN_PATH" <<RUN_HEADER_EOF
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="$APP_NAME"
VERSION="$VERSION"
EXPECTED_ARCH="$ARCH"
EXPECTED_SHA256="$PAYLOAD_SHA256"

print_help() {
  cat <<HELP
NotebookLM Desktop v\${VERSION} - Universal Linux Installer (\${EXPECTED_ARCH})

Usage:
  \$0 [OPTIONS]

Options:
  --user           Install for the current user (~/.local/share/\$APP_NAME) [default]
  --system         Install system-wide (/opt/\$APP_NAME, uses sudo if needed)
  --uninstall      Uninstall NotebookLM Desktop
  --purge          With --uninstall, also remove ~/.config/\$APP_NAME
  --extract <dir>  Extract portable bundle into <dir> without installing
  --check          Verify installer archive SHA-256 integrity
  -h, --help       Show this help message
HELP
}

ACTION="install"
EXTRACT_DIR=""
PASS_ARGS=()

while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    --check)
      ACTION="check"
      shift
      ;;
    --extract)
      ACTION="extract"
      if [[ -z "\${2:-}" ]]; then
        echo "Error: --extract requires a target directory." >&2
        exit 1
      fi
      EXTRACT_DIR="\$2"
      shift 2
      ;;
    --uninstall)
      ACTION="uninstall"
      shift
      ;;
    --user|--system|--purge)
      PASS_ARGS+=("\$1")
      shift
      ;;
    *)
      echo "Unknown option: \$1" >&2
      echo "Run '\$0 --help' for usage." >&2
      exit 1
      ;;
  esac
done

ARCHIVE_LINE="\$(awk '/^__ARCHIVE_BELOW__$/ {print NR + 1; exit 0}' "\$0")"
if [[ -z "\$ARCHIVE_LINE" ]]; then
  echo "Error: corrupted installer (missing archive marker)." >&2
  exit 1
fi

verify_checksum() {
  if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL_SHA256="\$(tail -n +"\$ARCHIVE_LINE" "\$0" | sha256sum | awk '{print \$1}')"
  elif command -v shasum >/dev/null 2>&1; then
    ACTUAL_SHA256="\$(tail -n +"\$ARCHIVE_LINE" "\$0" | shasum -a 256 | awk '{print \$1}')"
  else
    echo "Warning: sha256sum not found; skipping checksum verification." >&2
    return 0
  fi

  if [[ "\$ACTUAL_SHA256" != "\$EXPECTED_SHA256" ]]; then
    echo "Error: installer integrity check failed!" >&2
    echo "  Expected: \$EXPECTED_SHA256" >&2
    echo "  Actual:   \$ACTUAL_SHA256" >&2
    exit 1
  fi
}

if [[ "\$ACTION" == "check" ]]; then
  verify_checksum
  echo "OK: NotebookLM Desktop v\${VERSION} installer integrity verified (\$EXPECTED_SHA256)"
  exit 0
fi

HOST_ARCH="\$(uname -m)"
if [[ "\$HOST_ARCH" != "\$EXPECTED_ARCH" && "\$ACTION" != "uninstall" ]]; then
  echo "Error: this installer is built for '\$EXPECTED_ARCH', but host is '\$HOST_ARCH'." >&2
  exit 1
fi

if [[ "\$ACTION" == "extract" ]]; then
  verify_checksum
  mkdir -p "\$EXTRACT_DIR"
  tail -n +"\$ARCHIVE_LINE" "\$0" | tar -xz -C "\$EXTRACT_DIR"
  echo "Extracted portable bundle to: \$EXTRACT_DIR/\$APP_NAME"
  exit 0
fi

TMP_DIR="\$(mktemp -d)"
cleanup_tmp() {
  rm -rf "\$TMP_DIR"
}
trap cleanup_tmp EXIT

if [[ "\$ACTION" == "uninstall" ]]; then
  DATA_HOME="\${XDG_DATA_HOME:-\$HOME/.local/share}"
  if [[ -x "\$DATA_HOME/\$APP_NAME/uninstall.sh" && "\${PASS_ARGS[*]-}" != *"--system"* ]]; then
    exec bash "\$DATA_HOME/\$APP_NAME/uninstall.sh" \${PASS_ARGS[@]+"\${PASS_ARGS[@]}"}
  elif [[ -x "/opt/\$APP_NAME/uninstall.sh" ]]; then
    exec bash "/opt/\$APP_NAME/uninstall.sh" \${PASS_ARGS[@]+"\${PASS_ARGS[@]}"}
  else
    verify_checksum
    tail -n +"\$ARCHIVE_LINE" "\$0" | tar -xz -C "\$TMP_DIR"
    bash "\$TMP_DIR/\$APP_NAME/uninstall.sh" \${PASS_ARGS[@]+"\${PASS_ARGS[@]}"}
  fi
  exit 0
fi

verify_checksum
echo "Extracting NotebookLM Desktop v\${VERSION}..."
tail -n +"\$ARCHIVE_LINE" "\$0" | tar -xz -C "\$TMP_DIR"
bash "\$TMP_DIR/\$APP_NAME/install.sh" \${PASS_ARGS[@]+"\${PASS_ARGS[@]}"}
exit 0

__ARCHIVE_BELOW__
RUN_HEADER_EOF

cat "$TARBALL_PATH" >> "$RUN_PATH"
chmod 755 "$RUN_PATH"

(cd "$DIST_DIR" && sha256sum "$RUN_NAME" "$TARBALL_NAME" > SHA256SUMS)

echo "Done! Universal Linux installer artifacts created in $DIST_DIR:"
ls -lh "$DIST_DIR"
