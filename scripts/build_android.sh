#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
build_app=${1:-"$repo/app"}
mkdir -p "$repo/dist"
apk_output="$repo/dist/icd-offline-0.1.1-android-arm64-demo.apk"
if [[ -e "$apk_output" ]]; then
  printf 'Existing APK preserved; choose a new version before rebuilding.\n' >&2
  exit 1
fi
cd "$build_app"
# Run serially, never alongside flutter test/pub (plugin registrant is generated).
flutter pub get --enforce-lockfile
flutter build apk --release --target-platform android-arm64 --split-per-abi
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$apk_output"
(cd "$repo/dist" && sha256sum icd-offline-0.1.1-android-arm64-demo.apk > android.sha256)
