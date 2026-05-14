# fcitx5-android-build

用于在 GitHub Actions 中自动构建 `fcitx5-android` 主项目、主项目内置插件，以及独立的 Fcitx5 SyncClipboard 剪贴板同步插件。

这个仓库不保存源代码副本。workflow 会在运行时 checkout 下面两个仓库，默认值可在手动运行时覆盖，也可用仓库 Variables 固定：

| 变量 | 默认值 |
| --- | --- |
| `FCITX_REPOSITORY` | `0inkxn/fcitx5-android` |
| `FCITX_REF` | `master` |
| `SYNCCLIP_REPOSITORY` | `0inkxn/Fcitx5-SyncClipboard` |
| `SYNCCLIP_REF` | `master` |
| `BUILD_TYPE` | `release` |
| `BUILD_ABI` | 空，表示构建主项目全部 ABI |

## 构建内容

- 主程序：`fcitx5-android :app:assembleRelease` 或 `:app:assembleDebug`
- 主项目内置插件：`:assembleReleasePlugins` 或 `:assembleDebugPlugins`
- 剪贴板同步插件：`Fcitx5-SyncClipboard :app:assembleRelease` 或 `:app:assembleDebug`

构建结果会上传为 `fcitx5-android-suite-*` artifact，并按目录区分：

- `main-app/`
- `bundled-plugins/`
- `syncclipboard/`
- `BUILD_INFO.txt`
- `SHA256SUMS.txt`

## Release 签名

fcitx5-android 的 release 插件需要与主程序同签名。要生成可直接配套安装的 release APK，请在构建仓库中配置 Secrets：

| Secret | 说明 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | keystore/jks 文件的 base64 内容 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key 密码，可省略；省略时剪贴板插件使用 `ANDROID_KEYSTORE_PASSWORD` |

注意：当前 `fcitx5-android` 主项目的 Gradle 签名约定只接收一个 `SIGN_KEY_PWD`，即 store password 和 key password 需要相同。若你的 keystore 两个密码不同，需要先调整主项目签名逻辑。

生成 base64 示例：

```bash
# Linux
base64 -w 0 release.jks

# macOS
base64 -i release.jks
```

## 手动运行

进入 GitHub Actions，运行 `Build Fcitx5 Android Suite`：

- `build_type=release`：要求签名 secrets，生成同签名 release APK。
- `build_type=debug`：不需要签名 secrets，主程序包名为 `org.fcitx.fcitx5.android.debug`。
- `build_abi=arm64-v8a`：只构建主程序指定 ABI；留空则构建全部 ABI。
- `publish_release=true`：同时创建 GitHub Release 并上传 APK。

## repository_dispatch 触发

源仓库可以通过 `repository_dispatch` 触发此构建仓库：

```bash
gh api repos/OWNER/fcitx5-android-build/dispatches \
  --method POST \
  -f event_type=build-fcitx5-android \
  -f client_payload='{
    "fcitx_ref": "master",
    "syncclip_ref": "master",
    "build_type": "release",
    "build_abi": "arm64-v8a"
  }'
```

`client_payload` 可覆盖 workflow input 中同名字段：`fcitx_repository`、`fcitx_ref`、`syncclip_repository`、`syncclip_ref`、`build_type`、`build_abi`、`publish_release`、`release_tag`。
