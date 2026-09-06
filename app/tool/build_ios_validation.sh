#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${script_dir}/build_ios_clean.sh" ios --release --no-codesign \
  --dart-define=BUILD_ENV=validation
