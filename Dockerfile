FROM docker.io/ubuntu:24.04 AS builder
ARG FLUTTER_VERSION=3.47.9
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils python3 libglu1-mesa && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter
ENV TAR_OPTIONS=--no-same-owner
ENV PATH="/opt/flutter/bin:${PATH}"
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter config --no-analytics && flutter pub get
COPY . .
# Never embed the developer's cloud configuration in a self-hosted image.
RUN printf '' > .env && bash scripts/build_web.sh

FROM docker.io/nginx:1.28-alpine
COPY deploy/15-local-resolver.sh /docker-entrypoint.d/15-local-resolver.sh
RUN chmod +x /docker-entrypoint.d/15-local-resolver.sh
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build/web /usr/share/nginx/html
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1/healthz || exit 1
EXPOSE 80
