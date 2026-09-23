#!/bin/bash

# Embedded snapshot of the local Cinnamon desktop, captured 2026-09-20.
# Safe to source from sh/install: shell options remain inside this subshell.
(
set -euo pipefail
if [[ ${EUID} -ne 0 ]]; then
    exec sudo bash "${BASH_SOURCE[0]}" "$@"
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

# Exact resolved categories and desktop IDs, including the local exclusions.
# No category wildcards or merge directories: package updates cannot add entries.
MENU_XML = r'''<?xml version="1.0" encoding="UTF-8"?>
<Menu>
  <Name>Applications</Name>
  <Directory>cinnamon-menu-applications.directory</Directory>
  <DefaultAppDirs />
  <DefaultDirectoryDirs />
  <Menu>
    <Name>Accessories</Name>
    <Directory>cinnamon-utility.directory</Directory>
    <Include>
      <Filename>org.gnome.Calculator.desktop</Filename>
      <Filename>org.gnome.DiskUtility.desktop</Filename>
      <Filename>nemo.desktop</Filename>
      <Filename>redshift-gtk.desktop</Filename>
      <Filename>org.gnome.Screenshot.desktop</Filename>
    </Include>
    <Layout>
      <Filename>org.gnome.Calculator.desktop</Filename>
      <Filename>org.gnome.DiskUtility.desktop</Filename>
      <Filename>nemo.desktop</Filename>
      <Filename>redshift-gtk.desktop</Filename>
      <Filename>org.gnome.Screenshot.desktop</Filename>
    </Layout>
  </Menu>
  <Menu>
    <Name>Games</Name>
    <Directory>cinnamon-game.directory</Directory>
    <Include>
      <Filename>mc-installer_mc-installer.desktop</Filename>
    </Include>
    <Layout>
      <Filename>mc-installer_mc-installer.desktop</Filename>
    </Layout>
  </Menu>
  <Menu>
    <Name>Graphics</Name>
    <Directory>cinnamon-graphics.directory</Directory>
    <Include>
      <Filename>blender_blender.desktop</Filename>
      <Filename>gimp.desktop</Filename>
      <Filename>org.inkscape.Inkscape.desktop</Filename>
    </Include>
    <Layout>
      <Filename>blender_blender.desktop</Filename>
      <Filename>gimp.desktop</Filename>
      <Filename>org.inkscape.Inkscape.desktop</Filename>
    </Layout>
  </Menu>
  <Menu>
    <Name>Internet</Name>
    <Directory>cinnamon-network.directory</Directory>
    <Include>
      <Filename>snap-store_snap-store.desktop</Filename>
      <Filename>discord.desktop</Filename>
      <Filename>google-chrome.desktop</Filename>
      <Filename>slack.desktop</Filename>
      <Filename>transmission-gtk.desktop</Filename>
      <Filename>Zoom.desktop</Filename>
    </Include>
    <Layout>
      <Filename>snap-store_snap-store.desktop</Filename>
      <Filename>discord.desktop</Filename>
      <Filename>google-chrome.desktop</Filename>
      <Filename>slack.desktop</Filename>
      <Filename>transmission-gtk.desktop</Filename>
      <Filename>Zoom.desktop</Filename>
    </Layout>
  </Menu>
  <Menu>
    <Name>Office</Name>
    <Directory>cinnamon-office.directory</Directory>
    <Include>
      <Filename>libreoffice-calc.desktop</Filename>
      <Filename>libreoffice-draw.desktop</Filename>
      <Filename>libreoffice-impress.desktop</Filename>
      <Filename>libreoffice-math.desktop</Filename>
      <Filename>libreoffice-writer.desktop</Filename>
    </Include>
    <Layout>
      <Filename>libreoffice-calc.desktop</Filename>
      <Filename>libreoffice-draw.desktop</Filename>
      <Filename>libreoffice-impress.desktop</Filename>
      <Filename>libreoffice-math.desktop</Filename>
      <Filename>libreoffice-writer.desktop</Filename>
    </Layout>
  </Menu>
  <Menu>
    <Name>Other</Name>
    <Directory>cinnamon-other.directory</Directory>
    <Include>
      <Filename>plex-desktop_plex-desktop.desktop</Filename>
    </Include>
    <Layout>
      <Filename>plex-desktop_plex-desktop.desktop</Filename>
    </Layout>
  </Menu>
  <Menu>
    <Name>Development</Name>
    <Directory>cinnamon-development.directory</Directory>
    <Include>
      <Filename>android-studio_android-studio.desktop</Filename>
      <Filename>sublime_text.desktop</Filename>
    </Include>
    <Layout>
      <Filename>android-studio_android-studio.desktop</Filename>
      <Filename>sublime_text.desktop</Filename>
    </Layout>
  </Menu>
  <Menu>
    <Name>Multimedia</Name>
    <Directory>cinnamon-audio-video.directory</Directory>
    <Include>
      <Filename>be.maartenbaert.simplescreenrecorder.desktop</Filename>
      <Filename>org.gnome.SoundRecorder.desktop</Filename>
      <Filename>spotify.desktop</Filename>
      <Filename>vlc.desktop</Filename>
    </Include>
    <Layout>
      <Filename>be.maartenbaert.simplescreenrecorder.desktop</Filename>
      <Filename>org.gnome.SoundRecorder.desktop</Filename>
      <Filename>spotify.desktop</Filename>
      <Filename>vlc.desktop</Filename>
    </Layout>
  </Menu>
  <Menu>
    <Name>Preferences</Name>
    <Directory>cinnamon-settings.directory</Directory>
    <Include>
      <Filename>org.gnome.DiskUtility.desktop</Filename>
      <Filename>guake-prefs.desktop</Filename>
      <Filename>software-properties-gtk.desktop</Filename>
      <Filename>cinnamon-settings.desktop</Filename>
    </Include>
    <Layout>
      <Filename>org.gnome.DiskUtility.desktop</Filename>
      <Filename>guake-prefs.desktop</Filename>
      <Filename>software-properties-gtk.desktop</Filename>
      <Filename>cinnamon-settings.desktop</Filename>
    </Layout>
  </Menu>
  <Menu>
    <Name>Administration</Name>
    <Directory>cinnamon-settings-system.directory</Directory>
    <Include>
      <Filename>guake.desktop</Filename>
      <Filename>org.gnome.Software.desktop</Filename>
      <Filename>update-manager.desktop</Filename>
      <Filename>virtualbox.desktop</Filename>
    </Include>
    <Layout>
      <Filename>guake.desktop</Filename>
      <Filename>org.gnome.Software.desktop</Filename>
      <Filename>update-manager.desktop</Filename>
      <Filename>virtualbox.desktop</Filename>
    </Layout>
  </Menu>
  <Layout>
    <Menuname>Accessories</Menuname>
    <Menuname>Games</Menuname>
    <Menuname>Graphics</Menuname>
    <Menuname>Internet</Menuname>
    <Menuname>Office</Menuname>
    <Menuname>Other</Menuname>
    <Menuname>Development</Menuname>
    <Menuname>Multimedia</Menuname>
    <Menuname>Preferences</Menuname>
    <Menuname>Administration</Menuname>
  </Layout>
</Menu>
'''
MENU_SETTINGS = json.loads(r'''{
    "overlay-key": "Super_L::Super_R",
    "menu-custom": true,
    "menu-icon": "/usr/share/icons/hicolor/scalable/emblems/ubuntu-meep-hand-symbolic.svg",
    "menu-icon-size": 32,
    "menu-label": "",
    "show-category-icons": true,
    "category-icon-size": 22,
    "show-application-icons": true,
    "application-icon-size": 22,
    "favbox-show": true,
    "fav-icon-size": 32,
    "show-favorites": true,
    "show-places": false,
    "show-recents": false,
    "category-hover": true,
    "enable-autoscroll": true,
    "search-filesystem": false,
    "force-show-panel": true,
    "activate-on-hover": false,
    "hover-delay": 0,
    "enable-animation": false,
    "popup-width": 590,
    "popup-height": 515
}''')
MENU_DCONF = r'''[org/cinnamon]
favorite-apps=['firefox.desktop', 'firefox-esr.desktop', 'cinnamon-settings.desktop', 'pidgin.desktop', 'org.gnome.Terminal.desktop', 'nemo.desktop']
'''
MENU_ICON = r'''<svg version="1.1" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
 <path d="m7.0001 0c0.554 0 1 0.446 1 1v6h1v-4c0-0.554 0.446-1 1-1s1 0.446 1 1v9.5859l2.293-2.293c0.18827-0.19354 0.44679-0.30271 0.71679-0.30273 0.31924 7.5e-4 0.61895 0.15387 0.80664 0.41211l0.59766 0.59766-0.6582 0.65625c-0.0157 0.0175-0.0319 0.0344-0.0488 0.0508l-4 4c-0.22904 0.23813-0.56089 0.3478-0.88672 0.29297h-5.8263c-1.2582-0.0145-2.1789 0.0306-2.9316-0.38477-0.37637-0.20766-0.67322-0.55939-0.83789-0.99805-0.16432-0.43867-0.22461-0.95957-0.22461-1.6172v-9c0-0.554 0.446-1 1-1s1 0.446 1 1v4h1v-6c0-0.554 0.446-1 1-1s1 0.446 1 1v5h1v-6c0-0.554 0.446-1 1-1z" enable-background="new" fill="#808080"/>
</svg>
'''

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

# Retain desktop launchers on disk; restrict the menu through explicit XML.
# Recover allowed launchers hidden by the old version of this script.
import shutil
import xml.etree.ElementTree as ET
allowed = {node.text for node in ET.fromstring(MENU_XML).iter('Filename')}
backup = Path('/var/lib/ubuntu-meep-menu/disabled')
for directory in ('usr/share/applications', 'etc/xdg/applications'):
    saved = backup / directory
    if saved.is_dir():
        for source in saved.glob('*.desktop'):
            target = Path('/') / directory / source.name
            if source.name in allowed and not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)

write_file('/usr/share/icons/hicolor/scalable/emblems/ubuntu-meep-hand-symbolic.svg', MENU_ICON)
system_menu = Path('/etc/xdg/menus/cinnamon-applications.menu')
original = system_menu.with_suffix('.menu.before-meep')
if system_menu.exists() and not original.exists():
    shutil.copy2(system_menu, original)
write_file(system_menu, MENU_XML)
for home, owner in homes:
    write_file(home / '.config/menus/cinnamon-applications.menu', MENU_XML, owner)
apply_applet('menu@cinnamon.org', '0', MENU_SETTINGS, all_instances=True)
apply_dconf('00-ubuntu-meep-menu', MENU_DCONF)
print('Applied the embedded local Cinnamon menu, favorites, and menu appearance.')
PYTHON
)
