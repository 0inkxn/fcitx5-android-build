#!/usr/bin/env bash
set -euo pipefail

project_dir="${1:-sources/fcitx5-android}"
build_type="${2:-${BUILD_TYPE:-release}}"

case "$build_type" in
  release|debug) ;;
  *)
    echo "Unsupported build type: $build_type" >&2
    exit 2
    ;;
esac

cd "$project_dir"
chmod +x ./gradlew

if [[ -n "${BUILD_ABI:-}" ]]; then
  export BUILD_ABI
fi

if [[ "$build_type" == "release" && "${HAS_RELEASE_SIGNING:-false}" == "true" ]]; then
  export SIGN_KEY_FILE SIGN_KEY_PWD SIGN_KEY_ALIAS
fi

variant_cap="${build_type^}"
./gradlew --no-daemon --stacktrace ":app:assemble${variant_cap}" ":assemble${variant_cap}Plugins"
