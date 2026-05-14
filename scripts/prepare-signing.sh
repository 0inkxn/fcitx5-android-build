#!/usr/bin/env bash
set -euo pipefail

build_type="${BUILD_TYPE:-release}"
require_signing="${REQUIRE_SIGNING:-true}"

write_env() {
  printf '%s=%s\n' "$1" "$2" >> "$GITHUB_ENV"
}

if [[ "$build_type" != "release" ]]; then
  write_env HAS_RELEASE_SIGNING false
  exit 0
fi

missing=()
[[ -n "${ANDROID_KEYSTORE_BASE64:-}" ]] || missing+=("ANDROID_KEYSTORE_BASE64")
[[ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ]] || missing+=("ANDROID_KEYSTORE_PASSWORD")
[[ -n "${ANDROID_KEY_ALIAS:-}" ]] || missing+=("ANDROID_KEY_ALIAS")

if (( ${#missing[@]} > 0 )); then
  if [[ "$require_signing" == "true" ]]; then
    printf '::error::Missing signing secrets for release build: %s\n' "${missing[*]}"
    exit 1
  fi
  printf '::warning::Release signing is disabled because secrets are missing: %s\n' "${missing[*]}"
  write_env HAS_RELEASE_SIGNING false
  exit 0
fi

keystore_path="$RUNNER_TEMP/android-release.jks"
printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode > "$keystore_path"
chmod 600 "$keystore_path"

write_env HAS_RELEASE_SIGNING true
write_env SIGN_KEY_FILE "$keystore_path"
write_env SIGN_KEY_PWD "$ANDROID_KEYSTORE_PASSWORD"
write_env SIGN_KEY_ALIAS "$ANDROID_KEY_ALIAS"
write_env KEYSTORE_PATH "$keystore_path"
write_env KEYSTORE_PASSWORD "$ANDROID_KEYSTORE_PASSWORD"
write_env KEY_ALIAS "$ANDROID_KEY_ALIAS"
write_env KEY_PASSWORD "${ANDROID_KEY_PASSWORD:-$ANDROID_KEYSTORE_PASSWORD}"
