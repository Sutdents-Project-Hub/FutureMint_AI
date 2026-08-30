#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(cd "${script_dir}/.." && pwd)"
env_file="${APP_STORE_ENV_FILE:-${app_dir}/.env.appstore.local}"

if [[ ! -f "${env_file}" ]]; then
  echo "Missing App Store environment file: ${env_file}" >&2
  echo "Copy .env.appstore.example to .env.appstore.local and fill only local values." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${env_file}"
set +a

: "${API_BASE_URL:?API_BASE_URL is required}"
: "${APPLE_BUILD_NUMBER:?APPLE_BUILD_NUMBER is required}"
: "${APP_BUNDLE_ID:?APP_BUNDLE_ID is required}"

if [[ ! "${API_BASE_URL}" =~ ^https:// ]] || [[ ! "${API_BASE_URL}" =~ /api/$ ]]; then
  echo "API_BASE_URL must be an HTTPS URL ending in /api/." >&2
  exit 1
fi

if [[ "${API_BASE_URL}" == *"example.invalid"* ]] || [[ "${API_BASE_URL}" == *"localhost"* ]]; then
  echo "API_BASE_URL must point to the verified production API." >&2
  exit 1
fi

if [[ ! "${APPLE_BUILD_NUMBER}" =~ ^[1-9][0-9]*$ ]]; then
  echo "APPLE_BUILD_NUMBER must be a positive integer." >&2
  exit 1
fi

project_file="${app_dir}/ios/Runner.xcodeproj/project.pbxproj"
if ! grep -Fq "PRODUCT_BUNDLE_IDENTIFIER = ${APP_BUNDLE_ID};" "${project_file}"; then
  echo "APP_BUNDLE_ID does not match the Runner Xcode project." >&2
  exit 1
fi

cd "${app_dir}"
flutter build ipa --release \
  --build-number="${APPLE_BUILD_NUMBER}" \
  --dart-define="API_BASE_URL=${API_BASE_URL}"
