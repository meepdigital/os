#!/bin/bash
# Install the core desktop and system packages for Ubuntu Meep.
# Also allow this module to be invoked directly.
if ! declare -F meep_once >/dev/null; then
	. "$(dirname -- "${BASH_SOURCE[0]}")/cache.sh"
fi

CORE_PACKAGES=(
	redshift
	caffeine
	transmission
	gnome-disk-utility
	file-roller
	grub2-common
	qemu-system-x86
	qemu-utils
	rsync
	snapd
	gimp
	libreoffice-common
	inkscape
	apache2
	memcached
	postgresql
	redis
	redis-server
	acli
	docker.io
	docker-compose-v2
	eslint
	gh
	golang
	gradle
	maven
	nodejs
	npm
	perl
	python3
	python3-pip
	qemu-system
	rake
	rclone
	gvfs-backends
	ruby-full
	rustup
	redshift-gtk
	sass
	simplescreenrecorder
	virtualbox
	vlc
)

MINIMAL_CORE_PACKAGES=(
	gnome-disk-utility
	file-roller
	grub2-common
	rsync
	snapd
	nodejs
	npm
)

if [[ ${MEEP_MINIMAL:-0} == 1 ]]; then
	echo "Installing minimal Meep core packages."
	meep_apt_install "${MINIMAL_CORE_PACKAGES[@]}"
	return 0 2>/dev/null || exit 0
fi

meep_apt_install "${CORE_PACKAGES[@]}"

install_downloaded_deb zoom https://zoom.us/client/latest/zoom_amd64.deb zoom

install_downloaded_deb slack "https://downloads.slack-edge.com/desktop-releases/linux/x64/4.52.155/slack-desktop-4.52.155-amd64.deb" slack-desktop
install_downloaded_deb discord "https://discord.com/api/download?platform=linux&format=deb" discord
