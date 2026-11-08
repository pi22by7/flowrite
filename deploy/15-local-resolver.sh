#!/bin/sh
set -eu
# Use the runtime's DNS (Docker's embedded resolver or Podman's network DNS).
# Nginx must re-resolve WebDAV after Compose replaces its container.
resolvers=$(awk '$1 == "nameserver" { if ($2 ~ /:/) printf "[%s] ", $2; else printf "%s ", $2 }' /etc/resolv.conf)
[ -n "$resolvers" ] || { echo 'No container DNS resolver configured' >&2; exit 1; }
printf 'resolver %s valid=5s ipv6=off;\n' "$resolvers" > /etc/nginx/conf.d/00-resolver.conf
