#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(cd "${script_dir}/.." && pwd)"
env_file="${APP_STORE_ENV_FILE:-${app_dir}/.env.appstore.local}"
cd "${app_dir}"

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
: "${PRIVACY_POLICY_URL:?PRIVACY_POLICY_URL is required}"
: "${SUPPORT_URL:?SUPPORT_URL is required}"
: "${SUPPORT_EMAIL:?SUPPORT_EMAIL is required}"
: "${SERVICE_OPERATOR:?SERVICE_OPERATOR is required}"
: "${APPLE_BUILD_NUMBER:?APPLE_BUILD_NUMBER is required}"
: "${APP_BUNDLE_ID:?APP_BUNDLE_ID is required}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"
: "${IOS_EXPORT_METHOD:?IOS_EXPORT_METHOD is required}"

export BUILD_ENV=production
dart run "${script_dir}/validate_release_config.dart"

if [[ ! "${APPLE_BUILD_NUMBER}" =~ ^[1-9][0-9]*$ ]]; then
  echo "APPLE_BUILD_NUMBER must be a positive integer." >&2
  exit 1
fi

if [[ ! "${APPLE_TEAM_ID}" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "APPLE_TEAM_ID must be the 10-character Apple Developer Team ID." >&2
  exit 1
fi

if [[ "${IOS_EXPORT_METHOD}" != "app-store" ]]; then
  echo "IOS_EXPORT_METHOD must be app-store for an App Store archive." >&2
  exit 1
fi

project_file="${app_dir}/ios/Runner.xcodeproj"
settings_file="$(mktemp "${TMPDIR:-/tmp}/futuremint-settings.XXXXXX")"
trap 'rm -f "${settings_file}"' EXIT
xcodebuild -project "${project_file}" -scheme Runner -configuration Release \
  -showBuildSettings -json CODE_SIGNING_ALLOWED=NO > "${settings_file}"
python3 - "${settings_file}" <<'PYSETTINGS'
import json, os, re, sys
settings = [item['buildSettings'] for item in json.load(open(sys.argv[1]))
            if item.get('target') == 'Runner']
if len(settings) != 1:
    raise SystemExit('Could not identify the Runner Release target unambiguously.')
settings = settings[0]
bundle = os.environ['APP_BUNDLE_ID']
if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+){2,}', bundle) or bundle.endswith('.RunnerTests'):
    raise SystemExit('APP_BUNDLE_ID must be the application bundle identifier.')
if settings.get('PRODUCT_BUNDLE_IDENTIFIER') != bundle:
    raise SystemExit('APP_BUNDLE_ID must exactly match the Runner Release target.')
if settings.get('DEVELOPMENT_TEAM') != os.environ['APPLE_TEAM_ID']:
    raise SystemExit('Configure the confirmed Apple Team on Runner in Xcode first; APPLE_TEAM_ID must match it.')
if settings.get('TARGETED_DEVICE_FAMILY') != '1':
    raise SystemExit('Runner must target iPhone only (TARGETED_DEVICE_FAMILY=1).')
PYSETTINGS
rm -f "${settings_file}"

export_options_file="$(mktemp "${TMPDIR:-/tmp}/futuremint-export-options.XXXXXX.plist")"
cleanup() {
  rm -f "${export_options_file}" "${settings_file}"
}
trap cleanup EXIT
printf '%s\n' \
  '<?xml version="1.0" encoding="UTF-8"?>' \
  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
  '<plist version="1.0"><dict>' \
  '<key>method</key><string>app-store</string>' \
  '<key>signingStyle</key><string>automatic</string>' \
  "<key>teamID</key><string>${APPLE_TEAM_ID}</string>" \
  '</dict></plist>' > "${export_options_file}"

cd "${app_dir}"
bash "${script_dir}/build_ios_clean.sh" ipa --release \
  --build-number="${APPLE_BUILD_NUMBER}" \
  --export-options-plist="${export_options_file}" \
  --dart-define="BUILD_ENV=production" \
  --dart-define="API_BASE_URL=${API_BASE_URL}" \
  --dart-define="PRIVACY_POLICY_URL=${PRIVACY_POLICY_URL}" \
  --dart-define="SUPPORT_URL=${SUPPORT_URL}" \
  --dart-define="SUPPORT_EMAIL=${SUPPORT_EMAIL}" \
  --dart-define="SERVICE_OPERATOR=${SERVICE_OPERATOR}"
