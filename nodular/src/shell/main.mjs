import { app, BrowserWindow, ipcMain, screen } from 'electron';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import net from 'node:net';
import { existsSync } from 'node:fs';
import { spawn } from 'node:child_process';

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
  const panelHeight = 56;
  const overhang = 16;
  navbar = new BrowserWindow({
    width,
    height: panelHeight + overhang + 240,
    x: 0,
    y: height - panelHeight - overhang - 240,
    frame: false,
    transparent: true,
    backgroundColor: '#00000000',
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

function launchApplication(application) {
  const home = process.env.HOME || '/tmp';
  const applications = {
    files: existsSync('/usr/bin/nautilus')
      ? ['/usr/bin/nautilus', ['--new-window', home]]
      : existsSync('/usr/bin/nemo')
        ? ['/usr/bin/nemo', [home]]
        : ['/usr/bin/xdg-open', [home]],
    terminal: ['/usr/bin/x-terminal-emulator', []],
    browser: ['/usr/bin/xdg-open', ['https://www.google.com']],
  };
  const command = applications[application];
  if (!command) throw new Error(`Unknown application: ${application}`);
  const child = spawn(command[0], command[1], { detached: true, stdio: 'ignore' });
  child.unref();
  return 'ok';
}

app.whenReady().then(createNavbar);
ipcMain.handle('nodular-wm', (_event, command) => wm(command));
ipcMain.handle('launch-application', (_event, application) => launchApplication(application));
app.on('window-all-closed', (event) => event.preventDefault());
