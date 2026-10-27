# 天琴 · TavernHeadless Android 客户端

Flutter/Dart 原生客户端，仅 Android。当前版本为 `0.1.0+2`。供手机下载安装时使用 ARM64 Release 包。

## 构建与安装

本次验证工具链：`/opt/homebrew/share/flutter`，Flutter 3.47.7 / Dart 3.13.5。另一套 `/Users/xiefuzhu/dev/flutter/sdk/flutter` 当前内置 Dart 3.11.5，不满足工程要求，不能使用该路径的检查结果判断当前工程。

```sh
/opt/homebrew/share/flutter/bin/flutter pub get
/opt/homebrew/share/flutter/bin/flutter analyze --no-pub
/opt/homebrew/share/flutter/bin/flutter test --no-pub test/widget_test.dart
/opt/homebrew/share/flutter/bin/flutter build apk --release --target-platform android-arm64 --split-per-abi --no-pub
```

安装包：`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`，仅含 ARM64 架构。应用名“天琴”，包名 `com.tavernheadless.tavern_headless`；最低 Android 7.0 / API 24，target API 36。Release 构建去除调试运行时并裁剪未使用代码与图标；目前仍使用同一个 Android 调试签名，供本地测试更新，尚未准备正式发布签名。通用 `app-debug.apk` 仅供开发调试，体积显著更大。

## 连接

填写手机可访问的 TavernHeadless API 地址和访问凭证；模型密钥保留在服务器。默认 `127.0.0.1:3000` 指手机自身，不会自动连接开发电脑。

Release 与 debug 包均支持用户填写的 HTTP / HTTPS 后端。当前开发电脑地址是 `10.172.22.64`，手机与电脑在可互通的局域网时，填写 `http://10.172.22.64:3000`（不加 `/api`）。电脑切换网络后，需重新确认 IP。手机浏览器打开 `http://10.172.22.64:3000/health` 可先检查网络是否可达。

服务端启动：

```sh
cd /Users/xiefuzhu/Desktop/Chat/TavernHeadless
pnpm dev:api
```

本机私密 `.env` 已设置 `HOST="0.0.0.0"`、`PORT="3000"` 与 API Key 认证。启动时自动加载；已有服务运行时无需重复启动。其他环境默认仅监听 `127.0.0.1`，需要局域网连接时再配置 `HOST=0.0.0.0`。客户端访问密钥取根目录 `.env` 的 `AUTH_API_KEYS`，不使用模型密钥 `LLM_API_KEY`。通过 ADB 联调也可运行 `adb reverse tcp:3000 tcp:3000` 后使用 `http://127.0.0.1:3000`。

## 当前范围与验证

已编写连接、角色库、会话列表、显式资产选择、聊天、设置页面，REST/SSE、重新生成、行动选项、分页、草稿与凭证存储，以及 Material 3 主题、动态配色、液态玻璃底栏。

2026-10-26 验证结果：静态分析无问题；现有 5 项测试通过；Android debug 与 ARM64 Release APK 均构建成功。通用 Debug 包约 168 MiB，ARM64 Release 包约 20 MiB，主要减少多架构 Flutter 引擎、调试代码与 Vulkan 校验库。没有连接的 Android 设备，本次未安装、未做实际聊天与性能验收。

局域网接入补验：服务实际监听 `*:3000`；局域网地址的健康检查 200，未认证业务请求 401；使用真实客户端 Dart Repository 可读取角色、资产、会话；API 类型检查及 6 项认证集成测试通过。新版 ARM64 APK 的 versionCode 为 2002，Manifest 已启用 HTTP，签名校验通过。手机到电脑的网络可达性仍由用户在手机上确认。

受控 WebView、原 HTML 卡面、JS 显示正则与酒馆助手桥接尚未实现；当前只剥离 HTML 卡面，并将 SUOT 行动选项渲染为原生组件。默认上下文 1,048,576、输出 65,536 是配置目标，实际生效与上限仍需后端及模型验证。

后续优先验证手机连接、连续发送、仅填入/直接发送、重新生成、草稿与恢复，再继续原卡面兼容。历史开发快照见 `HANDOFF.md`；完整目标见根目录 `CLIENT-PLAN.md`。
