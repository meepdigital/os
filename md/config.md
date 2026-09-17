# Programs with configuration under `~/.config`

This inventory was collected from the local user's `~/.config` and lists each top-level application/configuration owner. The lines below each heading are the direct, one-level-deep paths found beneath it; caches and runtime locks are called out where they are useful diagnostically.

### Cinnamon

- `backgrounds/` — desktop background catalog and selections.
- `spices/` — installed Cinnamon applets, desklets, extensions, and themes.
- `cinnamon-monitors.xml` — monitor layout and display geometry.
- `cinnamon-monitors.xml~` — editor backup of the monitor layout.

### Cinnamon session

- `saved-session/` — saved session applications and restart state.

### Cinnamon session terminals

- `X-Cinnamon-xdg-terminals.list` — preferred terminal association.

### Cinnamon menu

- `menus/` — generated application-menu merges and menu overrides.

### Nemo

- `bookmark-metadata` — metadata for bookmarked locations.
- `desktop-metadata` — desktop icon metadata.

### GTK 2

- `gtk-2.0/gtkfilechooser.ini` — GTK2 file chooser preferences.

### GTK 3

- `gtk-3.0/bookmarks` — GTK file chooser bookmarks.
- `gtk-3.0/gtk.css` — user GTK3 CSS overrides.

### GTK 4

- `gtk-4.0/` — GTK4 application and UI preferences.

### D-Bus / dconf

- `dconf/user` — binary desktop settings database.

### Autostart

- `autostart/` — per-user startup launchers, including Caffeine, Guake, Redshift, Easystroke, Stick, and the GitHub runner.

### Browsers: Chrome-family profiles

- `google-chrome/` — Chrome profiles, cookies, history, extensions, preferences, local storage, and browser databases.
- `google-chrome-beta/` — Chrome Beta profile and native-messaging configuration.
- `google-chrome-unstable/` — Chrome Unstable native-messaging and profile configuration.
- `google-chrome-for-testing/` — Chrome for Testing profile and crash/browser state.
- `chromium/` — Chromium native-messaging hosts and browser integration.
- `BraveSoftware/` — Brave browser profiles and browser state.
- `microsoft-edge/` — Edge native-messaging and profile state.
- `opera/` — Opera native-messaging configuration.
- `vivaldi/` — Vivaldi native-messaging configuration.

### Codex

- `Codex/` — the Electron/browser application's profiles, state databases, extensions, safety data, caches, and session metadata.

### Electron

- `Electron/Crashpad/` — Electron crash-reporting state.

### Draft

- `Draft/` — Chromium/Electron profile, cookies, local storage, caches, preferences, and session state for the Draft application.

### Example Com Test

- `Example Com Test/` — Chromium/Electron test profile, cookies, storage, preferences, and caches.

### Example Test

- `Example Test/` — Chromium/Electron test profile, cookies, storage, preferences, and caches.

### Slack

- `Slack/local-settings.json` — Slack local application settings.
- `Slack/storage/` — Slack application storage.
- `Slack/logs/` — local Slack diagnostic logs.
- `Slack/IndexedDB/` — Slack web application database.
- `Slack/Local Storage/` — Slack key/value application state.
- `Slack/Service Worker/` — cached Slack service-worker data.

### Discord

- `discord/settings.json` — Discord client settings.
- `discord/quotes.json` — Discord quote/application data.
- `discord/module_data/` — client modules and module metadata.
- `discord/1.0.154/` — versioned client state.
- `discord/1.0.156/` — versioned client state.
- `discord/installer.db` — Discord installer database.
- `discord/logs/` — client logs.
- `discord/Local Storage/` — client key/value state.
- `discord/IndexedDB/` — client database state.

### Zoom

- `zoom.conf` — Zoom desktop preferences.
- `zoomus.conf` — Zoom/Zoom Meetings preferences.
- `zoom/` — Zoom runtime and single-instance state.

### Trello

- `Trello/config.json` — Trello client configuration.
- `Trello/logs/` — Trello client logs.
- `Trello/Local Storage/` — Trello web application state.
- `Trello/IndexedDB/` — Trello cached application database.

### GitHub

- `GitHub/ActionsService/` — GitHub Actions desktop integration state.

### GitHub application

- `com.github.githubapp/.window-state.json` — window size and position.

### GitHub CLI

- `gh/config.yml` — CLI hosts and user preferences.
- `gh/hosts.yml` — authenticated GitHub host/token metadata; protect this file.

### Git

- `git/ignore` — global Git ignore rules.

### Composer

- `composer/auth.json` — Composer credentials; protect this file.
- `composer/composer.json` — global Composer package configuration.
- `composer/composer.lock` — locked global dependency versions.
- `composer/vendor/` — globally installed Composer packages.

### Node update notifier

- `configstore/update-notifier-@github/` — update-check preferences and timestamps.

### Go

- `go/telemetry` — Go telemetry consent and upload state.

### Python / binwalk

- `binwalk/config` — binwalk configuration.
- `binwalk/magic` — custom magic definitions.
- `binwalk/modules` — binwalk module data.
- `binwalk/plugins` — binwalk plugins.

### Fish

- `fish/completions/` — user Fish shell completions.

### Ruby / Flutter

- `flutter/tool_state` — Flutter tool state.

### acli

- `acli/*_config.yaml` — Atlassian CLI administration, assets, Jira, Confluence, guard, auth, and global settings.

### Audacity

- `audacity/audacity.cfg` — Audacity preferences.
- `audacity/pluginregistry.cfg` — audio plugin registry.
- `audacity/pluginsettings.cfg` — plugin-specific settings.

### GIMP

- `GIMP/2.10/` — GIMP brushes, plug-ins, themes, shortcuts, and preferences.

### Inkscape

- `inkscape/preferences.xml` — Inkscape preferences.
- `inkscape/keys` — keyboard shortcuts.
- `inkscape/themes` — theme data.
- `inkscape/templates` — document templates.
- `inkscape/palettes` — color palettes.
- `inkscape/extensions` — extensions.
- `inkscape/ui` — UI state.
- `inkscape/paint` — paint settings.

### LibreOffice

- `libreoffice/4/` — LibreOffice user profile, extensions, templates, registry, and recovery data.

### Sublime Text

- `sublime-text/Packages/` — installed packages and package settings.
- `sublime-text/Installed Packages/` — packaged extensions.
- `sublime-text/Local/` — sessions and local workspace state.
- `sublime-text/Lib/` — editor libraries.
- `sublime-text/Trash/` — editor recovery/trash data.

### FileZilla

- `filezilla/filezilla.xml` — FileZilla preferences and saved sites.
- `filezilla/sitemanager.xml` — saved site definitions; protect credentials.
- `filezilla/queue.sqlite3` — transfer queue database.
- `filezilla/recentservers.xml` — recent server history.
- `filezilla/layout.xml` — UI layout.

### VirtualBox

- `VirtualBox/VirtualBox.xml` — registered VMs and global settings.
- `VirtualBox/VirtualBox.xml-prev` — previous global settings.
- `VirtualBox/*.log` — VirtualBox service and selector logs.

### Transmission

- `transmission/settings.json` — daemon/client preferences.
- `transmission/torrents/` — torrent metadata.
- `transmission/resume/` — transfer resume state.
- `transmission/blocklists/` — peer blocklists.
- `transmission/bandwidth-groups.json` — bandwidth policies.

### rclone

- `rclone/rclone.conf` — remote definitions and potentially secrets; protect this file.

### VLC

- `vlc/vlcrc` — VLC preferences and hotkeys.
- `vlc/vlc-qt-interface.conf` — Qt interface state.

### Guake

- `guake/session.json` — terminal tabs, profiles, and session layout.

### Redshift

- `redshift.conf` — color-temperature and location settings.

### Evolution / online accounts

- `evolution/sources/` — mail/calendar/contact source definitions.
- `goa-1.0/accounts.conf` — GNOME Online Accounts account metadata.

### File and desktop utilities

- `enchant/` — spelling dictionaries and personal word lists.
- `eog/accels` — Image Viewer shortcuts.
- `gthumb/` — image viewer filters and history.
- `glib-2.0/settings` — GLib application settings.
- `ibus/bus` — input-method bus state.
- `pavucontrol.ini` — PulseAudio volume-control preferences.
- `pulse/cookie` — PulseAudio authentication cookie; protect this file.
- `procps/` — process viewer preferences.
- `simple-update-notifier/nodemon.json` — update-notifier/Nodemon settings.
- `systemd/user/` — per-user systemd units and enablement links.
- `update-notifier/` — update notification state.
- `user-dirs.dirs` — standard user-directory mappings.
- `user-dirs.locale` — user-directory locale.
- `xfce4/xfconf/` — XFCE compatibility settings.
- `yelp/` — Help viewer state.
- `keep/auth.json` — Google Keep helper credentials; protect this file.
- `cubic/cubic.conf` — Cubic image-builder preferences.
- `Thunar/renamerrc` — bulk rename rules.
- `Thunar/uca.xml` — custom Thunar actions.

### Meep installer

- `ubuntu-meep-installer/Crashpad/` — Electron crash-reporting state for the installer.

### Gedit

- `gedit/accels` — editor keyboard accelerators.

### JetBrains

- `JetBrains/PhpStorm2026.2/` — PhpStorm IDE settings, indexes, plugins, and project metadata.

### Android Studio

- `Google/AndroidStudio2026.1.4/` — Android Studio IDE settings, caches, plugins, and indexes.

### Qt applications

- `QtProject.conf` — Qt framework/application preferences.

### MIME and desktop associations

- `mimeapps.list` — default applications and MIME-type associations.

### Chromium web apps

- `Google Voice/` — browser-app profile data for Google Voice.
- `Todoist/` — browser-app profile data for Todoist.
- `SoundCloud/` — browser-app profile data for SoundCloud.
- `Google Keep/` — browser-app profile data for Google Keep.
- `LinkedIn/` — browser-app profile data for LinkedIn.
- `Messages/` — browser-app profile data for Messages.
- `Syncthing/` — browser-app profile data for Syncthing.

### Wrangler

- `.wrangler/` — Cloudflare Wrangler configuration, caches, registry, metrics, and logs.
