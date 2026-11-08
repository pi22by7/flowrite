FROM docker.io/httpd:2.4-alpine
RUN apk add --no-cache apr-util-dbm_gdbm
COPY httpd.conf /usr/local/apache2/conf/httpd.conf
COPY entrypoint.sh /usr/local/bin/flowrite-webdav
RUN chmod +x /usr/local/bin/flowrite-webdav && printf ok > /usr/local/apache2/htdocs/healthz
ENTRYPOINT ["flowrite-webdav"]
CMD ["httpd-foreground"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1/healthz || exit 1
