# meepdigital/os

`meepdigital/os` is an Ubuntu Meep remix builder. It creates a bootable USB
whose live filesystem, persistent layer, and future installer all use the same
customized Ubuntu Meep system rather than treating the original Ubuntu
Cinnamon ISO as the install source.

The main entry point is [`sh/persist`](./sh/persist). It builds the customized
filesystem and its matching kernel/initramfs before writing a USB disk, then
creates an ext4 persistence partition labeled `writable`.

## Work on the VM disk at /meep

The development VM is `Ubuntu Meep`, stored in `~/vm/Ubuntu Meep/`. Its
`meep.vdi` is the hard drive; `/meep` is the host mount of that drive's root
partition. Only mount it with the VM fully powered off. The VM has 2 CPUs,
3,904 MiB RAM, VBoxSVGA with 128 MiB video memory and 3D disabled, and a
60 GiB dynamically allocated SATA SSD disk.
The display setting avoids the VMSVGA channel failures observed with this
host's VirtualBox 7.0.16 and the image's Linux 7.0 kernel.

From this repository, initialize the new VM disk from the saved customized
root, repair its boot files, and leave it mounted at `/meep`:

```bash
sudo bash ./vm.sh prepare
sudo bash ./vm.sh chroot
```

Inside the chroot, run `/home/casper/os/sh/meep --boot-only` to replace and
verify boot graphics, or `/home/casper/os/sh/meep` for full provisioning.
Exit the shell, then unmount and start the VM:

```bash
sudo bash ./vm.sh unmount
bash ./vm.sh start
```

After shutting down the VM, `sudo bash ./vm.sh mount` makes the same system
available at `/meep` again. Changes to the installed VM filesystem persist
normally. `prepare` enables desktop autologin for the local `casper` user;
set its password inside the chroot with `passwd casper` if needed.

Export the mounted OS to a live ISO without writing a USB:

```bash
./sh/persist --root /meep --build-only \
  --iso ./ubuntucinnamon-26.04.1-desktop-amd64.iso
```

To export and write it, replace `--build-only` with the intended whole USB
device, such as `/dev/sdX`. The source ISO supplies the bootloader structure;
the OS, kernel, initramfs, and graphics come from the customized root.

`vm.sh` requires VirtualBox, qemu-nbd, gdisk, dosfstools, e2fsprogs, and rsync
on the host. Creating `/meep`, partitioning the new VDI, and mounting it need
root privileges. The prepared disk must be boot-tested before being treated
as working.

> **Warning:** `sh/persist` is a destructive disk-imaging tool. Verify the
> target with `lsblk` every time. Never substitute a partition for the whole
> USB device, and never run it against a disk containing data you need.

## Choose an operation

- Build a new persistent USB: `./sh/persist /dev/sdX`
- Build a new persistent USB with the optional package groups skipped:
  `./sh/persist /dev/sdX --minimal`
- Rerun the software installation on an existing build:
  `./sh/persist /dev/sdX --resume`
- Install the package set directly in the current Ubuntu Cinnamon system:
  `./sh/meep`

`sh/meep` self-elevates through `sudo` and sources the ordered modules in
`sh/_meep/`. The `sh/_meep/` directory
directory is the source of truth for installed, configured, and removed tools;
the package lists below are a readable summary of that configuration.

### How To Use

Find the USB disk ID. Use the whole disk, such as `/dev/sdX`, not a partition like `/dev/sdX1`.

```bash
lsblk -d -o NAME,PATH,SIZE,MODEL,TRAN,TYPE
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,MOUNTPOINTS
```

Create the persistent Ubuntu Cinnamon USB:

```bash
git clone https://github.com/meepdigital/os
cd os
./sh/persist /dev/sdX
```

`sh/persist` is destructive. It will erase the target disk after asking you to type the selected device path again.

Build commands run synchronously and show their normal output. An installer
failure stops the build before writing a device. Plymouth graphics and the
matching initramfs are refreshed by `sh/_meep/plymouth.sh` during the normal build;
the completed filesystem is then exported.

To rebuild and rewrite the inspected USB with the current Plymouth graphics:

```bash
sudo bash ./tmp.sh
```

This temporary command is restricted to `/dev/sde` and serial `618BB4EB`, then
delegates to `sh/persist`. It is destructive: close files open on the USB and
confirm the device path when prompted.

To rerun only the persistent overlay install work on an already-created USB:

```bash
./sh/persist /dev/sdX --resume
```

New USBs contain one automatic boot path:

- **Ubuntu Meep** boots the customized merged filesystem through Casper with
  the `writable` persistence partition. The same persistent desktop contains
  the custom Electron installer, so installation is available from the live
  session without a second GRUB choice.

There is no Ubuntu Cinnamon, Ubiquity, Subiquity, or Ubuntu Desktop Installer
install path. The custom Electron installer lives in [`installer/`](./installer/)
and its disk-writing backend is intentionally gated while the first pages are
being tested. The performance design is installed
by `sh/_meep/design.sh` from `sh/meep`; it does not put `/usr`, the package database,
or user data in tmpfs. Rebuild an older USB in create mode to replace its
immutable ISO boot menu; `--resume` only reruns the persistent overlay work.
It cannot repair the immutable kernel, initramfs, or splash graphics; export
and rewrite the image to update those.

## Boot verification

`sh/_meep/boot.sh` registers Meep through `update-alternatives`, installs the supplied
PNG/SVG graphics, and explicitly generates an initramfs for every installed
kernel. Verification extracts each image and compares all graphics and the
selected theme. `sh/persist` exports the matching boot pair and Casper media
UUID, retains essential runtime mount directories, updates checksums, and
reads boot files back from the resulting ISO.

Run `bash tests/boot-artifacts.sh` for unprivileged regression checks. These
checks verify artifact rejection, not a successful OS boot. Final acceptance
requires a desktop boot and a marker file surviving a shutdown/reboot, both
for the installed VM disk and for the live USB's persistence partition.

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
