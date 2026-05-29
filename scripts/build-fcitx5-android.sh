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

gradle_args=(--no-daemon --stacktrace)

ensure_libthai_tis_header() {
  local source_file="plugin/thai/src/main/cpp/fcitx5-libthai/src/thaikb.cpp"
  local prebuilt_root="lib/fcitx5/src/main/cpp/prebuilt/libthai"

  [[ -f "$source_file" ]] || return 0
  grep -Fq "#include <thai/tis.h>" "$source_file" || return 0
  [[ -d "$prebuilt_root" ]] || return 0

  local include_dirs=("$prebuilt_root"/*/include/thai)
  [[ -d "${include_dirs[0]:-}" ]] || return 0

  for include_dir in "${include_dirs[@]}"; do
    local header="$include_dir/tis.h"
    [[ -f "$header" ]] && continue
    # Compatibility header for fcitx5-libthai commits that include <thai/tis.h>
    # before fcitx5-android/prebuilt ships that libthai header.
    cat > "$header" <<'EOF'
/*
 * TIS-620 character names from libthai include/thai/tis.h.
 * Added during CI for older fcitx5-android/prebuilt snapshots that do not
 * package this header yet.
 */
#ifndef THAI_TIS_H
#define THAI_TIS_H

#define TIS_KO_KAI 0xa1
#define TIS_KHO_KHAI 0xa2
#define TIS_KHO_KHUAT 0xa3
#define TIS_KHO_KHWAI 0xa4
#define TIS_KHO_KHON 0xa5
#define TIS_KHO_RAKHANG 0xa6
#define TIS_NGO_NGU 0xa7
#define TIS_CHO_CHAN 0xa8
#define TIS_CHO_CHING 0xa9
#define TIS_CHO_CHANG 0xaa
#define TIS_SO_SO 0xab
#define TIS_CHO_CHOE 0xac
#define TIS_YO_YING 0xad
#define TIS_DO_CHADA 0xae
#define TIS_TO_PATAK 0xaf
#define TIS_THO_THAN 0xb0
#define TIS_THO_NANGMONTHO 0xb1
#define TIS_THO_PHUTHAO 0xb2
#define TIS_NO_NEN 0xb3
#define TIS_DO_DEK 0xb4
#define TIS_TO_TAO 0xb5
#define TIS_THO_THUNG 0xb6
#define TIS_THO_THAHAN 0xb7
#define TIS_THO_THONG 0xb8
#define TIS_NO_NU 0xb9
#define TIS_BO_BAIMAI 0xba
#define TIS_PO_PLA 0xbb
#define TIS_PHO_PHUNG 0xbc
#define TIS_FO_FA 0xbd
#define TIS_PHO_PHAN 0xbe
#define TIS_FO_FAN 0xbf
#define TIS_PHO_SAMPHAO 0xc0
#define TIS_MO_MA 0xc1
#define TIS_YO_YAK 0xc2
#define TIS_RO_RUA 0xc3
#define TIS_RU 0xc4
#define TIS_LO_LING 0xc5
#define TIS_LU 0xc6
#define TIS_WO_WAEN 0xc7
#define TIS_SO_SALA 0xc8
#define TIS_SO_RUSI 0xc9
#define TIS_SO_SUA 0xca
#define TIS_HO_HIP 0xcb
#define TIS_LO_CHULA 0xcc
#define TIS_O_ANG 0xcd
#define TIS_HO_NOKHUK 0xce
#define TIS_PAIYANNOI 0xcf
#define TIS_SARA_A 0xd0
#define TIS_MAI_HAN_AKAT 0xd1
#define TIS_SARA_AA 0xd2
#define TIS_SARA_AM 0xd3
#define TIS_SARA_I 0xd4
#define TIS_SARA_II 0xd5
#define TIS_SARA_UE 0xd6
#define TIS_SARA_UEE 0xd7
#define TIS_SARA_U 0xd8
#define TIS_SARA_UU 0xd9
#define TIS_PHINTHU 0xda
#define TIS_SYMBOL_BAHT 0xdf
#define TIS_SARA_E 0xe0
#define TIS_SARA_AE 0xe1
#define TIS_SARA_O 0xe2
#define TIS_SARA_AI_MAIMUAN 0xe3
#define TIS_SARA_AI_MAIMALAI 0xe4
#define TIS_LAKKHANGYAO 0xe5
#define TIS_MAIYAMOK 0xe6
#define TIS_MAITAIKHU 0xe7
#define TIS_MAI_EK 0xe8
#define TIS_MAI_THO 0xe9
#define TIS_MAI_TRI 0xea
#define TIS_MAI_CHATTAWA 0xeb
#define TIS_THANTHAKHAT 0xec
#define TIS_NIKHAHIT 0xed
#define TIS_YAMAKKAN 0xee
#define TIS_FONGMAN 0xef
#define TIS_THAI_DIGIT_ZERO 0xf0
#define TIS_THAI_DIGIT_ONE 0xf1
#define TIS_THAI_DIGIT_TWO 0xf2
#define TIS_THAI_DIGIT_THREE 0xf3
#define TIS_THAI_DIGIT_FOUR 0xf4
#define TIS_THAI_DIGIT_FIVE 0xf5
#define TIS_THAI_DIGIT_SIX 0xf6
#define TIS_THAI_DIGIT_SEVEN 0xf7
#define TIS_THAI_DIGIT_EIGHT 0xf8
#define TIS_THAI_DIGIT_NINE 0xf9
#define TIS_ANGKHANKHU 0xfa
#define TIS_KHOMUT 0xfb

#define TIS_YMBOL_BAHT 0xdf

#endif
EOF
  done
}

ensure_libthai_tis_header

if [[ -n "${BUILD_ABI:-}" ]]; then
  # The upstream Gradle convention reads BUILD_ABI to limit native split APKs.
  export BUILD_ABI
fi

if [[ "$build_type" == "release" && "${HAS_RELEASE_SIGNING:-false}" == "true" ]]; then
  export SIGN_KEY_FILE SIGN_KEY_PWD SIGN_KEY_ALIAS
  signing_init="$RUNNER_TEMP/fcitx5-android-signing.gradle"
  # Override release signing explicitly so storePassword and keyPassword may differ.
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
fi

variant_cap="${build_type^}"
# Build the main APK and all bundled fcitx5-android plugin APKs in one Gradle invocation.
./gradlew "${gradle_args[@]}" ":app:assemble${variant_cap}" ":assemble${variant_cap}Plugins"
