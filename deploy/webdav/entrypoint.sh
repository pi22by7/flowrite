#!/bin/sh
set -eu
: "${WEBDAV_USERNAME:?Set WEBDAV_USERNAME}"
: "${WEBDAV_PASSWORD:?Set WEBDAV_PASSWORD}"
mkdir -p /var/lib/dav /var/lib/dav-lock
htpasswd -bc /usr/local/apache2/conf/dav.passwd "$WEBDAV_USERNAME" "$WEBDAV_PASSWORD" >/dev/null 2>&1
chmod 640 /usr/local/apache2/conf/dav.passwd
chown root:daemon /usr/local/apache2/conf/dav.passwd
chown -R daemon:daemon /var/lib/dav /var/lib/dav-lock
exec "$@"
