# NotebookLM Desktop (`notebooklm-desktop`)

Native-feeling Linux Electron desktop wrapper for **Google NotebookLM** (`https://notebooklm.google.com`) tailored for KDE Plasma (Wayland & X11).

## Features
- **Native KDE / Wayland integration**: Sets `desktopName`, `--class=notebooklm-desktop`, `StartupWMClass`, custom `.desktop` entry, and high-resolution SVG/PNG icons.
- **System Tray & Minimize-to-Tray**: Left-click the tray icon to show/hide the window; right-click for quick actions (*Show / Hide NotebookLM*, *NotebookLM Home*, *Reload*, *Minimize to Tray on Close*, *Always on Top*, *Quit*).
- **Google Sign-In & Drive Picker Ready**: Strips Electron identifiers from the User-Agent and allows Google OAuth and Drive/Docs popup flows while opening external citation links in your default browser.
- **Persistent State**: Remembers window size, position, maximized state, login cookies, and tray preferences.
- **Keyboard Shortcuts**:
  - `Alt+Left` / `Alt+Right`: Back / Forward
  - `Alt+Home`: NotebookLM Home
  - `Ctrl+R` / `F5`: Reload (`Ctrl+Shift+R`: Force Reload)
  - `Ctrl++` / `Ctrl+-` / `Ctrl+0`: Zoom In / Out / Reset
  - `F11`: Toggle Fullscreen
  - `Ctrl+Shift+I`: Toggle DevTools
  - `Ctrl+Q`: Quit NotebookLM completely
  - `Alt`: Temporarily reveal the hidden menu bar

## Universal Linux Installer (Zero Dependencies)

You can distribute and install **NotebookLM Desktop** on any `x86_64` Linux distribution (Arch/CachyOS, Ubuntu/Debian, Fedora, openSUSE, etc.) without `node` or `npm` using the self-extracting `.run` installer or portable `.tar.gz` archive in `dist/`.

### Install with the Single-File `.run` Installer

```bash
chmod +x dist/notebooklm-desktop-1.0.1-linux-x86_64.run
./dist/notebooklm-desktop-1.0.1-linux-x86_64.run
```

Installer options:
- `--user` *(default)* — Install for the current user (`~/.local/share/notebooklm-desktop`, `~/.local/bin/notebooklm-desktop`, and `~/.local/share/applications/notebooklm-desktop.desktop`)
- `--system` — Install system-wide (`/opt/notebooklm-desktop`, `/usr/local/bin/notebooklm-desktop`, `/usr/share/applications/notebooklm-desktop.desktop`; uses `sudo` if not already root)
- `--check` — Verify the embedded SHA-256 checksum of the installer payload
- `--extract <dir>` — Extract the portable bundle into `<dir>` without installing
- `--uninstall` — Remove NotebookLM Desktop (can also run `notebooklm-desktop --uninstall`)
- `--purge` — With `--uninstall`, also remove `~/.config/notebooklm-desktop`

### Rebuild the Installer Artifacts

```bash
npm run build:installer
```

This generates:
- `dist/notebooklm-desktop-1.0.1-linux-x86_64.run`
- `dist/notebooklm-desktop-1.0.1-linux-x86_64.tar.gz`
- `dist/SHA256SUMS`

## Development Usage

Launch from your KDE Application Launcher (**NotebookLM**), or from the terminal:

```bash
notebooklm-desktop
```

Or run directly from the project folder:

```bash
npm start
```

To reinstall or update the `.desktop` launcher and icons:

```bash
npm run install-desktop
```

To regenerate PNG icons from `assets/icon.svg`:

```bash
python3 generate_icons.py
```

## Credits, Dependencies & Third-Party Acknowledgments

This project stands on the shoulders of many open-source projects, runtimes, and system tools. Huge thanks to their authors and maintainers:

### Wrapped Service & Disclaimer
- **[Google NotebookLM](https://notebooklm.google.com)** — Created and operated by **Google LLC**. This project is an **unofficial** Linux desktop wrapper and is not affiliated with, endorsed by, or supported by Google.

### Core Runtime & Bundled Engine
The standalone `.run` / `.tar.gz` distribution bundles the official Electron Linux runtime, which includes:
- **[Electron](https://www.electronjs.org/)** (`45.3.4`, MIT License) — OpenJS Foundation & contributors.
- **[Chromium](https://www.chromium.org/)** (`156.0.8078.100`, BSD-3-Clause) — The Chromium Authors.
- **[Node.js](https://nodejs.org/)** (`24.22.3`, MIT License) — OpenJS Foundation & contributors.
- **[V8 JavaScript Engine](https://v8.dev/)** (`15.6.75`, BSD-3-Clause) — The V8 Project Authors.
- **[FFmpeg](https://ffmpeg.org/)** (`libffmpeg.so`, LGPL-2.1+) — The FFmpeg developers (pre-built Chromium media component shipped in Electron).
- **[SwiftShader](https://swiftshader.googlesource.com/SwiftShader)** (`libvk_swiftshader.so`, Apache-2.0) & **[Vulkan-Loader](https://github.com/KhronosGroup/Vulkan-Loader)** (`libvulkan.so.1`, Apache-2.0) — Google / Khronos Group.

### NPM Dependencies (Build & Development)
Resolved in `package-lock.json`:
- [`electron`](https://www.npmjs.com/package/electron) (`45.3.4`, `MIT`) — Electron maintainers
- [`@electron/get`](https://www.npmjs.com/package/@electron/get) (`5.1.0`, `MIT`) — Electron maintainers
- [`@electron-internal/extract-zip`](https://www.npmjs.com/package/@electron-internal/extract-zip) (`1.0.8`, `MIT`) — Electron maintainers
- [`@types/node`](https://www.npmjs.com/package/@types/node) (`24.19.2`, `MIT`) — DefinitelyTyped contributors
- [`undici`](https://www.npmjs.com/package/undici) (`7.30.2`, `MIT`) & [`undici-types`](https://www.npmjs.com/package/undici-types) (`7.24.6`, `MIT`) — Node.js / Undici contributors
- [`semver`](https://www.npmjs.com/package/semver) (`7.8.6`, `ISC`) — npm, Inc. & contributors
- [`debug`](https://www.npmjs.com/package/debug) (`4.4.3`, `MIT`) & [`ms`](https://www.npmjs.com/package/ms) (`2.1.3`, `MIT`) — TJ Holowaychuk, Josh Junon & contributors
- [`env-paths`](https://www.npmjs.com/package/env-paths) (`3.0.0`, `MIT`) — Sindre Sorhus
- [`graceful-fs`](https://www.npmjs.com/package/graceful-fs) (`4.2.12`, `BlueOak-1.0.0`) — Isaac Z. Schlueter & contributors
- [`sumchecker`](https://www.npmjs.com/package/sumchecker) (`3.0.1`, `Apache-2.0`) — Mark Lee & contributors
- [`progress`](https://www.npmjs.com/package/progress) (`2.0.3`, `MIT`) — TJ Holowaychuk & contributors

### Icon Generation, Packaging & Linux Desktop Integration
- **[Python 3](https://www.python.org/)** (PSF License) & **[Pillow (PIL)](https://python-pillow.org/)** (HPND License) — Used by `generate_icons.py` to produce RGBA multi-resolution PNG icons.
- **[librsvg (`rsvg-convert`)](https://gitlab.gnome.org/GNOME/librsvg)** (LGPL-2.1+) — GNOME Project, used to rasterize `assets/icon.svg` across `16×16` through `512×512` (with optional fallback to headless Chromium).
- **[GNU Bash](https://www.gnu.org/software/bash/)**, **[GNU Tar](https://www.gnu.org/software/tar/)**, **[GNU Gzip](https://www.gnu.org/software/gzip/)**, **[GNU Coreutils](https://www.gnu.org/software/coreutils/)** (`sha256sum`, `mktemp`, `tail`), and **AWK** (GPL-3.0+) — Power the self-extracting `.run` installer, integrity verification, and portable `.tar.gz` packaging.
- **[freedesktop.org](https://www.freedesktop.org/) Desktop Integration** (`desktop-file-utils`, `xdg-utils`, `hicolor-icon-theme`) & **[GTK](https://www.gtk.org/)** (`gtk-update-icon-cache`) — Application menu entry, validation, and icon theme integration across Linux desktops.
- **[KDE Frameworks](https://develop.kde.org/products/frameworks/)** (`kbuildsycoca6` / `kbuildsycoca5`, LGPL-2.1+) — Desktop service cache refresh on KDE Plasma.
- **[Git](https://git-scm.com/)** (GPL-2.0) & **[GitHub CLI (`gh`)](https://cli.github.com/)** (`2.104.0`, MIT License) — Version control and release publishing.

