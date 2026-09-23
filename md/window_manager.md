# Five Node.js desktop strategies

The source discussion in `nodejs.md` points to Node as an orchestration layer, with X11 as the first-class Ubuntu Cinnamon target and compositor-specific adapters for Wayland. The external Meep user session is assumed to have already authenticated.

1. **Node shell over Cinnamon/Muffin.** Keep Cinnamon and Muffin as the real desktop, and run a Node daemon that owns a panel applet, taskbar menu, control-panel web views, and applet APIs. Use `wmctrl`, `xdotool`, XRandR, X properties, and `node-x11` through small adapters. This is the smallest migration path and preserves the working desktop.
2. **Electron shell with native helpers.** Use a frameless Electron window for the panel, launcher, settings, and window-control surfaces. Use Bootstrap and jQuery in renderer pages, IPC in preload, and narrowly scoped Node child processes for X11. Compile privileged or latency-sensitive pieces with node-gyp as `.node` addons, never as arbitrary renderer code.
3. **Node compositor companion.** Write a lightweight Node session service that exposes a stable `desktop.windows`, `desktop.input`, `desktop.workspaces`, and `desktop.events` API. The Cinnamon panel remains visible while Meep components consume the API. Add X11, Sway, GNOME, and KDE backends so the public API does not depend on one display server.
4. **Web-based control plane.** Run one local Node service with a Unix-socket control API and render its Bootstrap/jQuery control panel in a dedicated browser or Electron shell. A taskbar client subscribes to window events, applets register routes, and system actions require PolicyKit authorization. This is easy to test and keeps UI modules separate.
5. **Minimal custom session.** Replace the desktop shell only after the first four approaches are proven: Node owns panel, task switcher, workspace model, applets, and window policy, while X11 remains the server. Bundle only the required V8/Electron runtime, `node-gyp`, Python, a C/C++ toolchain for builds, and prebuilt native addons for production. Keep a recovery session and do not let a broken addon prevent login.

## Shared implementation rules

- Prefer one long-lived Node daemon over one Node process per applet.
- Use Bootstrap Sass only at build time, jQuery for DOM/event glue, and plain HTML for simple pages.
- Put X11 or compositor code behind capability-tested adapters; Wayland does not permit unrestricted global input/window control.
- Keep native addons small: window enumeration, event watches, uinput or portal bridges, filesystem watchers, and compression are reasonable boundaries.
- Pin Node/Electron ABI-compatible builds and rebuild `.node` artifacts for every target Electron version with `node-gyp rebuild`.
- Store user-facing state in a versioned local database and keep secrets in the system keyring, not JavaScript config files.

