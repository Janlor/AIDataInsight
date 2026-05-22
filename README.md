# AIDataInsight

AIDataInsight 是一个 AI 驱动的数据分析多端应用项目。

项目的核心目标不是“手写多套互相漂移的端侧代码”，而是先设计一套稳定的领域模型、API 契约、业务用例和设计规则，再让 AI 基于这套契约辅助生成 iOS、Android、HarmonyOS NEXT、Web 以及未来候选端实现。

当前 iOS、Android、HarmonyOS NEXT、Web 和现代 Apple 全平台实现已完成主要功能开发，并逐步沉淀为参考实现、契约验收端、ArkUI 原生实现端、桌面工作台实现端和 SwiftUI 多平台参考实现；Windows 暂作为后续候选方向评估。

## 本地后端优先

当前仓库默认开发环境优先使用根目录下的 `api-server`，它是一个本地 FastAPI 后端服务，负责登录、会话、AI Chat function mock、图表数据、历史列表和历史详情持久化。

使用各端 `local` 环境前，先启动本地后端：

```sh
cd api-server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 3000 --reload
```

默认账号：

```text
name: demo
pwd: demo@123
```

默认本地地址：

- Apple 全平台 / iOS 模拟器 / Web / HarmonyOS 本机调试：`http://127.0.0.1:3000`
- Android Emulator：`http://10.0.2.2:3000`
- 真机调试：改为电脑局域网 IP，例如 `http://192.168.x.x:3000`

Apifox mock 仍保留为回退环境，但不再是默认本地开发入口。

## 项目理念

AIDataInsight 的多端开发路线是：

```text
contracts -> generated models -> repository -> usecase -> UI state mapper -> UI
```

也就是说，真正跨端共享的不是 UIKit、Compose、React 或 ArkUI 页面代码，而是：

- 领域模型
- API 契约
- 业务用例
- 动态函数参数规则
- 错误和会话规则
- 路由意图
- 设计 token
- golden fixtures / contract tests

iOS 当前是参考实现，但不是其它端照抄的来源。Android / HarmonyOS NEXT / Web / 未来候选端都应该从 `docs/cross-platform/contracts` 出发，而不是从 iOS 页面、Cell 或 ViewData 反推业务模型。

## 当前端侧策略

当前优先级：

```text
P0 iOS：已完成主要功能，继续稳定和契约化
P1 Android：已完成主要功能，继续作为契约验收端
P2 HarmonyOS NEXT：已完成主要功能开发，后续以 bugfix 和体验优化为主
P3 Web：已完成主要功能开发，进入收尾、联调和体验打磨
P4 Apple 全平台：现代 SwiftUI app-apple 已可用，作为 iOS / iPadOS / macOS / visionOS 参考实现继续打磨
P5 Windows：暂不规划，未来优先 Web / PWA
```

更完整的端侧适配建议见：

- [docs/architecture/platform-adaptation-strategy.md](docs/architecture/platform-adaptation-strategy.md)

## 业务主链路

项目围绕“自然语言提问 -> AI 理解 -> 函数参数解析 -> 数据查询 -> 图表展示 / 对话反馈”这条链路展开。

核心链路包括：

### 函数调用 / 图表分析链路

```text
用户输入
-> Function Analysis
-> FunctionName
-> FunctionArguments
-> /chart/{functionName}
-> HistoryChartDetail
-> ChartPayload
-> 各端图表 UI
```

这条链路已经被固化到契约中：

- `docs/cross-platform/contracts/usecases/ai-chat.usecases.yaml`
- `docs/cross-platform/contracts/domain/ai-chat.schema.json`
- `docs/cross-platform/contracts/fixtures/function-response/*.json`

### 流式回复链路

```text
用户输入
-> StreamAIResponseUseCase
-> SSE / Stream
-> chunk 累积
-> 各端渲染节流
-> 对话气泡增量展示
```

iOS 端当前已落地流式响应和打字机式渲染，Android 已按同一 use case 语义映射到 `Flow`；HarmonyOS NEXT 当前按完整响应解析 `/stream` 的 `data:` 内容并一次性展示，实时 SSE / 打字机可作为后续体验优化；Web 已接入 SSE 流式响应并完成桌面工作台主链路。

## 架构分层

项目按四层理解：

```text
App Shell
Platform Layer
Application Layer
Domain + Data Layer
```

### App Shell

负责：

- 应用入口
- 生命周期
- 模块装配
- 全局导航入口

### Platform Layer

负责：

- 平台路由
- 系统权限
- Keychain / 本地安全存储
- 外部链接
- 平台 UI 基础能力

### Application Layer

负责：

- use case
- 页面状态编排
- 业务流程
- application output

要求：

- 不返回 UIKit / Compose / React / ArkUI UI model
- 不依赖 Controller / View / Cell
- 不直接处理平台控件状态

### Domain + Data Layer

负责：

- 领域实体
- 值对象
- repository 协议
- API DTO
- DTO -> domain mapper
- 动态函数参数解析

## 当前工程结构

```text
AIDataInsight
├── api-server/             # 本地 FastAPI 后端，提供 local 环境接口和 Apifox fixture seed
├── app-ios/                 # iOS App、Swift Package 模块和 iOS 专属文档
├── app-apple/               # 现代 SwiftUI Apple 全平台工程
├── app-android/             # Android Gradle 多模块工程
├── app-harmony/             # HarmonyOS NEXT DevEco / ArkTS 原生工程
├── app-web/                 # Next.js Web 工程、契约生成模型和桌面工作台体验
├── docs/
│   ├── architecture/        # 架构、端侧策略、演进方案
│   └── cross-platform/      # 跨平台契约说明与机器可读契约包
├── images/                  # README 截图
└── scripts/                 # 契约校验、生成和图文档导出脚本
```

## 端侧入口

各端 README 负责说明本端工程结构、运行方式和实现细节：

- iOS 端说明：[app-ios/README.md](app-ios/README.md)
- Apple 全平台说明：[app-apple/README.md](app-apple/README.md)
- Android 端说明：[app-android/README.md](app-android/README.md)
- HarmonyOS NEXT 端说明：[app-harmony/README.md](app-harmony/README.md)
- Web 端说明：[app-web/README.md](app-web/README.md)

iOS 端是当前最完整的参考实现。iOS 专属架构设计、Networking 定稿和组件依赖关系图已经移到 [app-ios/docs](app-ios/docs)，根 README 不再重复展开这些端侧细节。

## Apple 全平台当前状态

`app-apple` 是基于跨平台契约重新实现的现代 SwiftUI 多平台工程，不复用 UIKit `app-ios` 的页面、Router 或 Cell 代码。它当前已进入可用收尾状态，并与契约 `0.2.1` 对齐。

当前已完成：

- iOS 17+、iPadOS 17+、macOS 14+、visionOS 1.0+ 的 SwiftUI package-first 工程
- Login / 自动登录 / Privacy / Setting / logout 链路
- AccountSession 与 AccountUser 的 Keychain 持久化，Setting 先读本地缓存再刷新远端
- AIChat 模板问题、`/chat/function`、动态 chart endpoint、图表渲染、反馈状态和历史详情回放
- iPhone compact 历史抽屉，iPadOS / macOS regular split workspace
- History 分组、分页、选择恢复 Chat、长按 / 上下文菜单 / 右键删除
- iPhone 紧凑聊天气泡与输入框体验、macOS 菜单入口和设置页承载策略
- Swift Testing 包测试和 Xcode build 验证

Apple 全平台说明见 [app-apple/README.md](app-apple/README.md)，实现计划与收尾记录见 [docs/architecture/apple-platform-implementation-plan.md](docs/architecture/apple-platform-implementation-plan.md)。

## Android 当前状态

Android 端已完成主要功能，并作为契约回归端继续使用：

```text
app-android
├── app                 # Android app 壳、导航、AIHome 组合入口
├── core
│   ├── common          # 通用基础代码
│   ├── model           # 契约生成模型
│   ├── network         # Ktor Client、remote service、API 响应处理
│   ├── account         # 登录态、账号会话、账号 remote service
│   ├── ui              # 主题、通用背景、共享 UI token
│   └── testing         # 测试辅助
└── feature
    ├── login
    ├── setting
    ├── privacy
    ├── history
    └── ai-chat
```

当前状态：

- `app-android/core/model/src/main/java/com/aidatainsight/android/core/model/contract/ContractModels.kt`
- Login / Setting / Privacy / History / AIChat / AIHome 已有 Compose 实现
- `core:network`、`core:account` 默认接入本地 `api-server`，可通过 Gradle 参数切换其它后端
- 自动登录、本地 Privacy HTML、主要 ViewModel / UseCase / 导航测试已覆盖
- 后续以契约回归、缺陷修复和体验打磨为主

推荐技术栈：

- Kotlin
- Jetpack Compose
- Navigation Compose
- Coroutines + Flow
- Kotlinx Serialization
- Ktor Client 或 Retrofit

## HarmonyOS NEXT 当前状态

HarmonyOS NEXT 已完成主要功能开发。工程已接入 DevEco Studio / ArkTS / ArkUI，并按契约生成、core 基础层和 feature 链路落地。

当前已完成：

- DevEco 工程骨架与 `entry/src/main/ets` 模块边界
- ArkTS contract models 生成：`app-harmony/entry/src/main/ets/contracts/generated/ContractModels.ets`
- 最小 contract mapper tests / golden fixture tests
- `core:model`、`core:network`、`core:account`、`core:ui`
- Login 本地后端登录、隐私入口、启动自动登录导航
- AIHome 壳层：AIChat 主 surface、History 面板、Setting route
- Setting / Privacy 链路：账户信息、隐私政策、退出登录
- History 本地后端列表链路：今天 / 本月 / 其它分组、无感刷新、选择会话
- AIChat 本地后端链路：模板问题、输入发送、`/stream` 返回文本展示、图表 fallback 和反馈状态
- 阶段 10 收尾：端侧 README、执行清单、AI 生成指南、change log 和工程卫生

推荐技术栈：

- ArkTS
- ArkUI 声明式 UI
- DevEco Studio
- 官方网络能力或项目统一网络封装
- DevEco Studio 单元测试 / UI 测试 / 模拟器验证

当前开源版本默认使用本地 `api-server` 环境；后续 HarmonyOS 工作以 bugfix、UI 细节和 SSE 体验优化为主。

## Web 当前状态

Web 端已完成第一版桌面工作台主链路，并复用跨平台契约生成模型：

- Next.js App Router / React / TypeScript / Tailwind CSS 工程
- local `api-server`、Apifox mock、DEV、TEST、PRE、PROD 环境矩阵
- 登录、自动登录、退出登录和 `401` / `402` session 行为
- 类 ChatGPT 左侧历史会话布局、New Chat、历史恢复和删除
- AI Chat 模板问题、SSE 流式响应、图表 fallback 和反馈
- 设置、隐私政策、深色模式、简体中文 / English 国际化
- Vitest 单元测试和 Playwright E2E 主流程保护

Web 端说明见 [app-web/README.md](app-web/README.md)。

## 桌面端

macOS 原生体验当前优先由 `app-apple` 承担。Web 继续作为跨平台桌面工作台和 E2E 回归端。

Windows 暂不规划。如果未来确实需要桌面端，优先考虑 Web / PWA / Tauri / Electron。

## 跨平台契约包

机器可读契约位于：

- [docs/cross-platform/contracts](docs/cross-platform/contracts)

契约包包括：

```text
contracts/
  domain/       JSON Schema 领域模型
  api/          OpenAPI API 契约
  usecases/     UseCase 输入、输出和业务规则
  ui-state/     平台中立 UI state
  routes/       路由意图
  design/       设计 token
  fixtures/     golden fixtures / contract tests
```

运行契约校验：

```bash
scripts/validate-cross-platform-contracts.sh
```

生成 Android / HarmonyOS NEXT / Web contract models：

```bash
scripts/generate-cross-platform-contracts.sh
```

## AI 生成协议

AI 生成端侧代码时必须遵守固定协议：

- [docs/ai-generation-guide.md](docs/ai-generation-guide.md)

简化流程：

```text
1. 读取 contracts/domain
2. 读取 contracts/api
3. 读取 contracts/usecases
4. 读取 contracts/ui-state
5. 读取 fixtures
6. 读取目标端模块映射
7. 生成 repository
8. 生成 data / mapper
9. 生成 usecase
10. 生成 UI state mapper
11. 最后生成 UI
12. 跑 contract tests 和目标端测试
```

## 重要文档

- iOS 端说明：[app-ios/README.md](app-ios/README.md)
- iOS 专属文档：[app-ios/docs](app-ios/docs)
- Apple 全平台说明：[app-apple/README.md](app-apple/README.md)
- Apple 全平台实现计划：[docs/architecture/apple-platform-implementation-plan.md](docs/architecture/apple-platform-implementation-plan.md)
- 多端适配建议：[docs/architecture/platform-adaptation-strategy.md](docs/architecture/platform-adaptation-strategy.md)
- HarmonyOS NEXT 适配清单：[docs/architecture/harmonyos-next-implementation-plan.md](docs/architecture/harmonyos-next-implementation-plan.md)
- Web 执行计划：[docs/architecture/web-implementation-plan.md](docs/architecture/web-implementation-plan.md)
- AI 生成协议：[docs/ai-generation-guide.md](docs/ai-generation-guide.md)
- 跨平台蓝图：[docs/architecture/cross-platform-blueprint.md](docs/architecture/cross-platform-blueprint.md)
- 领域模型说明：[docs/cross-platform/domain-models.md](docs/cross-platform/domain-models.md)
- API 契约说明：[docs/cross-platform/api-contract.md](docs/cross-platform/api-contract.md)
- 设计 token：[docs/cross-platform/design-tokens.md](docs/cross-platform/design-tokens.md)

## Demo

<img src="./images/history.png" width="402"> <img src="./images/chat.png" width="402">

## 说明

- 当前仓库以 AI 数据分析 Demo、多端架构设计和契约驱动生成实践为主
- iOS 已经具备完整参考实现
- iOS / Android / HarmonyOS NEXT / Web / app-apple 已完成主要功能开发，后续以联调、bugfix 和体验打磨为主
- 当前默认环境使用本地 `api-server`；Web E2E 仍使用内置 local mock 保持稳定回归
- macOS 由 app-apple 原生支持；Windows 暂不作为当前阶段强目标
