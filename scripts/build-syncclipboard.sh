#!/usr/bin/env bash
set -euo pipefail

project_dir="${1:-sources/Fcitx5-SyncClipboard}"
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

gradle_args=(--no-daemon --stacktrace)

if [[ "$build_type" == "release" && "${HAS_RELEASE_SIGNING:-false}" == "true" ]]; then
  signing_init="$RUNNER_TEMP/syncclipboard-signing.gradle"
  cat > "$signing_init" <<'EOF'
gradle.beforeProject { p ->
    p.afterEvaluate {
        if (p.plugins.hasPlugin("com.android.application")) {
            def android = p.extensions.findByName("android")
            if (android != null) {
                android.signingConfigs {
                    release {
                        storeFile = p.file(System.getenv("KEYSTORE_PATH"))
                        storePassword = System.getenv("KEYSTORE_PASSWORD")
                        keyAlias = System.getenv("KEY_ALIAS")
                        keyPassword = System.getenv("KEY_PASSWORD")
                    }
                }
                android.buildTypes.release.signingConfig = android.signingConfigs.release
            }
        }
    }
}
EOF
  export KEYSTORE_PATH KEYSTORE_PASSWORD KEY_ALIAS KEY_PASSWORD
  gradle_args+=("-I" "$signing_init")
elif [[ "$build_type" == "release" ]]; then
  echo "::warning::Building Fcitx5-SyncClipboard release with the signing config from the source project."
fi

variant_cap="${build_type^}"
./gradlew "${gradle_args[@]}" ":app:assemble${variant_cap}"
