#!/usr/bin/env bash
set -euo pipefail
app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stage_root="$(mktemp -d "${TMPDIR:-/tmp}/futuremint-ios.XXXXXX")"
trap 'rm -rf "${stage_root}"' EXIT
python3 "${app_dir}/tool/prepare_ios_release.py" "${app_dir}" "${stage_root}/app"
cd "${stage_root}/app"
flutter pub get --offline
flutter build "$@"
if find build/ios -iname '*integration_test*' -print | grep -q .; then
  echo 'Release rejected: integration_test found in iOS artifact.' >&2
  exit 1
fi
python3 - <<'PYVERIFY'
import pathlib, plistlib
apps = list(pathlib.Path('build/ios').rglob('Runner.app'))
if not apps:
    raise SystemExit('Release rejected: Runner.app missing.')
for app in apps:
    metadata = plistlib.loads((app / 'Info.plist').read_bytes())
    if metadata.get('UIDeviceFamily') != [1]:
        raise SystemExit('Release rejected: built app is not iPhone only.')
PYVERIFY
artifact_dir="${app_dir}/build/release-ios/$(basename "${stage_root}")"
mkdir -p "${artifact_dir}"
cp -R build/ios/. "${artifact_dir}/"
echo "Verified release artifact (without integration_test): ${artifact_dir}"
