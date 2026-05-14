#!/usr/bin/env bash
set -euo pipefail

fcitx_dir="${1:-sources/fcitx5-android}"
syncclip_dir="${2:-sources/Fcitx5-SyncClipboard}"
artifact_dir="${3:-artifacts}"
build_type="${4:-${BUILD_TYPE:-release}}"
apk_count=0

copy_apks() {
  local source_dir="$1"
  local dest_dir="$2"
  local prefix="$3"

  if [[ ! -d "$source_dir" ]]; then
    echo "::warning::APK output directory not found: $source_dir"
    return
  fi

  mkdir -p "$dest_dir"
  while IFS= read -r -d '' apk; do
    local rel="${apk#$source_dir/}"
    local safe_rel="${rel//\//-}"
    cp "$apk" "$dest_dir/${prefix}-${safe_rel}"
    ((apk_count += 1))
  done < <(find "$source_dir" -type f -name '*.apk' -print0)
}

rm -rf "$artifact_dir"
mkdir -p "$artifact_dir/main-app" "$artifact_dir/bundled-plugins" "$artifact_dir/syncclipboard"

# fcitx5-android emits split APKs under per-module Gradle output directories.
copy_apks "$fcitx_dir/app/build/outputs/apk/$build_type" "$artifact_dir/main-app" "fcitx5-android"

# Bundled plugins are optional per source checkout; collect whatever was built.
for plugin_dir in "$fcitx_dir"/plugin/*; do
  [[ -d "$plugin_dir" ]] || continue
  plugin_name="$(basename "$plugin_dir")"
  copy_apks "$plugin_dir/build/outputs/apk/$build_type" "$artifact_dir/bundled-plugins/$plugin_name" "$plugin_name"
done

copy_apks "$syncclip_dir/app/build/outputs/apk/$build_type" "$artifact_dir/syncclipboard" "syncclipboard"

if (( apk_count == 0 )); then
  echo "::error::No APK artifacts were collected."
  exit 1
fi

# Keep commit provenance beside the APKs so a downloaded artifact can be traced
# back without opening the Actions run page.
{
  echo "Build type: $build_type"
  echo "Build ABI: ${BUILD_ABI:-all}"
  echo
  echo "fcitx5-android repository: ${FCITX_REPOSITORY:-unknown}"
  echo "fcitx5-android ref: ${FCITX_REF:-unknown}"
  git -C "$fcitx_dir" rev-parse HEAD | sed 's/^/fcitx5-android commit: /'
  echo
  echo "Fcitx5-SyncClipboard repository: ${SYNCCLIP_REPOSITORY:-unknown}"
  echo "Fcitx5-SyncClipboard ref: ${SYNCCLIP_REF:-unknown}"
  git -C "$syncclip_dir" rev-parse HEAD | sed 's/^/Fcitx5-SyncClipboard commit: /'
  echo
  echo "APKs:"
  find "$artifact_dir" -type f -name '*.apk' | sort
} > "$artifact_dir/BUILD_INFO.txt"

if command -v sha256sum >/dev/null 2>&1; then
  find "$artifact_dir" -type f -name '*.apk' -print0 \
    | sort -z \
    | xargs -0 -r sha256sum > "$artifact_dir/SHA256SUMS.txt"
fi
