# syntax=docker/dockerfile:1

FROM debian:bookworm-slim AS build
ARG FLUTTER_VERSION=3.41.9
ARG FLUTTER_REVISION=00b0c91f06209d9e4a41f71b7a512d6eb3b9c694
ENV PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH \
    CI=true \
    FLUTTER_SUPPRESS_ANALYTICS=true

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*
RUN git init /opt/flutter \
    && git -C /opt/flutter remote add origin https://github.com/flutter/flutter.git \
    && git -C /opt/flutter fetch --depth 1 origin "refs/tags/$FLUTTER_VERSION" \
    && test "$(git -C /opt/flutter rev-parse FETCH_HEAD)" = "$FLUTTER_REVISION" \
    && git -C /opt/flutter checkout --detach FETCH_HEAD \
    && git -C /opt/flutter tag "$FLUTTER_VERSION" \
    && flutter config --enable-web \
    && flutter precache --web

WORKDIR /app
ARG API_BASE_URL
RUN test -n "$API_BASE_URL"
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"

FROM nginx:1.28.0-alpine AS runtime
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/ >/dev/null || exit 1
