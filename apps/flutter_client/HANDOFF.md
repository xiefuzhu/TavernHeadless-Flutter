# Flutter 客户端 · 暂停交接说明

> **局域网接入已补齐**：本机 `.env` 设置 `HOST=0.0.0.0`，服务监听 `*:3000` 并保留 API Key 认证；客户端版本 `0.1.0+2` 支持 HTTP / HTTPS。ARM64 Release 包约 20 MiB，versionCode 2002。电脑局域网地址与实际 Dart Repository 连接检查通过；操作步骤以 `README.md` 为准，尚未做手机端实测。

> **2026-10-26 接手更新**：下文是 15:28 的历史快照。当前三个页面、App 装配、入口与测试均已补齐，`Banner` 已改名。使用 `/opt/homebrew/share/flutter`（Flutter 3.47.7 / Dart 3.13.5）静态分析无问题，现有 5 项测试通过；debug APK 已构建并通过签名校验。`/Users/xiefuzhu/dev/flutter/sdk/flutter` 当前内置 Dart 3.11.5，使用它得到的 27 错误不能代表正确工具链下的状态。未进行真机安装与实际聊天验收，原 HTML 卡面、JS 显示正则和桥接仍未接入。当前构建与连接说明以本目录 `README.md` 为准。

- 快照时间：2026-10-26 15:28（GMT+8）
- 工作目录：`/Users/xiefuzhu/Desktop/Chat/TavernHeadless/apps/flutter_client`
- 当前状态：**暂停开发**，未提交、未构建、未上真机
- 一句话结论：基础层、数据层、ViewModel、主题、液态玻璃底栏、连接页、会话列表页、新建会话、消息与行动选项组件已写完；**3 个页面、App 装配、启动入口尚未创建**；`flutter analyze` 仍有 **18 error / 2 warning / 7 info**，其中 12 个 error 来自 `Banner` 命名冲突，6 个来自缺失页面文件。

---

## 1. 目标与边界（依据 `CLIENT-PLAN.md`）

| 项 | 内容 |
|---|---|
| 技术路线 | Flutter + Dart，仅 Android，工程位于 `apps/flutter_client` |
| 架构 | MVVM + Repository + Service，`provider` + `ChangeNotifier`，`go_router` 导航 |
| 首版范围 | M1 + M2：连接、角色/资产显式选择、会话列表、时间线、SSE 聊天、仅填入/直接发送、重新生成、恢复核对、草稿、诊断 |
| 本版不做 | M3 的受控 WebView 卡面与 JS 显示正则；M4 真机性能验收；M5 签名与分发 |
| 用户追加要求 | FlClash 风格 Material 3（配色/字体/间距/圆角/层级统一）、自然动画、液态玻璃底栏（成熟库） |
| 不在本版承诺 | 服务端任务与观察连接解耦、断线续流、跨设备互斥（依赖服务端） |

---

## 2. 环境与已验证事实

### 2.1 工具链（已执行验证）

| 项 | 结论 |
|---|---|
| Flutter | 3.47.7 stable（SDK：`/Users/xiefuzhu/dev/flutter/sdk/flutter`） |
| Dart | 3.13.5 |
| 后端 | 本地 `http://127.0.0.1:3000/health` 正常；`/sessions` 未认证返回 401，确认需要 API Key |
| 真机 | `PJZ110`（Android 17 / API 37）无线连接曾可用；本轮未重新安装验证 |
| 静态分析 | 已执行 `flutter analyze`，结果见 §4.9 |
| 依赖解析 | `flutter pub get` 成功，Manrope 可变字体与 OFL 已随包 |

### 2.2 后端契约（已读源码确认，非推测）

| 动作 | 接口与响应 |
|---|---|
| 列角色 | `GET /characters?limit&offset&sort_by&sort_order` → `{ data: [{ id, name, source, status, revision, latest_version_no, created_at, updated_at }], meta }` |
| 列资产 | `GET /presets`、`GET /worldbooks`、`GET /regex-profiles` → `{ data: [{ id, name, source, version, created_at, updated_at }] }` |
| 建会话 | `POST /sessions`，body 为 snake_case（`character_id`、`title`、`user_snapshot`、`preset_id`、`regex_profile_id`、`worldbook_profile_id`、`prompt_mode`）→ `{ data: {...} }` |
| 改会话 | `PATCH /sessions/:id` → `{ data: {...} }` |
| 时间线 | `GET /sessions/:id/timeline?branch_id&limit(1–200)&offset` → `{ data: { session_id, branch_id, floors: [{ id, floor_no, state, pages, active_pages, active_page, messages }] }, meta: { total, limit, offset, has_more } }`；`active_pages` 项**不含** `is_active` 字段 |
| 生成状态 | `GET /sessions/:id/active-run` → `{ data: { session_id, active_run: { branch_id, busy, public_phase, ... } \| null } }` |
| 发送 | `POST /sessions/:id/respond/stream`，SSE 事件：`start / chunk / run / summary / tool / error / done`；`done` 含 `floor_id / floor_no / branch_id / generated_text / summaries / total_usage / final_state` |
| 重新生成 | `POST /sessions/:id/regenerate` → `{ data: { floor_id, floor_no, generated_text, final_state, total_usage, ... } }`（无 `message`、无 `branch_id`） |
| 预算预览 | `POST /sessions/:id/respond/dry-run`，`budget: { max_input_tokens, reserved_completion_tokens }` |
| 生成配置 | `config` 为 camelCase：`enableDirector / enableVerifier / enableMemoryConsolidation`；输出上限为 `generation_params.max_output_tokens` |

### 2.3 依赖与平台配置（已核对文件内容）

- `pubspec.yaml`：`0.1.0+1`；provider、go_router 18.1.1、http 1.6.0、flutter_markdown_plus 1.0.12、webview_flutter 4.14.1（已加但**尚未使用**）、flutter_secure_storage 11.2.0、shared_preferences 2.5.6、path_provider、intl、uuid、`liquid_glass_renderer: 1.0.0-dev.1`、dynamic_color、crypto、flutter_lints 6。
- 字体：`assets/fonts/Manrope-VariableFont_wght.ttf`（164 KB）与 `OFL.txt` 已存在；中文由 `fontFamilyFallback` 交给系统 CJK 字体。
- `AndroidManifest.xml`：`INTERNET` 权限、应用名“天琴”、`EnableImpeller=true`、`EnableFlutterGPU=true`。
- `android/app/src/debug/res/xml/network_security_config.xml`：仅允许 `127.0.0.1`、`localhost`、`10.0.2.2` 明文 HTTP，其余禁止。

> **真机联调已知阻塞（已核验文件）**：debug 明文白名单不含开发机局域网 IP，真机用 `http://192.168.x.x:3000` 会被系统拒绝。后端按计划也未监听局域网。真机 HTTP 联调前必须二选一：把开发机 LAN IP 加入 debug-only 白名单，或为后端配置 HTTPS。

### 2.4 已验证 / 未验证

| 已验证 | 未验证 |
|---|---|
| 依赖解析、静态类型检查（除 §4.9 所列） | `flutter build apk --debug` |
| 液态玻璃 API（`LiquidGlassLayer` / `LiquidGlass` / `LiquidRoundedSuperellipse` / `LiquidGlassAppearance.ios27Regular`）与当前版本匹配 | 玻璃真机渲染与 Flutter GPU 是否实际启用（不可用会降级 FakeGlass） |
| `RoundedSuperellipseBorder`、`FadeForwardsPageTransitionsBuilder` 在 3.47.7 存在 | SSE 真实流式、UTF-8 跨分片、CRLF、长时间生成 |
| 后端接口路径与响应外壳（读源码） | 中文输入法 composing、Ctrl/⌘+Enter、软键盘与列表锚点 |
| 字体/Manifest/网络安全配置内容 | 64K 长输出、1000 条历史、内存与帧率 |
| 草稿与凭证代码路径 | 安全存储真机读写、进程回收后的草稿恢复 |

---

## 3. 已完成任务（含产出）

### 3.1 工程与平台

| 任务 | 产出 | 状态 |
|---|---|---|
| 创建仅 Android 的 Flutter 工程 | `apps/flutter_client` | 完成 |
| 依赖与版本锁定 | `pubspec.yaml` | 完成 |
| 字体打包 | `assets/fonts/*` | 完成 |
| Android 权限/应用名/Impeller/FlutterGPU | `android/app/src/main/AndroidManifest.xml` | 完成 |
| debug 明文 HTTP 白名单 | `android/app/src/debug/...` | 完成（范围仅本机/模拟器） |

### 3.2 设计系统（FlClash 风格 Material 3）

| 文件 | 内容 |
|---|---|
| `lib/core/theme/app_tokens.dart` | 间距（4–40）、圆角（10–30）、动效时长与曲线（含 stagger）、触控尺寸、`AppShapes.superellipse()` 连续曲率 |
| `lib/core/theme/app_theme.dart` | Material 3 主题；种子色 `#5B6CFF`；`AppPalette` ThemeExtension（success/warning/danger/streaming/hairline/glassTint/scrim）；组件主题（AppBar、按钮、输入框、卡片、弹窗、底部面板、SnackBar、Chip、Divider、ListTile、Switch、Tooltip、选择态、页面转场）；Manrope + 中文 fallback 的完整字阶 |

### 3.3 存储

| 文件 | 内容 | 备注 |
|---|---|---|
| `lib/core/config/connection_identity.dart` | 地址规范化、`connectionIdFor()`（地址+玩家名 SHA-256 前 16 位）、主机名展示 | 不包含密钥 |
| `lib/core/storage/credential_store.dart` | `flutter_secure_storage` 按 connectionId 读写/删除；Android `storageNamespace: tavern_credentials` | 未真机验证 |
| `lib/core/storage/settings_store.dart` | `SharedPreferencesAsync` 保存地址、玩家名、记住连接、直发默认、主题、动态色、最近会话 | 不存聊天事实 |
| `lib/core/storage/draft_store.dart` | `drafts/v1/<connectionId>/<sessionId>.json`；临时文件 + rename；空文本即删除；`clearConnection()` | 版本化文件 |

### 3.4 网络与 SSE

| 文件 | 内容 |
|---|---|
| `lib/core/network/api_error.dart` | status/code/requestId/details；`userMessage` 区分认证、网络、冲突、404 |
| `lib/core/network/tavern_api_client.dart` | base path 拼接、GET/POST/PATCH、30s 超时、错误体解析、`x-request-id`；`openSse()` 使用 `http.AbortableRequest` + Completer 取消 |
| `lib/core/network/sse_decoder.dart` | 增量 UTF-8、LF/CRLF、多行 `data:`、`event:`、注释心跳、尾部残片 flush；映射 `start/chunk/run/summary/tool/error/done`；`done` 缺失抛错；`RequestAbortedException` 原样抛出 |

### 3.5 数据模型与仓库

| 文件 | 内容 |
|---|---|
| `lib/data/models/json_utils.dart` | 类型安全读取（String/int/bool/Map/List） |
| `lib/data/models/character_summary.dart` | 角色摘要与首字头像 |
| `lib/data/models/asset_item.dart` | `AssetKind`、`AssetItem`、`AssetSelection`（含 clear* 语义）、`AssetBundle` |
| `lib/data/models/session_models.dart` | `SessionSummary`、`SessionTimeline.fromJson`、`TimelineFloor`（`active_pages → active_page → pages` 回退）、`TimelinePage`、`TimelineMessage`、`ActiveRun`（含 idle）、`RespondResult`、`DryRunDiagnostics`、`describeRunPhase()` |
| `lib/data/repositories/catalog_repository.dart` | 角色列表、三类资产并行拉取 |
| `lib/data/repositories/session_repository.dart` | 会话列表/创建/改名/状态、时间线、`fetchLatestTimeline()`（先 limit=1 取 total 再取尾页）、`fetchEarlier()`、active-run |
| `lib/data/repositories/chat_repository.dart` | `respondStream()`（可挂取消句柄）、`regenerate()`、`dryRun()`（正确使用 `budget` 字段） |

### 3.6 显示派生

`lib/services/message_derivation.dart`：剥离 ` ```html … ``` ` 卡面块、解析 `<SUOT>` 行动选项、HTML 实体解码、去编号、检测未闭合选项、空正文标记。保存层仍是服务端原始消息。

### 3.7 ViewModel

| 文件 | 内容 | 状态 |
|---|---|---|
| `lib/viewmodels/settings_controller.dart` | 主题/动态色/直发/玩家名/地址/记住连接/最近会话的持久化 | 已写 |
| `lib/viewmodels/connection_view_model.dart` | 地址校验、连接探针（角色+资产）、静默自动连接、错误归一化、断开时可选清凭证/草稿、`isConnected` 驱动路由 | 已写；未真机 |
| `lib/viewmodels/session_list_view_model.dart` | 筛选/本地搜索/创建/重命名/归档恢复/连接切换重置/epoch 防旧回调 | 已写 |
| `lib/viewmodels/chat_view_model.dart` | 打开会话、草稿读写与防抖、发送与 70ms 节流、停止、重新生成、时间线核对（floor 是否存在 + `committed`）、active-run 退避轮询（上限 12 次）、写入锁、epoch、选项权限、dry-run、未确认文本 | 已写；未运行验证 |

### 3.8 UI 组件

| 文件 | 内容 |
|---|---|
| `lib/ui/widgets/app_surface.dart` | `SurfaceCard`（按压缩放）、`SectionHeader`、`StatusPill`（脉冲点）、`EmptyState`、`Entrance` 入场、`Banner`（**名称冲突，待改名**） |
| `lib/ui/widgets/glass_nav_bar.dart` | `LiquidGlassLayer` + `LiquidGlass(LiquidRoundedSuperellipse)` 底栏、选择指示器 `AnimatedPositioned`、图标/文字颜色动画、无模糊的渐变遮罩 |
| `lib/ui/widgets/action_options_panel.dart` | 选项面板、仅填入/直接发送切换、历史选项折叠只读 |
| `lib/ui/widgets/message_view.dart` | 用户气泡、助手 Markdown 卡、行动选项/历史面板、空正文提示、未闭合提示、卡面说明、远程图片占位、链接复制、Markdown 样式表 |
| `lib/ui/widgets/chat_composer.dart` | 多行输入、IME composing 保护、Ctrl/⌘+Enter、发送/停止按钮、重新生成入口、状态提示 |
| `lib/ui/widgets/new_session_sheet.dart` | 角色选择、标题、三类资产显式选择（默认“不绑定”）、预算摘要、创建 |

### 3.9 页面与导航（部分）

| 文件 | 内容 | 状态 |
|---|---|---|
| `lib/ui/pages/connect_page.dart` | 极光背景、连接表单、密钥显隐、记住连接、预算标签、错误条 | 已写，含 2 个 `Banner` error |
| `lib/ui/pages/home_page.dart` | 会话列表、搜索、进行中/已归档、重命名/归档、FAB、下拉刷新、状态条、入场动画 | 已写，含 2 个 `Banner` error |
| `lib/ui/shell.dart` | 三 Tab + 液态玻璃底栏 + 底部渐变遮罩 | 已写 |
| `lib/ui/router.dart` | `/connect`、三分支 Shell、`/session/:id`；连接状态 redirect；自定义转场 | 已写，引用 3 个缺失页面 |
| `lib/ui/feedback.dart` | SnackBar、确认框、文本输入框 | 已写 |

### 3.10 静态分析快照（原样结论）

执行：`cd apps/flutter_client && flutter analyze` → **27 issues：18 error / 2 warning / 7 info**。

- **12 个 error：`Banner` 与 Flutter 内置 `Banner` 命名冲突**（每个调用点同时报 invocation + ambiguous）
  - `lib/ui/pages/connect_page.dart:232`
  - `lib/ui/pages/home_page.dart:248`
  - `lib/ui/widgets/message_view.dart:230`、`:306`
  - `lib/ui/widgets/new_session_sheet.dart:154`、`:263`
- **6 个 error：3 个页面文件不存在**
  - `lib/ui/pages/characters_page.dart`（`CharactersPage`）
  - `lib/ui/pages/chat_page.dart`（`ChatPage`，router 以 `ChatPage(sessionId:, initialSession:)` 调用）
  - `lib/ui/pages/settings_page.dart`（`SettingsPage`）
- **2 个 warning：未使用 import**
  - `lib/viewmodels/chat_view_model.dart:9` → `session_repository.dart`
  - `lib/viewmodels/connection_view_model.dart:8` → `settings_store.dart`
- **7 个 info**：`prefer_initializing_formals`（4 个 ViewModel 构造）、`use_null_aware_elements`（`app_surface.dart:129`）等，均为风格项。

> 说明：analyze 只能证明“其余文件没有类型/语法错误”，不能证明运行时行为。

---

## 4. 未完成任务（进度 / 阻塞 / 待办）

| # | 任务 | 当前进度 | 阻塞原因 | 后续待办 |
|---|---|---|---|---|
| 1 | `Banner` 改名 | 0% | 与 `package:flutter/material.dart` 的 `Banner` 冲突 | 把 `app_surface.dart` 中的 `Banner` 改名为 `AppBanner`，同步 5 个文件 6 处调用 |
| 2 | `characters_page.dart` | 0% | 未创建 | 角色列表/搜索/下拉刷新/点击进入新建会话；复用 `SurfaceCard`、`EmptyState`、`showNewSessionSheet` |
| 3 | `chat_page.dart` | 0% | 未创建 | `initState` 取 VM `open(initialSession)`；`dispose` 调 `close()`；`AppLifecycleListener.resumed → refreshFromServer()`；`reverse: true` 的 `ListView.builder` + 顶部“加载更早”；错误/公告条；恢复中进度；AppBar 菜单（刷新 / dry-run 诊断 / 重命名 / 归档）；`MessageView` 回调 + 撤销 SnackBar；`ChatComposer`；键盘与“回到最新” |
| 4 | `settings_page.dart` | 0% | 未创建 | 连接信息卡、重连对话框、主题模式（系统/浅/深）、动态色开关、直发默认、预算展示、资产数量/兼容说明、清理草稿、移除凭证并断开、关于 |
| 5 | App 装配与入口 | 0% | `lib/main.dart` 仍是 Flutter 默认 counter 示例（`MyApp`）；无 `app.dart` | 创建 `TavernApp`：`MultiProvider.value` 注入 4 个控制器、`DynamicColorBuilder`、`MaterialApp.router`、`themeMode`、`routerConfig`、首帧后 `connection.bootstrap()`；重写 `main()` 异步加载设置 |
| 6 | 测试入口 | 0% | `test/widget_test.dart` 仍是默认 counter 测试并 `pumpWidget(const MyApp())` | 删除或替换为最小 smoke（连接页可渲染、关键文案存在）；保持“不新增测试文件”的项目约定 |
| 7 | 清理 warning | 0% | 未处理 | 删除 2 个未使用 import；info 可留待格式化统一处理 |
| 8 | 构建验证 | 0% | 依赖 #1–#6 | `flutter analyze` 清零 error → `flutter test` → `flutter build apk --debug` |
| 9 | 真机运行 | 0% | 依赖 #8；且 debug 明文白名单不含 LAN IP | 加开发机 LAN IP 到 debug 白名单或配 HTTPS；安装后验证连接、新建、发送、仅填入/直发、重生成、杀进程恢复 |
| 10 | 运行时专项验证 | 0% | 未运行 | 玻璃是否走 Flutter GPU / 降级 FakeGlass；SSE 中文跨分片；IME composing；64K 长输出；1000 条历史；WebView 未使用（本版无） |
| 11 | 文档更新 | 0% | 现有 `MOBILE-README.md` / `MOBILE-COMPATIBILITY.md` 仍描述 Vue 原型 | 增加 Flutter 章节：运行方式、默认预算、已知限制、验收记录 |

---

## 5. 关键设计决策与假设（接管者必须知道）

1. **不自动绑定资产**：新建会话默认 `preset/worldbook/regex = null`，必须显式选择；避免复刻原型“任何角色都套夏瑾资产”的缺陷（CLIENT-PLAN 5.2 / C04）。
2. **本版无 HTML 卡面与 JS 正则**：` ```html ` 卡面块被剥离并提示；`<SUOT>` 选项由原生解析渲染。M3 才接 WebView + 桥接白名单。
3. **`prompt_mode` 固定 `compat_strict`**，与原型一致。
4. **预算**：上下文 1,048,576、单次输出 65,536、输入 983,040；请求只传 `max_output_tokens`；dry-run 传 `max_input_tokens` + `reserved_completion_tokens`。
5. **时间线取尾页**：先 `limit=1` 拿 `total`，再取 `offset = total - pageSize`；向上补页 offset 递减；页面计划用 `reverse: true` 保持阅读锚点。
6. **提交判定**：收到 `done` 后仍重新拉时间线，只有预期 `floor_id` 出现且最后楼层 `committed` 才算确认；否则保留输入并标记“未确认”。
7. **恢复策略**：仅前台轮询；1.5s×3 → 3s×3 → 6s，最多 12 次；不自动重发；`AppLifecycleListener` resumed 时先核对服务端。
8. **凭证隔离**：`connectionId = sha256(地址 + 玩家名)[:16]`；只有“记住连接”才写安全存储；草稿按 connectionId 分目录；退出可分别清理凭证与草稿。
9. **主题**：Android 12+ 用 `dynamic_color` 取系统色，否则用品牌种子 `#5B6CFF`；玻璃染色 `glassTint = primary @ 10–16%`。
10. **玻璃降级**：`liquid_glass_renderer` 在无 Flutter GPU 时自动 FakeGlass；Manifest 已开启 Impeller/FlutterGPU，但真机是否生效未验证。

---

## 6. 建议的下一步顺序（可直接照做）

1. `app_surface.dart`：`Banner` → `AppBanner`，改 6 处调用 → analyze 应减少 12 error。
2. 新建 `characters_page.dart`（最小可用：列表 + 搜索 + 点击新建）。
3. 新建 `chat_page.dart`（核心，按 §4 #3 清单）。
4. 新建 `settings_page.dart`（最小可用：连接、外观、预算、清理）。
5. 新建 `app.dart` + 重写 `main.dart`（Provider 装配 + 动态色 + router + bootstrap）。
6. 替换 `test/widget_test.dart`；`flutter analyze` 清零 error；`flutter test`。
7. `flutter build apk --debug`；解决构建问题（重点：liquid_glass_renderer 的 Flutter GPU 编译要求、minSdk）。
8. 真机联调（先解决 debug LAN HTTP 白名单），逐项记录 C01–C25 / F01–F08 中与本版相关的项。
9. 更新 `MOBILE-README.md`、`MOBILE-COMPATIBILITY.md` 的 Flutter 章节。

---

## 7. 风险与禁止事项

- **不要**把 API Key 放入 URL、日志、诊断导出、WebView 或 shared_preferences。
- **不要**对生成请求做透明重试；失败后必须先核对时间线，由用户主动重试。
- **不要**在 `build()` 中创建 `TextEditingController` / `WebViewController` / Timer。
- **不要**用 `Opacity` 淡化液态玻璃子树（应使用 `LiquidGlassVisibility`）。
- **不要**把 `pageTransitionsTheme` 与 `CustomTransitionPage` 之外的转场混用导致双动画。
- **不要**声称功能通过：目前没有任何 Flutter 运行时、构建或真机证据。
- **不要**把 `webview_flutter` 当作已接入：依赖已加但零调用，M3 才使用。

---

## 8. 文件清单（当前真实存在）

```
lib/
  core/config/{connection_identity,generation_defaults}.dart
  core/network/{api_error,sse_decoder,tavern_api_client}.dart
  core/storage/{credential_store,draft_store,settings_store}.dart
  core/theme/{app_theme,app_tokens}.dart
  core/utils/format.dart
  data/models/{json_utils,character_summary,asset_item,session_models}.dart
  data/repositories/{catalog_repository,chat_repository,session_repository}.dart
  services/message_derivation.dart
  viewmodels/{settings_controller,connection_view_model,session_list_view_model,chat_view_model}.dart
  ui/feedback.dart
  ui/router.dart
  ui/shell.dart
  ui/pages/{connect_page,home_page}.dart
  ui/widgets/{app_surface,glass_nav_bar,action_options_panel,message_view,chat_composer,new_session_sheet}.dart
  main.dart            ← 仍是默认 counter 示例
test/widget_test.dart  ← 仍是默认 counter 测试
```

缺失：`lib/app.dart`、`lib/ui/pages/characters_page.dart`、`lib/ui/pages/chat_page.dart`、`lib/ui/pages/settings_page.dart`。

---

## 9. 版本控制状态

`git status --short -- apps/flutter_client` → `?? apps/flutter_client/`

即整个 Flutter 工程**尚未纳入 Git**，没有提交记录；接管后应先确认 `.gitignore`（Flutter 默认生成）再提交。
