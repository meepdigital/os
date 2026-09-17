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

apt-get install -y "${CORE_PACKAGES[@]}"

ZOOM_DEB=/tmp/zoom_amd64.deb
curl -fsSL https://zoom.us/client/latest/zoom_amd64.deb -o "${ZOOM_DEB}"
apt-get install -y "${ZOOM_DEB}"
rm -f "${ZOOM_DEB}"

SLACK_DEB=/tmp/zoom_amd64.deb
curl -fsSL "https://slack.com/downloads/instructions/linux?ddl=1&build=deb" -o "${SLACK_DEB}"
apt-get install -y "${SLACK_DEB}"
rm -f "${SLACK_DEB}"

DISCORD_DEB=/tmp/discord_amd64.deb
curl -fsSL "https://discord.com/api/download?platform=linux&format=deb" -o "${DISCORD_DEB}"
apt-get install -y "${DISCORD_DEB}"
rm -f "${DISCORD_DEB}"

