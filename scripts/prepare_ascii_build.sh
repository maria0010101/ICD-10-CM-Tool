#!/usr/bin/env bash
# Work around Flutter 3.47.5 observed LSP JSON truncation in non-ASCII paths.
# Build copy only; source remains authoritative in this repository.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
build_root=${1:-/tmp/icd-work-build}
mkdir -p "$build_root/app" "$build_root/samples" "$build_root/tools/data_builder/tests/fixtures" "$build_root/evidence"
rsync -a --exclude=build --exclude=.dart_tool --exclude=local.properties --exclude=.gradle --exclude=.flutter-plugins-dependencies "$repo/app/" "$build_root/app/"
rsync -a "$repo/samples/" "$build_root/samples/"
rsync -a "$repo/tools/data_builder/tests/fixtures/" "$build_root/tools/data_builder/tests/fixtures/"
printf 'Build directory: %s/app\n' "$build_root"
