import { app, BrowserWindow, ipcMain, screen } from 'electron';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import net from 'node:net';

const source = dirname(fileURLToPath(import.meta.url));
const socketPath = process.env.NODULAR_WM_SOCKET || '/tmp/nodular.sock';
let navbar;

function wm(command) {
  return new Promise((resolve, reject) => {
    const connection = net.createConnection(socketPath);
    let response = '';
    connection.on('connect', () => connection.end(`${command}\n`));
    connection.on('data', (chunk) => { response += chunk; });
    connection.on('end', () => resolve(response.trim()));
    connection.on('error', reject);
  });
}

async function createNavbar() {
  const { width, height } = screen.getPrimaryDisplay().workAreaSize;
  navbar = new BrowserWindow({
    width,
    height: 56,
    x: 0,
    y: height - 56,
    frame: false,
    resizable: false,
    movable: false,
    skipTaskbar: true,
    alwaysOnTop: true,
    type: 'dock',
    webPreferences: {
      preload: join(source, 'preload.mjs'),
      contextIsolation: true,
      nodeIntegration: false,
      // Nodular's preload bridge uses ipcRenderer to reach the X11 manager.
      // Keep the renderer unsandboxed until the bridge is moved behind a
      // sandbox-compatible IPC boundary.
      sandbox: false,
    },
  });
  await navbar.loadFile(join(source, 'navbar.html'));
  navbar.setAlwaysOnTop(true, 'floating');
  navbar.setIgnoreMouseEvents(false);
}

app.whenReady().then(createNavbar);
ipcMain.handle('nodular-wm', (_event, command) => wm(command));
app.on('window-all-closed', (event) => event.preventDefault());
