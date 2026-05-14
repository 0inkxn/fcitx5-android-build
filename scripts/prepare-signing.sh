#!/usr/bin/env bash
set -euo pipefail

build_type="${BUILD_TYPE:-release}"
require_signing="${REQUIRE_SIGNING:-true}"

write_env() {
  # Values written to GITHUB_ENV are available to later workflow steps only.
  printf '%s=%s\n' "$1" "$2" >> "$GITHUB_ENV"
}

if [[ "$build_type" != "release" ]]; then
  write_env HAS_RELEASE_SIGNING false
  exit 0
fi

missing=()
[[ -n "${ANDROID_KEYSTORE_BASE64:-}" ]] || missing+=("ANDROID_KEYSTORE_BASE64")
[[ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ]] || missing+=("ANDROID_KEYSTORE_PASSWORD")

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

# Validate the keystore before Gradle starts. Otherwise a wrong alias can fail
# ten minutes later during APK packaging.
if ! aliases="$(keytool -list -v -keystore "$keystore_path" -storepass "$ANDROID_KEYSTORE_PASSWORD" 2>/dev/null | awk -F': ' '/Alias name:/{print $2}')"; then
  echo "::error::Failed to read the signing keystore. Check ANDROID_KEYSTORE_BASE64 and ANDROID_KEYSTORE_PASSWORD."
  exit 1
fi

alias_count="$(printf '%s\n' "$aliases" | sed '/^$/d' | wc -l | tr -d ' ')"
if [[ "$alias_count" == "0" ]]; then
  echo "::error::No key aliases were found in the signing keystore."
  exit 1
fi

resolved_alias="${ANDROID_KEY_ALIAS:-}"
# A single-key keystore is unambiguous, so tolerate a missing or stale alias secret.
if [[ -z "$resolved_alias" ]]; then
  if [[ "$alias_count" == "1" ]]; then
    resolved_alias="$(printf '%s\n' "$aliases" | sed '/^$/d' | head -n 1)"
    echo "::notice::ANDROID_KEY_ALIAS is not set; using the only alias in the keystore."
  else
    echo "::error::ANDROID_KEY_ALIAS is required because the signing keystore contains multiple aliases."
    exit 1
  fi
elif ! printf '%s\n' "$aliases" | grep -Fxq "$resolved_alias"; then
  if [[ "$alias_count" == "1" ]]; then
    resolved_alias="$(printf '%s\n' "$aliases" | sed '/^$/d' | head -n 1)"
    echo "::warning::ANDROID_KEY_ALIAS was not found in the keystore; using the only alias in the keystore."
  else
    echo "::error::ANDROID_KEY_ALIAS was not found in the signing keystore."
    exit 1
  fi
fi

# fcitx5-android reads SIGN_KEY_* from its convention plugin. The standalone
# SyncClipboard project uses KEY* variables through an injected Gradle init script.
write_env HAS_RELEASE_SIGNING true
write_env SIGN_KEY_FILE "$keystore_path"
write_env SIGN_KEY_PWD "$ANDROID_KEYSTORE_PASSWORD"
write_env SIGN_KEY_ALIAS "$resolved_alias"
write_env KEYSTORE_PATH "$keystore_path"
write_env KEYSTORE_PASSWORD "$ANDROID_KEYSTORE_PASSWORD"
write_env KEY_ALIAS "$resolved_alias"
write_env KEY_PASSWORD "${ANDROID_KEY_PASSWORD:-$ANDROID_KEYSTORE_PASSWORD}"
