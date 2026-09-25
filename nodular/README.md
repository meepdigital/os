# Nodular

A native X11 window manager with an Electron taskbar. JavaScript source and
webpack output use ES modules. Run commands below from this directory.

## Setup and local desktop testing

```bash
bash sh/xephyr_install
npm install
./sh/start
```

The Ubuntu installer needs sudo and installs Xephyr, X11 headers, PHP/Composer,
and desktop runtime dependencies. Use Node.js 22.22.2+, 24.15.0+, or 26+ (matching node-gyp's supported versions). Run npm as your normal user.
It does not change your display manager or install Nodular as your login session.

The repository-root `.env` sets `NODULAR_ELECTRON_NO_SANDBOX=1` for this
development host. You can also set it explicitly:

```bash
NODULAR_ELECTRON_NO_SANDBOX=1 ./sh/xephyr_init
```

This disables Chromium's sandbox for that test instance. Xephyr separates window
management, not filesystem access or user privileges. Test applications still
have access to your files. No host security settings are changed.

`sh/xephyr_init` automatically allocates a display with Xauthority authentication,
disables TCP listening and host keyboard grabs, and creates a separate D-Bus
session and temporary XDG config/cache/data/runtime directories. Closing Xephyr
or pressing Ctrl+C stops the session. The original desktop remains on its display.
The fixed window uses 90% of the primary monitor width and 80% of its height,
capped at 1600x1000 (1152x576 on the current 1280x720 host). Fixed sizing matches
the window manager's current lack of resize handling. Override with:

```bash
NODULAR_XEPHYR_SIZE=1024x600 ./sh/xephyr_init
```

`./sh/start` runs nodemon using `nodemon.json`. On startup and after watched
changes it runs `npm run build`, then starts a fresh Xephyr session. A failed
build prevents launch; nodemon waits for the next edit. Sources, templates,
`src/extensions/**/*.php`, scripts, configuration, and the repository `.env` are watched;
`build/`, `tmp/`, dependencies, and PHP vendor files are ignored. Ctrl+C stops
the watcher and desktop. `./sh/xephyr_init` launches once without watching.
There is no npm `start` script. `NODULAR_ELECTRON`
can select another Electron executable; `NODULAR_BACKGROUND` selects wallpaper.

## Build and modules

- `binding.gyp` builds only `src/native/x11wm.cpp` into `build/Release/x11wm.node`.
  `sh/build` runs Twig setup, node-gyp configure/build, then webpack.
  It uses Node-API, with the blocking X11 loop running in its own Node process.
- `webpack.config.js` builds the renderer `app`, Electron `main`, preload,
  session, and WM entry points into `build/js/*.mjs`. `main.mjs` injects the
  rendered layout; `app.mjs` is the JavaScript loaded by that layout.
- `src/js/components/window.js` exports `X11Window` (list/focus/closeFocused/
  launchTerminal) and the socket `command()` helper. Sessions allocate private
  sockets, so concurrent nested desktops do not share `/tmp/nodular.sock`.

The native manager creates one X11 frame window for each managed client. It
reparents the client into that frame, draws a small titlebar, handles titlebar
focus and dragging, and keeps the client window ID as the stable identifier
returned through the JavaScript socket API. JavaScript and future plugins can
therefore control native clients without drawing overlays over them. The
initial decoration model intentionally does not include compositing, animated
effects, workspaces, or advanced resize behavior.

```js
import { native } from './src/js/core/native.js';
const x11 = await native('x11wm'); // build/Release/x11wm.node
// x11.run() is blocking: invoke it only in the dedicated WM process.

import { render, interpret } from './src/js/core/twig.js';
const html = await render('layout', {
  stylesheet: 'file:///path/to/style.css',
  script: 'file:///path/to/app.mjs',
});
const output = await interpret('example', { test: true });
```

`render('example', context)` renders `src/templates/example.html.twig`.
`interpret('example', context)` renders `src/templates/example.js.twig`, writes a
unique `tmp/<uuid>.js`, imports it as an ES module, and returns its default export
(or the module namespace when it has only named exports). Both are asynchronous.
Generated files stay available for inspection. Only interpret trusted templates.
For example, `src/templates/example.js.twig` can contain:

```twig
export default {{ test|json_encode|raw }};
```

Template variables come from the context argument. HTML templates are escaped;
use `json_encode|raw` for values embedded in generated JS. Invalid slugs, missing
templates, Twig errors, and JavaScript errors reject or throw instead of silently
returning an error page.

`node-twig` is the Node rendering API. Its published PHP bridge targets obsolete
Twig 1; the executable Node script `sh/twig_setup` installs the locked Twig 3
dependencies and renders `src/templates/twig.php.twig` into
`node_modules/node-twig/php/Twig.php`. It bootstraps using PHP Twig directly so
it works even before the node-twig bridge exists. This happens during
`npm install`/`npm ci` and `npm run build`. PHP extensions under `src/extensions/**/*.php`
are loaded recursively in sorted order for both rendering helpers. `composer.lock` pins the PHP runtime. An npm override keeps
`exec-php`'s temporary-file dependency current.

## Verification

```bash
npm run check
```

Tests exercise HTML escaping, context values, generated ES module exports,
syntax/missing-template failures, invalid paths, and loading the native addon.
The native build requires X11 development headers. The committed legacy
`build/` runtime is retained for existing repository provisioning; this new
source/build workflow uses `build/Release` and `build/js` and does not update
that older deployment layout.

## Environment values

Dotenv loads `../.env` (the repository root) independently of the working directory.
The Node build script and JavaScript entrypoints load it directly. Xephyr
reads its size setting through the same dotenv module. Values are available as `process.env.KEY`
or through the `env` export from `src/js/core/env.js`. Existing shell values take
precedence, so `NODULAR_ELECTRON_NO_SANDBOX=0 ./sh/xephyr_init` restores the default
Electron sandbox behavior.

Webpack embeds the configured keys as build defaults in each entrypoint. At
runtime, the repository `.env` can update those defaults; explicit process values
still win. Only keys from `.env` are captured, not unrelated host environment
variables. Rebuild to refresh the embedded defaults.

Both Twig helpers inject the same values under the reserved `env` local:

```twig
{{ env.NODULAR_ELECTRON_NO_SANDBOX }}
```

For JavaScript templates, use `{{ env.KEY|json_encode|raw }}`. The `env` local is
injected automatically even when the caller supplies no template context.

## Styles and application layout

`layout.html.twig` is the application document. It loads `build/assets/style.css`
once and includes `components/navbar.html.twig` as a markup-only partial.
Bootstrap v5.3.8 source is cloned from https://github.com/twbs/bootstrap into
`src/assets/bootstrap`; `src/assets/style.scss` imports Bootstrap and Font Awesome once,
followed by custom SCSS from `src/assets/scss`. The Font Awesome webfonts are copied
beside the CSS bundle so its relative URLs remain valid. `npm run build` compiles
the stylesheet, and `sh/start` watches asset changes and runs that same full
build before restarting Xephyr.

The compiler is maintained Dart Sass (`sass`): archived `node-sass` does not
support this project's Node 26 runtime. If restoring the source clone separately:

```bash
git clone --depth 1 --branch v5.3.8 https://github.com/twbs/bootstrap.git src/assets/bootstrap
```

Nested Terminal controls and Super+Enter open a fresh xterm on the nested display.
Close flushes its X11 request immediately. The session defaults to the repository
`src/assets/bg.svg` when that file exists; set `NODULAR_BACKGROUND` to select another wallpaper.

DevTools are enabled for the taskbar renderer. Press F12 or Ctrl+Shift+I while
the Nodular window is focused to toggle them, or set `NODULAR_DEVTOOLS=1` in the
repository `.env` to open them automatically at startup.
