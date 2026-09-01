## taypme/os

`taypme/os` is a persistent Ubuntu Cinnamon remix builder. It uses the scripts in this repository to create a bootable USB stick based on the latest Ubuntu Cinnamon desktop ISO, then installs this repo's custom package set into the USB's persistent overlay.

The main entry point is [`persist.sh`](./persist.sh). It writes the ISO to a USB disk, creates an ext4 persistence partition labeled `writable`, copies this repo into `/home/casper/os`, and runs [`os.sh`](./os.sh) inside the persistent live system.

### How To Use

Find the USB disk ID. Use the whole disk, such as `/dev/sdX`, not a partition like `/dev/sdX1`.

```bash
lsblk -d -o NAME,PATH,SIZE,MODEL,TRAN,TYPE
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,MOUNTPOINTS
```

Create the persistent Ubuntu Cinnamon USB:

```bash
git clone https://github.com/taypme/os
cd os
sudo bash ./persist.sh /dev/sdX
```

`persist.sh` is destructive. It will erase the target disk after asking you to type the selected device path again.

To rerun only the persistent overlay install work on an already-created USB:

```bash
sudo bash ./persist.sh /dev/sdX --resume
```

### Included APT Packages

- `software-properties-common`
- `apt-transport-https`
- `ca-certificates`
- `curl`
- `gnupg`
- `git`
- `git-lfs`
- `zip`
- `gzip`
- `unzip`
- `7zip`
- `cmake`
- `jq`
- `wget`
- `nano`
- `guake`
- `redshift`
- `redshift-gtk`
- `caffeine`
- `transmission`
- `gnome-disk-utility`
- `file-roller`
- `gufw`
- `ufw`
- `gimp`
- `libreoffice-common`
- `inkscape`
- `google-chrome-stable`
- `simplescreenrecorder`
- `sublime-text`
- `vlc`
- `zoom`
- `apache2`
- `memcached`
- `mysql-client`
- `mysql-server`
- `postgresql`
- `redis`
- `redis-server`
- `docker.io`
- `docker-compose-v2`
- `nodejs`
- `npm`
- `python3`
- `python3-pip`
- `golang`
- `gradle`
- `maven`
- `ruby-full`
- `rake`
- `rustup`
- `perl`
- `eslint`
- `gh`
- `acli`
- `grub2-common`
- `qemu-system-x86`
- `qemu-system`
- `qemu-utils`
- `rsync`
- `virtualbox`
- `php8.4`
- `php8.4-{{ the works }}`

### Included Other Tools

- Composer
- Symfony CLI
- Drush Launcher
- `@github/copilot`
- `@githubnext/github-copilot-cli`
- `@google/gemini-cli`
- `@openai/codex`
- `electron`
- `heroku`
- `nodemon`
- `yo`
- Discord from [`deb/`](./deb)
- Slack from [`deb/`](./deb)

### Included Snaps

- `plex-desktop`
- `spotify`
- `teams-for-linux`
- `mc-installer`
- `snap-store`
- `trello-cli`
- `canonical-livepatch`
- `flutter --classic`
- `blender --classic`

### Removed APT Packages

- `gedit`
- `pidgin`
- `hexchat`
- `alacritty`
- `aisleriot`
- `gnome-2048`
- `brasero`
- `gnome-chess`
- `firefox`
- `five-or-more`
- `four-in-a-row`
- `gnote`
- `hitori`
- `gnome-klotski`
- `gnome-mahjongg`
- `gnome-mines`
- `gnome-nibbles`
- `quadrapassel`
- `iagno`
- `rhythmbox`
- `gnome-robots`
- `sound-juicer`
- `gnome-sudoku`
- `swell-foop`
- `tali`
- `gnome-taquin`
- `gnome-tetravex`
- `thunderbird`
- `totem`

### Removed Snaps

- `firefox`
- `thunderbird`
