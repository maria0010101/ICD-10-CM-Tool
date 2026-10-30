#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
build_app=${1:-"$repo/app"}
mkdir -p "$repo/dist"
version=$(sed -n 's/^version: \([0-9.]*\).*/\1/p' "$repo/app/pubspec.yaml")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
apk_name="icd-offline-$version-android-arm64.apk"
apk_output="$repo/dist/$apk_name"
if [[ -e "$apk_output" ]]; then
  printf 'Existing APK preserved; choose a new version before rebuilding.\n' >&2
  exit 1
fi
cd "$build_app"
# Run serially, never alongside flutter test/pub (plugin registrant is generated).
flutter pub get --enforce-lockfile
flutter build apk --release --target-platform android-arm64 --split-per-abi
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$apk_output"
(cd "$repo/dist" && sha256sum "$apk_name" > "$apk_name.sha256")
