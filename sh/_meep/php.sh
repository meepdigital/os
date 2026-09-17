#!/bin/bash

PHP_MODULES=(
	apcu
	ast
	bcmath
	bz2
	cli
	common
	curl
	decimal
	dev
	fpm
	gd
	grpc
	http
	igbinary
	imap
	intl
	mbstring
	memcached
	mysql
	oauth
	opcache
	pgsql
	protobuf
	ps
	pspell
	psr
	readline
	redis
	smbclient
	soap
	solr
	sqlite3
	ssh2
	tidy
	uploadprogress
	uuid
	xdebug
	xlswriter
	xml
	xmlrpc
	xsl
	yaml
	zip
)

target_codename=$(. /etc/os-release; printf '%s' "${VERSION_CODENAME}")
php_prefix=php
[[ ${target_codename} != noble ]] || php_prefix=php8.4
apt-get install -y "${php_prefix}" "${php_prefix}-cli" "${php_prefix}-fpm"
PHP_PACKAGES=()
for module in "${PHP_MODULES[@]}"; do
    package="${php_prefix}-${module}"
    # Read the complete apt-cache output; exiting awk early can SIGPIPE
    # apt-cache under the repository's pipefail setting (status 141).
    candidate=$(apt-cache policy "${package}" | awk '/Candidate:/ && !seen {print $2; seen=1}')
    if [[ -n ${candidate} && ${candidate} != '(none)' ]]; then
        PHP_PACKAGES+=("${package}")
    else
        echo "Optional PHP module unavailable on ${target_codename}: ${package}"
    fi
done
((${#PHP_PACKAGES[@]} == 0)) || apt-get install -y "${PHP_PACKAGES[@]}"

php_version=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')
a2enconf "php${php_version}-fpm"
a2enmod proxy_fcgi setenvif

# composer
EXPECTED_CHECKSUM="$(php -r "copy('https://composer.github.io/installer.sig', 'php://stdout');")"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [[ "${EXPECTED_CHECKSUM}" != "${ACTUAL_CHECKSUM}" ]]; then
	rm -f composer-setup.php
	echo "Composer installer checksum mismatch" >&2
	exit 1
fi

php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm -f composer-setup.php

COMPOSER_GLOBAL_HOME=/usr/local/share/composer
COMPOSER_GLOBAL_BIN="${COMPOSER_GLOBAL_HOME}/vendor/bin"

install -d -m 0755 "${COMPOSER_GLOBAL_HOME}"
install -d -m 0755 /etc/profile.d

cat <<'EOF' >/etc/profile.d/composer-global-bin.sh
#!/bin/sh
COMPOSER_GLOBAL_BIN="/usr/local/share/composer/vendor/bin"

case ":${PATH}:" in
	*:"${COMPOSER_GLOBAL_BIN}":*)
		;;
	*)
		export PATH="${COMPOSER_GLOBAL_BIN}:${PATH}"
		;;
esac
EOF
chmod 0644 /etc/profile.d/composer-global-bin.sh

export COMPOSER_HOME="${COMPOSER_GLOBAL_HOME}"
export COMPOSER_ALLOW_SUPERUSER=1
export PATH="${COMPOSER_GLOBAL_BIN}:${PATH}"

# symfony
symfony_setup=$(mktemp)
curl -1sLf 'https://dl.cloudsmith.io/public/symfony/stable/setup.deb.sh' -o "${symfony_setup}"
bash "${symfony_setup}"
rm -f "${symfony_setup}"
apt-get update
apt-get install -y symfony-cli

# Drush Launcher finds and executes the project-local drush/drush installed in
# each repo's vendor directory, so the global `drush` command matches the Drupal
# project's own Drush version instead of forcing one global Composer copy.
curl -fL \
	https://github.com/drush-ops/drush-launcher/releases/latest/download/drush.phar \
	-o /usr/local/bin/drush
chmod 0755 /usr/local/bin/drush
