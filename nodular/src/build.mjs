import { cp, mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);
const source = dirname(fileURLToPath(import.meta.url));
const root = resolve(source, '..');
const build = join(root, 'build');
const bootstrap = process.env.NODULAR_BOOTSTRAP || '/node_modules/bootstrap/dist/css/bootstrap.min.css';
const fontAwesome = join(source, 'node_modules/@fortawesome/fontawesome-free');

await mkdir(build, { recursive: true });
await execFileAsync('g++', [
  '-std=c++17', '-O2', '-Wall', '-Wextra', '-pedantic',
  join(source, 'x11wm.cpp'), '-lX11', '-o', join(build, 'nodular-wm'),
]);

for (const file of ['start.mjs', 'nodular.desktop', 'install-ubuntu-meep.sh', 'shell/main.mjs', 'shell/preload.mjs', 'shell/navbar.html']) {
  const destination = join(build, file);
  await mkdir(dirname(destination), { recursive: true });
  await cp(join(source, file), destination);
}
await cp(bootstrap, join(build, 'bootstrap.min.css'));
await cp(join(fontAwesome, 'css/all.min.css'), join(build, 'fontawesome/css/all.min.css'));
await cp(join(fontAwesome, 'webfonts'), join(build, 'fontawesome/webfonts'), { recursive: true });
await writeFile(join(build, 'BUILD.json'), JSON.stringify({
  name: 'nodular',
  renderer: 'Electron / Chromium / Blink / V8',
  windowManager: 'native X11 C++',
  bootstrap: '5.x',
  fontAwesome: '@fortawesome/fontawesome-free',
}, null, 2) + '\n');
console.log(`Built Nodular in ${build}`);
