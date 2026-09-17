const { app, BrowserWindow, dialog, ipcMain } = require('electron');
const path = require('node:path');
const listDisks = require('../disk/list');

const isRoot = typeof process.getuid !== 'function' || process.getuid() === 0;

function createWindow() {
  const window = new BrowserWindow({
    width: 1100,
    height: 760,
    minWidth: 900,
    minHeight: 620,
    center: true,
    frame: false,
    resizable: true,
    backgroundColor: '#202225',
    autoHideMenuBar: true,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  window.center();
  window.once('ready-to-show', () => {
    window.show();
    window.maximize();
    window.focus();
  });
  window.loadFile(path.join(__dirname, 'index.html'));
}

ipcMain.handle('system:is-root', () => isRoot);
ipcMain.handle('system:list-block-devices', async () => listDisks());
ipcMain.handle('window:return-to-os', (event) => {
  BrowserWindow.fromWebContents(event.sender)?.destroy();
});
ipcMain.handle('installer:execute', async (_event, payload) => ({
  ok: false,
  pending: true,
  message: 'The disk-writing backend is intentionally gated while the installer pages are being tested.',
  payload,
}));

app.whenReady().then(async () => {
  if (!isRoot) {
    await dialog.showMessageBox({
      type: 'error',
      title: 'Install Ubuntu Meep',
      message: 'Install Ubuntu Meep must be run as root.',
      detail: 'Launch it from the menu with administrator privileges, or run: sudo npm start',
    });
    app.quit();
    return;
  }
  createWindow();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
