# 天琴移动网页原型

本机地址：http://127.0.0.1:5174/ 。API：http://127.0.0.1:3000/ 。两者只监听本机，手机远程连接和服务器部署尚未启用。

上游仓库：HerSophia/TavernHeadless，基线提交 `5061b3cc2b0a1007beb59b7943cc61812255b83d`。正式客户端已确定使用 Flutter，仅开发和验证 Android，见 [Flutter 客户端详细计划](CLIENT-PLAN.md)。本页仍说明现有 Vue 网页对照原型的运行方式。

默认总上下文 **1M = 1,048,576 token**，最大输出 **64K = 65,536 token**；预留输出后，输入预算为 983,040 token。输出上限包含模型计入用量的推理，不代表每次要求写满 64K。

## 当前可以做什么

- 选择角色、创建会话、输入消息、接收 SSE 回复、重新生成最后一轮、恢复服务端已提交历史。
- 夏瑾预设的行动卡面保留 HTML/CSS，通过隔离 iframe 与网页通信，支持“仅填入”和“直接发送”。
- 页面中的“卡面验证 · 首轮真实回复”来自实际 DeepSeek 生成；“复测 · 1M上下文与64K输出”也包含真实回复与重新生成记录。
- 仅对这套资产提供兼容适配，不是完整酒馆助手／提示词模板替代品。

## 重新启动

在项目目录执行（当前服务已运行，不要重复启动）：

```sh
pnpm exec concurrently --kill-others "pnpm dev:api" "pnpm --filter @tavern/mobile dev"
```

打开网页后，服务地址保持 `/api`。访问密钥取根目录私密 `.env` 中的 `AUTH_API_KEYS` 值；在“连接设置”粘贴并连接。网页只在当前浏览器会话中保存此访问密钥。`LLM_API_KEY` 是模型密钥，不能填到网页。

`.env`、`.local/`、数据库和构建产物都不提交版本库。不要把这些私密文件放进网页 public 目录。模型地址与密钥只在后端使用。

## 从原始资产准备环境

需要 Node >= 22.22.2 与 pnpm >= 9。仓库的 packageManager 固定 pnpm 9.15.4；本机当前 Node 26 的 SQLite 原生模块已成功编译。

```sh
pnpm install --frozen-lockfile
python3 scripts/prepare-mobile.py --card '/你的角色卡.png' --preset '/你的预设.json'
pnpm dev:api
```

API 启动后，在另一个终端：

```sh
python3 scripts/bootstrap-mobile.py
pnpm --filter @tavern/mobile dev
```

`prepare-mobile.py` 默认从相邻原版酒馆的 default-user 数据目录读取当前直连 DeepSeek 配置；其他连接类型需自行配置 `.env`，脚本不会猜测目标地址。已有 `.env` 不覆盖。

bootstrap 适用于这套预设：将单角色轨道 100001 映射为后端活动轨道；四处 `model` 规范化为 `assistant`；无深度限制 `null` 规范化为 `-1`。两组正则仅选择 `extensions.regex_scripts`，不叠加 SPreset 规则。原始资产保存在 `.local/`，不覆盖原文件。

再次运行 bootstrap 会校准这套原型预设副本的 1M / 64K 默认值与原始 31 项启用顺序；不在原活动轨道中的条目显式禁用，以避免上游 editor 自动补为启用。该脚本用于标准原型资产，不用于保留用户另行编辑的启用顺序；自行调整预设后不要用它覆盖配置。

## 验证命令

```sh
pnpm exec tsc -b packages/shared packages/core packages/adapters-sillytavern
pnpm --filter @tavern/api typecheck
pnpm --filter @tavern/mobile build
pnpm exec vitest run apps/api/src/services/__tests__/prompt-assembler.test.ts apps/api/src/services/__tests__/turn-commit-service.test.ts apps/api/src/services/st-macros/runtime.test.ts apps/api/src/services/st-macros/write-macros.test.ts packages/adapters-sillytavern/src/__tests__/regex-engine.test.ts packages/adapters-sillytavern/src/__tests__/preset-parser.test.ts apps/api/src/services/__tests__/prompt-runtime/regex/runtime-facade.test.ts
```

构建后的静态目录是 `apps/mobile/dist/`。当前 `/api` 代理由 Vite 开发服务提供；正式部署时需要相应的反向代理，不能直接用 Vite preview 代替部署。

## 已知行为

- 生成中的连接若断开，上游可能取消尚未提交的回合；网页恢复服务端历史，不自动重发，也不承诺恢复已丢失的流式片段。
- 原型请求上限为 65,536 token。长输出仍可能受 180 秒模型调用超时等限制；完整 64K 输出和接近 1M 输入未做压力验收。
- 复测仍观察到一次模型空正文。后端已拒绝无工具结果的空聊天回复，重新生成也不会用空正文覆盖旧回复。空正文的确切原因仍需结合 provider 结束原因与用量诊断，不能一概认定预算耗尽。
- 已经在保护修复前产生的一次空回复保留在归档验证记录中，不作为通过样本。
- 历史选项不可直接发送；此预设还会隐藏深度 >= 1 的选项，因此通常只显示最新行动面板。
- 普通消息只渲染安全 Markdown；完整 HTML/JS 仅适配已知的夏瑾行动面板。任意其他 HTML 卡、MVU、EJS 与酒馆助手脚本不在兼容承诺内。
- 新建其他角色时沿用当前原型资产配置；完整多角色资产管理尚未提供。建议首版只使用已导入的角色。
- 时间线当前使用 SDK 默认单页上限 200；超长会话完整分页列入客户端计划。
