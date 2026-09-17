CORE_PACKAGES=(
	guake
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
	google-chrome-stable
	sass
	simplescreenrecorder
	sublime-text
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
	apt-get install -y "${MINIMAL_CORE_PACKAGES[@]}"
	return 0 2>/dev/null || exit 0
fi

apt-get install -y "${CORE_PACKAGES[@]}"

install_downloaded_deb() {
	local name="$1"
	local url="$2"
	local deb="/tmp/${name}.deb"

	rm -f "${deb}"
	curl -fL --retry 3 --retry-delay 2 "${url}" -o "${deb}"
	if ! dpkg-deb --info "${deb}" >/dev/null 2>&1; then
		echo "Downloaded ${name} artifact is not a valid Debian archive: ${url}" >&2
		file "${deb}" >&2 || true
		rm -f "${deb}"
		return 1
	fi
	apt-get install -y "${deb}"
	rm -f "${deb}"
}

install_downloaded_deb zoom https://zoom.us/client/latest/zoom_amd64.deb
install_downloaded_deb slack "https://slack.com/downloads/instructions/linux?ddl=1&build=deb"
install_downloaded_deb discord "https://discord.com/api/download?platform=linux&format=deb"
