'use strict';

const {
  app,
  BrowserWindow,
  Menu,
  Tray,
  clipboard,
  screen,
  session,
  shell,
} = require('electron');
const fs = require('fs');
const path = require('path');

const NOTEBOOKLM_URL = 'https://notebooklm.google.com';
const ACCOUNT_CHOOSER_URL =
  'https://accounts.google.com/AccountChooser?continue=' +
  encodeURIComponent(NOTEBOOKLM_URL);
const APP_NAME = 'NotebookLM';
const PROFILE_DIR_NAME = 'notebooklm-desktop';
const DESKTOP_FILE = 'notebooklm-desktop.desktop';

const INTERNAL_HOST_ALLOWLIST = new Set([
  'notebooklm.google.com',
  'accounts.google.com',
  'accounts.youtube.com',
  'myaccount.google.com',
  'content.googleapis.com',
  'drive.google.com',
  'docs.google.com',
  'gstatic.com',
  'oauth-redirect.googleusercontent.com',
]);

// Configure sandbox, process model, Linux/Wayland identity, and User-Agent before ready.
app.enableSandbox();
app.commandLine.appendSwitch('process-per-site');
app.commandLine.appendSwitch('ozone-platform-hint', 'auto');
app.setName(APP_NAME);
app.setPath('userData', path.join(app.getPath('appData'), PROFILE_DIR_NAME));
if (process.platform === 'linux' && typeof app.setDesktopName === 'function') {
  app.setDesktopName(DESKTOP_FILE);
}

app.userAgentFallback = `${app.userAgentFallback.replace(/Electron\/[0-9.]+\s/, '')} GeminiWindowsApp/1.15.0 (prod)`;

const gotSingleInstanceLock = app.requestSingleInstanceLock();
if (!gotSingleInstanceLock) {
  app.quit();
}

let mainWindow = null;
let tray = null;
let isQuitting = false;

const userDataPath = app.getPath('userData');
const windowStatePath = path.join(userDataPath, 'window-state.json');
const settingsPath = path.join(userDataPath, 'settings.json');

let settings = {
  minimizeToTray: true,
};

function readJsonSafe(filePath, fallback) {
  try {
    if (fs.existsSync(filePath)) {
      const raw = fs.readFileSync(filePath, 'utf8');
      return { ...fallback, ...JSON.parse(raw) };
    }
  } catch {
    // Ignore malformed config files and fall back to defaults.
  }
  return { ...fallback };
}

function writeJsonSafe(filePath, data) {
  try {
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
  } catch {
    // Non-fatal persistence error.
  }
}

function loadSettings() {
  settings = readJsonSafe(settingsPath, { minimizeToTray: true });
}

function saveSettings() {
  writeJsonSafe(settingsPath, settings);
}

function isRectOnAnyDisplay(bounds) {
  if (
    typeof bounds.x !== 'number' ||
    typeof bounds.y !== 'number' ||
    typeof bounds.width !== 'number' ||
    typeof bounds.height !== 'number'
  ) {
    return false;
  }

  return screen.getAllDisplays().some((display) => {
    const area = display.workArea;
    return (
      bounds.x < area.x + area.width - 60 &&
      bounds.x + bounds.width > area.x + 60 &&
      bounds.y < area.y + area.height - 60 &&
      bounds.y + bounds.height > area.y + 60
    );
  });
}

function loadWindowState() {
  const defaults = {
    width: 1280,
    height: 840,
    isMaximized: false,
  };
  const state = readJsonSafe(windowStatePath, defaults);

  if (typeof state.width !== 'number' || state.width < 480) {
    state.width = defaults.width;
  }
  if (typeof state.height !== 'number' || state.height < 360) {
    state.height = defaults.height;
  }
  if (!isRectOnAnyDisplay(state)) {
    delete state.x;
    delete state.y;
  }
  return state;
}

function saveWindowState() {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  const isMaximized = mainWindow.isMaximized();
  const previous = loadWindowState();
  const bounds = isMaximized
    ? {
        x: previous.x,
        y: previous.y,
        width: previous.width,
        height: previous.height,
      }
    : mainWindow.getBounds();

  writeJsonSafe(windowStatePath, {
    ...bounds,
    isMaximized,
  });
}

function isInternalPopupUrl(rawUrl) {
  if (!rawUrl || rawUrl === 'about:blank') return true;
  try {
    const parsed = new URL(rawUrl);
    if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
      return false;
    }
    return INTERNAL_HOST_ALLOWLIST.has(parsed.hostname);
  } catch {
    return false;
  }
}

function isSafeExternalUrl(rawUrl) {
  try {
    const parsed = new URL(rawUrl);
    return parsed.protocol === 'https:' || parsed.protocol === 'http:';
  } catch {
    return false;
  }
}

function goBack(webContents) {
  if (!webContents) return;
  if (webContents.navigationHistory && webContents.navigationHistory.canGoBack()) {
    webContents.navigationHistory.goBack();
  } else if (webContents.canGoBack()) {
    webContents.goBack();
  }
}

function goForward(webContents) {
  if (!webContents) return;
  if (webContents.navigationHistory && webContents.navigationHistory.canGoForward()) {
    webContents.navigationHistory.goForward();
  } else if (webContents.canGoForward()) {
    webContents.goForward();
  }
}

function canGoBack(webContents) {
  if (!webContents) return false;
  if (webContents.navigationHistory) {
    return webContents.navigationHistory.canGoBack();
  }
  return webContents.canGoBack();
}

function canGoForward(webContents) {
  if (!webContents) return false;
  if (webContents.navigationHistory) {
    return webContents.navigationHistory.canGoForward();
  }
  return webContents.canGoForward();
}

function showAndFocusWindow() {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  if (mainWindow.isMinimized()) {
    mainWindow.restore();
  }
  if (!mainWindow.isVisible()) {
    mainWindow.show();
  }
  mainWindow.focus();
}

function toggleWindowFromTray() {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  if (mainWindow.isVisible() && !mainWindow.isMinimized() && mainWindow.isFocused()) {
    mainWindow.hide();
  } else {
    showAndFocusWindow();
  }
}

function toggleWindowAction() {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  if (mainWindow.isVisible() && !mainWindow.isMinimized()) {
    mainWindow.hide();
  } else {
    showAndFocusWindow();
  }
}

function attachContextMenu(webContents) {
  webContents.on('context-menu', (_event, params) => {
    const menuItems = [];

    if (params.linkURL && isSafeExternalUrl(params.linkURL)) {
      menuItems.push(
        {
          label: 'Open Link in Default Browser',
          click: () => shell.openExternal(params.linkURL),
        },
        {
          label: 'Copy Link Address',
          click: () => clipboard.writeText(params.linkURL),
        },
        { type: 'separator' }
      );
    }

    if (params.isEditable) {
      menuItems.push(
        { label: 'Cut', role: 'cut', enabled: params.editFlags.canCut },
        { label: 'Copy', role: 'copy', enabled: params.editFlags.canCopy },
        { label: 'Paste', role: 'paste', enabled: params.editFlags.canPaste },
        { label: 'Select All', role: 'selectAll', enabled: params.editFlags.canSelectAll }
      );
    } else if (params.selectionText) {
      menuItems.push(
        { label: 'Copy', role: 'copy' },
        { label: 'Select All', role: 'selectAll' }
      );
    } else {
      menuItems.push({ label: 'Select All', role: 'selectAll' });
    }

    menuItems.push(
      { type: 'separator' },
      {
        label: 'Back',
        enabled: canGoBack(webContents),
        click: () => goBack(webContents),
      },
      {
        label: 'Forward',
        enabled: canGoForward(webContents),
        click: () => goForward(webContents),
      },
      {
        label: 'Reload',
        click: () => webContents.reload(),
      }
    );

    Menu.buildFromTemplate(menuItems).popup({
      window: BrowserWindow.fromWebContents(webContents) || mainWindow,
    });
  });
}

function switchAccount() {
  showAndFocusWindow();
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.loadURL(ACCOUNT_CHOOSER_URL);
  }
}

async function resetSession() {
  await session.defaultSession.clearStorageData({
    storages: ['cookies', 'localstorage', 'serviceworkers', 'cachestorage'],
  });
  showAndFocusWindow();
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.loadURL(NOTEBOOKLM_URL);
  }
}

function configureWebContents(webContents) {
  attachContextMenu(webContents);

  webContents.setWindowOpenHandler(({ url }) => {
    if (isInternalPopupUrl(url)) {
      return {
        action: 'allow',
        overrideBrowserWindowOptions: {
          width: 960,
          height: 740,
          autoHideMenuBar: true,
          backgroundColor: '#131314',
          icon: path.join(__dirname, 'assets', 'icon.png'),
          webPreferences: {
            contextIsolation: true,
            nodeIntegration: false,
            sandbox: true,
            spellcheck: true,
          },
        },
      };
    }

    if (isSafeExternalUrl(url)) {
      shell.openExternal(url);
    }
    return { action: 'deny' };
  });

  webContents.on('did-create-window', (childWindow) => {
    childWindow.setAutoHideMenuBar(true);
    childWindow.setMenuBarVisibility(false);
    configureWebContents(childWindow.webContents);
  });
}

function buildApplicationMenu() {
  const template = [
    {
      label: 'File',
      submenu: [
        {
          label: 'NotebookLM Home',
          accelerator: 'Alt+Home',
          click: () => {
            if (mainWindow && !mainWindow.isDestroyed()) {
              mainWindow.loadURL(NOTEBOOKLM_URL);
            }
          },
        },
        {
          label: 'Switch Account',
          click: () => switchAccount(),
        },
        {
          label: 'Sign Out / Reset Session',
          click: () => {
            void resetSession();
          },
        },
        { type: 'separator' },
        {
          label: 'Quit NotebookLM',
          accelerator: 'CommandOrControl+Q',
          click: () => {
            isQuitting = true;
            app.quit();
          },
        },
      ],
    },
    {
      label: 'Edit',
      submenu: [
        { role: 'undo' },
        { role: 'redo' },
        { type: 'separator' },
        { role: 'cut' },
        { role: 'copy' },
        { role: 'paste' },
        { role: 'selectAll' },
      ],
    },
    {
      label: 'Navigation',
      submenu: [
        {
          label: 'Back',
          accelerator: 'Alt+Left',
          click: () => {
            if (mainWindow && !mainWindow.isDestroyed()) {
              goBack(mainWindow.webContents);
            }
          },
        },
        {
          label: 'Forward',
          accelerator: 'Alt+Right',
          click: () => {
            if (mainWindow && !mainWindow.isDestroyed()) {
              goForward(mainWindow.webContents);
            }
          },
        },
        {
          label: 'NotebookLM Home',
          click: () => {
            if (mainWindow && !mainWindow.isDestroyed()) {
              mainWindow.loadURL(NOTEBOOKLM_URL);
            }
          },
        },
      ],
    },
    {
      label: 'View',
      submenu: [
        {
          label: 'Reload',
          accelerator: 'CommandOrControl+R',
          click: () => {
            if (mainWindow && !mainWindow.isDestroyed()) {
              mainWindow.webContents.reload();
            }
          },
        },
        {
          label: 'Reload (F5)',
          accelerator: 'F5',
          visible: false,
          click: () => {
            if (mainWindow && !mainWindow.isDestroyed()) {
              mainWindow.webContents.reload();
            }
          },
        },
        {
          label: 'Force Reload',
          accelerator: 'CommandOrControl+Shift+R',
          click: () => {
            if (mainWindow && !mainWindow.isDestroyed()) {
              mainWindow.webContents.reloadIgnoringCache();
            }
          },
        },
        { type: 'separator' },
        { role: 'zoomIn' },
        { role: 'zoomOut' },
        { role: 'resetZoom' },
        { type: 'separator' },
        {
          label: 'Toggle Fullscreen',
          accelerator: 'F11',
          click: () => {
            if (mainWindow && !mainWindow.isDestroyed()) {
              mainWindow.setFullScreen(!mainWindow.isFullScreen());
            }
          },
        },
        {
          label: 'Toggle Developer Tools',
          accelerator: 'CommandOrControl+Shift+I',
          click: () => {
            if (mainWindow && !mainWindow.isDestroyed()) {
              mainWindow.webContents.toggleDevTools();
            }
          },
        },
      ],
    },
  ];

  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

function updateTrayMenu() {
  if (!tray) return;
  const alwaysOnTop = mainWindow && !mainWindow.isDestroyed() ? mainWindow.isAlwaysOnTop() : false;

  const contextMenu = Menu.buildFromTemplate([
    {
      label: 'Show / Hide NotebookLM',
      click: () => toggleWindowAction(),
    },
    {
      label: 'NotebookLM Home',
      click: () => {
        showAndFocusWindow();
        if (mainWindow && !mainWindow.isDestroyed()) {
          mainWindow.loadURL(NOTEBOOKLM_URL);
        }
      },
    },
    {
      label: 'Reload',
      click: () => {
        if (mainWindow && !mainWindow.isDestroyed()) {
          mainWindow.webContents.reload();
        }
      },
    },
    { type: 'separator' },
    {
      label: 'Switch Account',
      click: () => switchAccount(),
    },
    {
      label: 'Sign Out / Reset Session',
      click: () => {
        void resetSession();
      },
    },
    { type: 'separator' },
    {
      label: 'Minimize to Tray on Close',
      type: 'checkbox',
      checked: Boolean(settings.minimizeToTray),
      click: (menuItem) => {
        settings.minimizeToTray = menuItem.checked;
        saveSettings();
        updateTrayMenu();
      },
    },
    {
      label: 'Always on Top',
      type: 'checkbox',
      checked: alwaysOnTop,
      click: (menuItem) => {
        if (mainWindow && !mainWindow.isDestroyed()) {
          mainWindow.setAlwaysOnTop(menuItem.checked);
        }
        updateTrayMenu();
      },
    },
    { type: 'separator' },
    {
      label: 'Quit NotebookLM',
      click: () => {
        isQuitting = true;
        app.quit();
      },
    },
  ]);

  tray.setContextMenu(contextMenu);
}

function createTray() {
  const trayIconPath = path.join(__dirname, 'assets', 'tray-icon.png');
  tray = new Tray(trayIconPath);
  tray.setToolTip('NotebookLM');
  updateTrayMenu();

  tray.on('click', () => {
    toggleWindowFromTray();
  });
}

function createMainWindow() {
  const windowState = loadWindowState();

  mainWindow = new BrowserWindow({
    title: 'NotebookLM',
    width: windowState.width,
    height: windowState.height,
    x: windowState.x,
    y: windowState.y,
    minWidth: 640,
    minHeight: 480,
    icon: path.join(__dirname, 'assets', 'icon.png'),
    autoHideMenuBar: true,
    backgroundColor: '#131314',
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: true,
    },
  });

  if (windowState.isMaximized) {
    mainWindow.maximize();
  }

  configureWebContents(mainWindow.webContents);

  let saveTimer = null;
  const scheduleSaveWindowState = () => {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(saveWindowState, 250);
  };

  mainWindow.on('resize', scheduleSaveWindowState);
  mainWindow.on('move', scheduleSaveWindowState);

  mainWindow.on('close', (event) => {
    saveWindowState();
    if (!isQuitting && settings.minimizeToTray) {
      event.preventDefault();
      mainWindow.hide();
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  mainWindow.loadURL(NOTEBOOKLM_URL);
}

if (gotSingleInstanceLock) {
  app.on('second-instance', (_event, argv) => {
    if (argv.includes('--quit')) {
      isQuitting = true;
      app.quit();
      return;
    }

    if (!mainWindow || mainWindow.isDestroyed()) return;

    if (argv.includes('--toggle')) {
      toggleWindowAction();
    } else {
      showAndFocusWindow();
    }
  });

  app.on('before-quit', () => {
    isQuitting = true;
    saveWindowState();
  });

  app.on('window-all-closed', () => {
    if (process.platform !== 'darwin' && (!settings.minimizeToTray || isQuitting)) {
      app.quit();
    }
  });

  app.on('activate', () => {
    if (!mainWindow || mainWindow.isDestroyed()) {
      createMainWindow();
    } else {
      showAndFocusWindow();
    }
  });

  app.whenReady().then(() => {
    if (process.argv.includes('--quit')) {
      isQuitting = true;
      app.quit();
      return;
    }

    loadSettings();
    buildApplicationMenu();
    createMainWindow();
    createTray();
  });
}
