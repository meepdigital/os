#!/bin/bash

# Embedded snapshot of the local Cinnamon desktop, captured 2026-09-20.
# Safe to source from sh/install: shell options remain inside this subshell.
(
set -euo pipefail
if [[ ${EUID} -ne 0 ]]; then
    exec sudo bash "${BASH_SOURCE[0]}" "$@"
fi

# Required by the bundled Force Quit applet.
if ! command -v xkill >/dev/null 2>&1; then
    apt-get install -y x11-utils
fi

python3 - <<'PYTHON'
import copy
import hashlib
import json
import os
from pathlib import Path
import pwd
import subprocess
import tempfile

# One bottom panel, 35px, with the exact local applet order and zone sizes.
PANEL_DCONF = r'''[org/cinnamon]
panels-enabled=['1:0:bottom']
panels-height=['1:35', '2:30']
panels-autohide=['1:false', '2:false']
panels-show-delay=['1:0', '2:0']
panels-hide-delay=['1:0', '2:0']
panel-zone-icon-sizes='[{"panelId":1,"left":0,"center":0,"right":24}]'
panel-zone-symbolic-icon-sizes='[{"panelId":1,"left":28,"center":28,"right":16}]'
panel-zone-text-sizes='[{"panelId":1,"left":0,"center":0,"right":0}]'
enabled-applets=['panel1:left:0:menu@cinnamon.org:0', 'panel1:left:1:grouped-window-list@cinnamon.org:2', 'panel1:right:0:workspace-switcher@cinnamon.org:15', 'panel1:right:5:notifications@cinnamon.org:5', 'panel1:right:7:removable-drives@cinnamon.org:7', 'panel1:right:3:sound@cinnamon.org:11', 'panel1:right:11:calendar@cinnamon.org:13', 'panel1:right:12:cornerbar@cinnamon.org:14', 'panel1:right:6:user@cinnamon.org:29', 'panel1:right:9:trash@cinnamon.org:30', 'panel1:right:2:spacer@cinnamon.org:34', 'panel1:right:4:network@cinnamon.org:16', 'panel1:right:10:xapp-status@cinnamon.org:17', 'panel1:right:0:systray@cinnamon.org:20', 'panel1:right:8:force-quit@cinnamon.org:21']
next-applet-id=22
panel-edit-mode=false
date-format='%a, %h %d %Y%l:%M %p'

[org/cinnamon/desktop/interface]
clock-show-date=true
clock-show-seconds=true
clock-use-24h=true
'''
# Includes all local applet values, not just the pinned applications.
APPLET_SETTINGS = json.loads(r'''{
    "grouped-window-list@cinnamon.org": {
        "group-apps": true,
        "scroll-behavior": 1,
        "left-click-action": 2,
        "middle-click-action": 3,
        "show-all-workspaces": false,
        "window-display-settings": 1,
        "cycleMenusHotkey": "",
        "show-apps-order-hotkey": "<Super>grave",
        "show-apps-order-timeout": 2500,
        "super-num-hotkeys": true,
        "title-display": 1,
        "launcher-animation-effect": 3,
        "number-display": true,
        "enable-app-button-dragging": true,
        "thumbnail-scroll-behavior": false,
        "show-thumbnails": true,
        "animate-thumbnails": false,
        "vertical-thumbnails": false,
        "sort-thumbnails": false,
        "highlight-last-focused-thumbnail": true,
        "onclick-thumbnails": false,
        "thumbnail-timeout": 250,
        "thumbnail-size": 6,
        "enable-hover-peek": true,
        "hover-peek-time-in": 300,
        "hover-peek-time-out": 0,
        "hover-peek-opacity": 100,
        "show-recent": true,
        "autostart-menu-item": false,
        "monitor-move-all-windows": true,
        "pinned-apps": [
            "nemo.desktop",
            "google-chrome.desktop",
            "sublime_text.desktop",
            "android-studio_android-studio.desktop",
            "slack.desktop",
            "discord.desktop",
            "teams-for-linux_teams-for-linux.desktop",
            "spotify.desktop"
        ]
    },
    "workspace-switcher@cinnamon.org": {
        "display-type": "visual",
        "scroll-behavior": "disabled"
    },
    "notifications@cinnamon.org": {
        "ignoreTransientNotifications": true,
        "showEmptyTray": false,
        "showNotificationCount": true,
        "keyOpen": "<Super>n",
        "keyClear": "<Shift><Super>c"
    },
    "sound@cinnamon.org": {
        "playerControl": true,
        "extendedPlayerControl": false,
        "keyOpen": "<Shift><Super>s",
        "alwaysShowMuteInput": false,
        "_knownPlayers": [
            "banshee",
            "vlc",
            "rhythmbox"
        ],
        "showtrack": false,
        "truncatetext": 30,
        "middleClickAction": "mute",
        "middleShiftClickAction": "in_mute",
        "horizontalScroll": false,
        "showalbum": false,
        "hideSystray": true,
        "tooltipShowVolume": true,
        "tooltipShowPlayer": false,
        "tooltipShowArtistTitle": false
    },
    "calendar@cinnamon.org": {
        "show-events": false,
        "show-week-numbers": false,
        "use-custom-format": true,
        "custom-format": "          %A        %B %e        %I:%M          ",
        "custom-tooltip-format": "          %A        %B %e        %I:%M          ",
        "keyOpen": "<Super>c"
    },
    "cornerbar@cinnamon.org": {
        "click-action": "show_desktop",
        "middle-click-action": "show_desklets",
        "shift-click-action": "show_expo",
        "shift-middle-click-action": "show_scale",
        "scroll-behavior": "nothing",
        "peek-at-desktop": false,
        "peek-blur": false,
        "peek-delay": 400,
        "peek-opacity": 5
    },
    "user@cinnamon.org": {
        "display-name": false,
        "display-image": false
    },
    "spacer@cinnamon.org": {
        "width": 55.0
    },
    "network@cinnamon.org": {
        "keyOpen": "<Shift><Super>n"
    }
}''')
APPLET_INSTANCES = json.loads(r'''{
    "grouped-window-list@cinnamon.org": "2",
    "workspace-switcher@cinnamon.org": "15",
    "notifications@cinnamon.org": "notifications@cinnamon.org",
    "sound@cinnamon.org": "sound@cinnamon.org",
    "calendar@cinnamon.org": "13",
    "cornerbar@cinnamon.org": "14",
    "user@cinnamon.org": "29",
    "spacer@cinnamon.org": "34",
    "network@cinnamon.org": "network@cinnamon.org"
}''')

# The local Force Quit applet is user-installed, so bundle it for new systems.
FORCE_QUIT_JS = r'''const Lang = imports.lang;
const Applet = imports.ui.applet;
const GLib = imports.gi.GLib;
const Gettext = imports.gettext;
const UUID = "force-quit@cinnamon.org";

Gettext.bindtextdomain(UUID, GLib.get_home_dir() + "/.local/share/locale");

function _(str) {
    return Gettext.dgettext(UUID, str);
}

function MyApplet(metadata, orientation, panelHeight, instanceId) {
    this._init(metadata, orientation, panelHeight, instanceId);
}

MyApplet.prototype = {
    __proto__: Applet.IconApplet.prototype,

    _init: function(metadata, orientation, panelHeight, instanceId) {
        Applet.IconApplet.prototype._init.call(this, orientation, panelHeight, instanceId);

        try {
            this.set_applet_icon_symbolic_name("window-close");
            this.set_applet_tooltip(_("Click here to kill a window"));
            this.actor.connect('button-release-event', Lang.bind(this, this._onButtonReleaseEvent));
        }
        catch (e) {
            global.logError(e);
        }
    },

    _onButtonReleaseEvent: function(actor, event) {
        if (this._applet_enabled) {
            if (event.get_button() == 1) {
                if (!this._draggable.inhibit) {
                    return false;
                } else {
                    GLib.spawn_command_line_async('xkill');
                }
            }
        }
        return true;
    }

};

function main(metadata, orientation, panelHeight, instanceId) {
    let myApplet = new MyApplet(metadata, orientation, panelHeight, instanceId);
    return myApplet;
}
'''
FORCE_QUIT_METADATA = r'''{
    "uuid": "force-quit@cinnamon.org",
    "name": "Force Quit",
    "description": "Click on the applet to launch xkill and force any window to quit immediately",
    "author": "none",
    "last-edited": 1760254106
}'''
FORCE_QUIT_ICON = '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'

def write_file(path, content, owner=None):
    """Replace atomically and give newly created user directories to that user."""
    path = Path(path)
    missing = []
    parent = path.parent
    while not parent.exists():
        missing.append(parent)
        parent = parent.parent
    for parent in reversed(missing):
        parent.mkdir(mode=0o755)
        if owner:
            os.chown(parent, *owner)
    fd, name = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
        os.chmod(name, 0o644)
        if owner:
            os.chown(name, *owner)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def json_text(value):
    return json.dumps(value, indent=4) + '\n'


users = [u for u in pwd.getpwall()
         if (u.pw_uid == 0 or 1000 <= u.pw_uid < 65534)
         and Path(u.pw_dir).is_dir()]
homes = [(Path('/etc/skel'), None)] + [
    (Path(u.pw_dir), (u.pw_uid, u.pw_gid)) for u in users]


def apply_applet(uuid, instance, values, all_instances=False):
    applet_dir = Path('/usr/share/cinnamon/applets') / uuid
    schema_path = applet_dir / 'settings-schema.json'
    schema_text = schema_path.read_text()
    schema = json.loads(schema_text)
    missing = values.keys() - schema.keys()
    if missing:
        raise RuntimeError(f'{uuid}: unsupported settings: {sorted(missing)}')
    override_path = applet_dir / 'settings-override.json'
    overrides = json.loads(override_path.read_text()) if override_path.exists() else {}
    for key, value in values.items():
        overrides[key] = {'override-props': True, 'default': value}
    override_text = json_text(overrides)
    write_file(override_path, override_text)
    # Match Cinnamon's schema + override checksum so the first login does not
    # reset the seeded values. Keep the installed version's setting metadata.
    for key, props in overrides.items():
        if props.get('override-props'):
            schema[key].update({k: v for k, v in props.items() if k != 'override-props'})
        else:
            schema[key] = props
    for setting in schema.values():
        if isinstance(setting, dict) and 'default' in setting:
            setting['value'] = copy.deepcopy(setting['default'])
    schema['__md5__'] = (hashlib.md5(schema_text.encode()).hexdigest()
                         + hashlib.md5(override_text.encode()).hexdigest())
    for home, owner in homes:
        directory = home / '.config/cinnamon/spices' / uuid
        paths = {directory / (instance + '.json')}
        if all_instances and directory.exists():
            paths.update(directory.glob('*.json'))
        for path in paths:
            write_file(path, json_text(schema), owner)


def apply_dconf(filename, settings):
    # A local.d file is ignored unless the user profile selects its database.
    profile = Path('/etc/dconf/profile/user')
    content = profile.read_text() if profile.exists() else 'user-db:user\n'
    if 'system-db:local' not in content.splitlines():
        write_file(profile, content.rstrip() + '\nsystem-db:local\n')
    write_file(Path('/etc/dconf/db/local.d') / filename, settings)
    subprocess.run(['dconf', 'update'], check=True)
    # Defaults alone do not replace existing user values. Load only this
    # script's keys, including for users who have not logged in yet.
    for user in users:
        bus = Path(f'/run/user/{user.pw_uid}/bus')
        command = ['runuser', '-u', user.pw_name, '--', 'env',
                   '-u', 'DBUS_SESSION_BUS_ADDRESS', '-u', 'DCONF_PROFILE',
                   '-u', 'XDG_CONFIG_HOME', '-u', 'XDG_RUNTIME_DIR',
                   f'HOME={user.pw_dir}']
        if bus.is_socket():
            command += [f'XDG_RUNTIME_DIR=/run/user/{user.pw_uid}',
                        f'DBUS_SESSION_BUS_ADDRESS=unix:path={bus}']
        else:
            command += ['dbus-run-session', '--']
        subprocess.run(command + ['dconf', 'load', '/'], input=settings,
                       text=True, check=True)

import base64
force_dir = Path('/usr/share/cinnamon/applets/force-quit@cinnamon.org')
write_file(force_dir / 'applet.js', FORCE_QUIT_JS)
write_file(force_dir / 'metadata.json', FORCE_QUIT_METADATA)
(force_dir / 'icon.png').write_bytes(base64.b64decode(FORCE_QUIT_ICON))
(force_dir / 'icon.png').chmod(0o644)

for uuid, values in APPLET_SETTINGS.items():
    apply_applet(uuid, APPLET_INSTANCES[uuid], values)
# Write settings before enabling the applets, so newly created instances start
# with the captured values instead of briefly using stock defaults.
apply_dconf('00-ubuntu-meep-panel', PANEL_DCONF)
print('Applied the embedded local 35px bottom panel, applets, clock, and eight pinned applications.')
PYTHON
)
