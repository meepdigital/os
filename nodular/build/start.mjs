import { spawn } from 'node:child_process';
import { dirname, join } from 'node:path';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const wm = spawn(join(root, 'nodular-wm'), [], { stdio: 'inherit' });
const bundledElectron = join(root, 'electron-dist', 'electron');
const electron = process.env.NODULAR_ELECTRON
  || (existsSync(bundledElectron) ? bundledElectron : '/usr/local/lib/node_modules/electron/dist/electron');
const shell = spawn(electron, [join(root, 'shell/main.mjs')], {
  stdio: 'inherit',
  env: { ...process.env, NODULAR_WM_SOCKET: '/tmp/nodular.sock' },
});

const stop = (signal) => {
  wm.kill(signal);
  shell.kill(signal);
};
process.on('SIGINT', () => stop('SIGINT'));
process.on('SIGTERM', () => stop('SIGTERM'));
shell.on('exit', (code) => {
  if (wm.exitCode === null) wm.kill('SIGTERM');
  process.exit(code ?? 0);
});
