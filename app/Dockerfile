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
ARG PRIVACY_POLICY_URL
ARG SUPPORT_URL
ARG SUPPORT_EMAIL
ARG SERVICE_OPERATOR
ARG BUILD_ENV=production
RUN test -n "$API_BASE_URL" \
    && test -n "$PRIVACY_POLICY_URL" \
    && test -n "$SUPPORT_URL" \
    && test -n "$SUPPORT_EMAIL" \
    && test -n "$SERVICE_OPERATOR" \
    && { test "$BUILD_ENV" = "production" || test "$BUILD_ENV" = "validation"; }
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY lib ./lib
COPY tool/validate_release_config.dart ./tool/validate_release_config.dart
RUN dart run tool/validate_release_config.dart
COPY assets ./assets
COPY web ./web
RUN flutter build web --release \
    --dart-define=BUILD_ENV="$BUILD_ENV" \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=PRIVACY_POLICY_URL="$PRIVACY_POLICY_URL" \
    --dart-define=SUPPORT_URL="$SUPPORT_URL" \
    --dart-define=SUPPORT_EMAIL="$SUPPORT_EMAIL" \
    --dart-define=SERVICE_OPERATOR="$SERVICE_OPERATOR"

FROM nginx:1.28.0-alpine AS runtime
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/ >/dev/null || exit 1
