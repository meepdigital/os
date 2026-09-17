# Ubuntu Meep menu

This is the visible launcher inventory for the current Ubuntu Cinnamon desktop: visible `.desktop` entries in `/usr/share/applications` and user launchers in `~/.local/share/applications`, with the Meep provisioning additions included. Entries hidden with `Hidden=true`, `NoDisplay=true`, or excluded by desktop-environment conditions are omitted. Names can vary slightly with translations and package versions.

## Default Cinnamon and Ubuntu applications

- System Settings
- Backgrounds
- Color
- Display
- Network
- Keyboard
- Mouse and Touchpad
- Sound
- Power Management
- Privacy
- Notifications
- Themes
- Effects
- Extensions
- Applets
- Desklets
- Panel
- Windows
- Workspaces
- Window Tiling
- Hot Corners
- General
- Accessibility
- Account details
- Users and Groups
- Date & Time
- Preferred Applications
- Startup Applications
- System Info
- Login Window
- Printers
- Additional Drivers
- Software & Updates
- Software Updater
- Software
- Files (Nemo)
- Terminal
- Calculator
- Calendar
- Characters
- Disks
- Disk Image Mounter
- Disk Image Writer
- Document Viewer
- File Roller
- Logs
- Power Statistics
- Screenshot
- Sound Recorder
- System Monitor
- Image Viewer
- Fonts
- Passwords and Keys
- Online Accounts
- Input Method
- Text Editor
- Help
- GDebi Package Installer
- Synaptic Package Manager

## Meep-managed desktop applications

These are installed directly or indirectly by the repository scripts, except where the package is listed in `sh/_meep/purge.sh`.

- Install Ubuntu Meep
- Google Chrome
- Slack
- Discord
- Zoom Workplace
- Trello
- Audacity
- Caffeine
- Caffeine Indicator
- Redshift
- Guake Preferences
- Firewall Configuration
- GIMP
- Inkscape
- LibreOffice
- LibreOffice Writer
- LibreOffice Calc
- LibreOffice Impress
- LibreOffice Draw
- LibreOffice Math
- SimpleScreenRecorder
- Sublime Text
- VLC media player
- Transmission
- VirtualBox
- QEMU
- Cubic
- FileZilla
- Easystroke Gesture Recognition
- PulseAudio Volume Control
- Start Syncthing
- Syncthing Web UI
- Plex
- Snap Store
- Spotify
- Blender
- Flutter
- Microsoft Teams (when the snap exposes its launcher)
- Minecraft (when the snap exposes its launcher)
- Canonical Livepatch

## User-installed launchers currently present

- Github
- Notion-Snap-Reborn --No-Sandbox
- Google Voice
- Todoist
- SoundCloud
- Google Keep
- LinkedIn
- Messages
- Syncthing
- Trello (Chrome web app)

## Exclusions

`sh/_meep/purge.sh` explicitly removes Gedit, Pidgin, HexChat, Alacritty, Aisleriot, GNOME games, Brasero, Gnote, Rhythmbox, Sound Juicer, Thunderbird, Totem, Firefox, and the Firefox/Thunderbird snaps. They are therefore not counted as Meep-enabled menu items even if a stale desktop file remains on a development workstation.
