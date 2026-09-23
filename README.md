# Ubuntu Meep

Ubuntu Meep turns an existing Ubuntu installation into a Meep workstation. The repository contains system provisioning scripts, the Nodular desktop, and a graphical installer.

Nodular is Meep's lightweight X11 desktop. It combines a native window manager with an Electron panel for the application launcher, terminal controls, and basic window status. It is designed to provide a small, predictable desktop for Meep.

Node.js is used where fast iteration and Electron's desktop ecosystem help: Electron provides the panel window, JavaScript handles panel and application actions, and Twig renders the panel layout. The window manager remains a small native C++/X11 addon so it can own and arrange X11 windows directly. Node.js also coordinates the window manager and panel.

## Build Nodular

Run from the repository root:

```bash
bash nodular/sh/xephyr_install
npm --prefix nodular ci
npm --prefix nodular run build
```

The dependency script installs packages needed for X11 testing, native compilation, PHP/Twig, and Electron. Nodular supports Node.js 22.22.2, 24.15.0, or 26 and newer.

The build creates the native addon, JavaScript bundles, compiled CSS, and desktop runtime files under `nodular/build/`. To try the desktop in a nested test display:

```bash
npm --prefix nodular run xephyr
```

For an edit-and-restart development loop:

```bash
nodular/sh/start
```

Xephyr is only the local test display; the installed desktop runs as a normal X11 session through LightDM.

## Install Nodular on Ubuntu

Build Nodular first, then provision the target system:

```bash
sudo ./sh/install
```

Provisioning installs LightDM, Xorg, and runtime dependencies, removes competing window managers and Wayland sessions, installs the built Nodular runtime under `/usr/local/lib/nodular`, registers `nodular.desktop`, and selects Nodular as the default X11 session. It installs `/usr/local/bin/nodular-session`, which starts the window manager and Electron panel together.

The provisioning script expects the current build and dependencies; it does not compile Nodular for you:

```bash
npm --prefix nodular ci
npm --prefix nodular run build
sudo ./sh/install
```

Use `sudo ./sh/install --minimal` for the reduced package set. Use `sudo ./sh/install --boot-only` for only Plymouth and graphical-installer boot integration.

Provisioning changes the current root filesystem, package set, display manager, login sessions, and boot configuration. Run it on the intended Ubuntu installation or an explicitly prepared target root.

## Using the desktop

Nodular provides a bottom panel. Its launcher opens Files, Terminal, and Web Browser actions. The panel shows the number of managed windows and provides Terminal and Close controls.

- Super+Enter opens a terminal.
- Super+Q closes the focused managed window.

The desktop is intentionally small: it provides X11 window management and the panel, without Wayland support, workspaces, or a full desktop-application menu.

## Graphical installer

The separate `installer/` application uses Electron, AngularJS, Bootstrap, and webpack. Its flow is:

```text
Start → Keyboard → Disks → Drivers → Review
```

It can inspect disks and drivers, but the final disk-writing action is gated and does not partition or write a disk.

```bash
npm --prefix installer ci
npm --prefix installer run build
sudo npm --prefix installer start
```

## Provisioning behavior

`sh/install` runs:

```text
setup → base → npm → repo → core → spotify → teams → go → firewall
→ php → mysql → nodular → purge → boot → appearance → design → snap
```

Successful package phases are checkpointed under `/var/lib/ubuntu-meep/provisioning`. Output is written to `meep.log` beside this README and shown in the terminal. Package downloads are cached under `/var/cache/ubuntu-meep`; `MEEP_STATE_DIR` and `MEEP_CACHE_DIR` can override those locations.

Minimal mode skips optional repositories, applications, language stacks, databases, cleanup, appearance, and Snap phases. Provisioning uses a lock and refuses recursive runs.

## Repository layout

```text
sh/install                  Ubuntu provisioning entrypoint
sh/_install/                Provisioning phases, including Nodular installation
nodular/src/native/          Native X11 window manager
nodular/src/js/              Electron, session, IPC, and panel code
nodular/src/templates/       Panel templates
nodular/src/assets/          Styles and Bootstrap source
nodular/sh/                  Build, dependency, watcher, and test-display scripts
nodular/test/                Nodular tests
nodular/build/               Generated desktop runtime
installer/                   Graphical installer
assets/                      Shared boot and background assets
md/                          Design notes
```

Generated dependencies, build output, temporary files, and logs are ignored by Git.

## Checks

```bash
npm --prefix nodular run check
npm --prefix installer run lint
bash -n sh/install
bash -n sh/_install/nodular.sh
git diff --check
```

The Nodular tests cover template rendering, generated modules, path validation, layout ownership, and loading the native addon without opening a display. A real desktop test requires X11; the quickest development check is `nodular/sh/start`.
