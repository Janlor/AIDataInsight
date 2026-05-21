# app-apple 现代 Apple 全平台实现计划

## 文档定位

这份文档用于指导 `app-apple` 的创建和实现。

`app-apple` 不是当前 UIKit `app-ios` 的迁移工程，而是一个从跨平台契约重新生成的现代 Apple 全平台项目。它的目标是作为 AIDataInsight 的 Apple 全平台 SwiftUI 参考实现，同时也是一个可学习、可演进的中大型 Apple 工程架构样本。

当前 UIKit `app-ios` 继续保留为真实行为参考端和契约提炼来源，但 `app-apple` 不复用它的 `UIViewController`、UIKit Router、BaseUI、Cell、TableView、CollectionView 或 UIKit 图表视图。

源事实优先级：

1. `docs/cross-platform/contracts`
2. `docs/cross-platform/contracts/fixtures`
3. `docs/cross-platform/contracts/design/tokens.json`
4. `docs/cross-platform/api-contract.md`
5. `docs/cross-platform/domain-models.md`
6. `app-ios` 已验证的真实行为

如果 `app-apple` 实现时发现契约缺失，应先补充跨平台契约和 fixtures，再实现端侧代码。

## 目标

`app-apple` 的目标平台：

- iOS 17+
- iPadOS 17+
- macOS 14+
- visionOS 1.0+

核心技术栈：

- SwiftUI
- Observation
- Swift Concurrency
- URLSession
- SwiftData
- Keychain
- Swift Charts
- Swift Testing
- XCTest UI Tests
- Swift Package Manager

依赖策略：

- 首版尽量零三方。
- 不引入 TCA、RxSwift、Alamofire、Moya、第三方 DI 容器或第三方持久化框架。
- Apple 原生能力明显不足时，再单独评估是否引入小型三方库。

架构目标：

- 使用 Apple 官方技术栈组织一个中大型项目。
- 外层采用 Feature + Core Packages。
- 包内保持 Domain / Application / Data / Presentation 边界。
- 用 SwiftUI、Observation、SwiftData、Swift Testing 展示现代 Apple 项目的推荐实践。
- 在 iPhone、iPadOS、macOS、visionOS 上共享业务能力，但让 presentation shell 尊重各平台体验。

## 当前收尾状态

截至 2026-05-21，`app-apple` 已经从实施计划进入可使用状态，跨平台契约标注为 `0.2.1` 已对齐。

已完成：

- SwiftUI package-first 工程、App 入口、Root composition、Feature/Core packages。
- 登录、自动登录、隐私协议、设置、退出登录与 Keychain-backed session / user storage。
- AI Chat 模板问题、新对话、历史会话恢复、`/chat/function` function analysis、业务图表接口分发、SwiftUI 图表渲染、反馈。
- 推荐问题交互与其他端保持 welcome 卡片语义，不直接替换首屏上下文。
- iPhone compact 聊天气泡、底部输入区、左侧历史抽屉和紧凑导航。
- iPadOS / macOS regular 分栏工作台。
- 历史列表分组、分页、选择恢复、上下文菜单删除；macOS 补齐右键菜单删除。
- macOS 设置入口采用系统菜单 / commands 语义，移动端设置继续使用页面或 sheet。
- New Chat 按钮在当前已是空白新对话时进入不可交互状态。
- 跨平台契约新增 `0.2.1-ai-home-history-interaction-polish` migration，并在 `app-apple/contract-alignment.json` 标注已应用。

已验证：

- `scripts/validate-cross-platform-contracts.sh`
- `scripts/generate-cross-platform-contracts.sh`
- `scripts/check-contract-alignment.sh app-apple`
- `xcodebuild -scheme AIDataInsightApple -destination generic/platform=iOS build`
- `xcodebuild -scheme AIDataInsightApple -destination platform=macOS build`
- `FeatureAIChat` / `FeatureHistory` 等核心 package 的 `swift test`

仍建议后续继续跟进：

- iPhone 聊天页全屏横向抽屉手势与内部纵向滚动、点击事件的完全互斥。
- visionOS 真机或模拟器 smoke build 与视觉验证。
- 更完整的 XCTest UI Tests、截图回归、Dynamic Type 和辅助功能验证。
- 生产环境配置、错误空态、弱网与刷新 token 的更完整端到端验证。

## 官方技术依据

Apple 官方文档：

- SwiftUI: https://developer.apple.com/documentation/swiftui
- SwiftUI apps: https://developer.apple.com/documentation/technologyoverviews/swiftui
- Observation: https://developer.apple.com/documentation/observation
- SwiftData: https://developer.apple.com/documentation/swiftdata
- Swift Testing: https://developer.apple.com/documentation/testing
- Xcode Testing: https://developer.apple.com/documentation/xcode/testing
- NavigationSplitView: https://developer.apple.com/documentation/swiftui/navigationsplitview

这些文档约束本项目的默认方向：

- 新项目优先使用 SwiftUI App lifecycle。
- 新 SwiftUI 项目优先使用 `NavigationStack` / `NavigationSplitView`，不使用旧 `NavigationView`。
- Feature state 使用 Observation，而不是把 Combine 作为主状态机制。
- 业务并发使用 structured concurrency。
- 单元测试优先使用 Swift Testing，端到端 UI 测试仍使用 XCTest UI Tests。

## Codex 实施边界

默认由 Codex 负责：

- 生成 `app-apple` 目录结构。
- 生成 Swift package 分层骨架。
- 生成 App 入口、Scene、Commands、Root composition。
- 生成业务源码、测试、README 和文档。
- 接入跨平台契约、fixtures 和 design tokens。
- 持续运行可用的 Swift package tests 和静态检查。

壳工程生成策略：

1. 首选：Codex 生成 `app-apple` Swift package-first 架构，再生成或补齐 Xcode project / workspace 配置。
2. 如果当前命令行没有完整 Xcode 或 project 文件生成风险过高，用户可用 Xcode 26.5 创建官方 Multiplatform SwiftUI App 空模板。
3. 用户创建空模板后，Codex 接管全部源码和 package 组织。

当前本地环境提示：

- 当前命令行 `xcodebuild` 可能指向 CommandLineTools 而不是完整 Xcode。
- Swift toolchain 可用时，可先生成和验证 local Swift packages。
- 真正的多平台 App target、simulator、UI Tests 需要完整 Xcode 环境验证。

## 总体架构

采用 Feature + Core Packages：

```text
app-apple/
  AIDataInsightApple.xcodeproj
  AIDataInsightApple/
    AIDataInsightAppleApp.swift
    AppScene.swift
    AppCommands.swift
    AppEnvironment.swift
    Assets.xcassets
  Packages/
    AppCore/
    AppContracts/
    AppDesignSystem/
    AppNetworking/
    AppPersistence/
    AppAccount/
    FeatureLogin/
    FeatureAIChat/
    FeatureHistory/
    FeatureSetting/
    FeaturePrivacy/
    AppTestingSupport/
```

依赖方向：

```text
AIDataInsightApple App
-> Feature*
-> AppAccount / AppNetworking / AppPersistence / AppDesignSystem / AppCore
-> AppContracts

AppTestingSupport
-> AppContracts / AppCore
```

禁止依赖方向：

- `AppContracts` 不依赖任何业务包。
- `AppCore` 不依赖 feature 包。
- `AppNetworking` 不依赖 SwiftUI。
- `AppPersistence` 不依赖 SwiftUI feature view。
- Feature View 不直接依赖 URLSession、SwiftData context 或 Keychain。
- `app-apple` 不依赖 `app-ios` 的 Swift package。

## Package 职责

### AppContracts

职责：

- 承载从 `docs/cross-platform/contracts` 生成或镜像的 Swift models。
- 提供 contract fixtures 可解码的数据类型。
- 不包含业务编排。

内容：

- Account models
- Environment models
- AI Chat models
- History models
- Setting models
- API envelope models
- Route intent models
- Design token models

规则：

- 生成文件不手改。
- 如果类型不对，先更新 contracts，再重新生成。

### AppCore

职责：

- 应用级基础类型。
- 错误模型。
- 环境枚举。
- 路由意图。
- 时间、ID、日志、平台能力协议。

建议类型：

- `AppEnvironment`
- `AppError`
- `SessionInvalidationReason`
- `RouteIntent`
- `PlatformKind`
- `Logger`
- `ClockProtocol`

### AppDesignSystem

职责：

- 将 design tokens 映射为 SwiftUI 可用 API。
- 提供跨平台视觉基线。
- 提供可复用基础组件。

内容：

- `AppColor`
- `AppTypography`
- `AppSpacing`
- `AppRadius`
- `AppChartPalette`
- `PrimaryButton`
- `StatusPanel`
- `TokenizedBackground`
- `PlatformAdaptiveToolbar`

规则：

- 支持 light / dark。
- 支持 Dynamic Type。
- 不硬编码业务文案。
- 不引入 UIKit / AppKit view 作为默认实现。

### AppNetworking

职责：

- URLSession async/await 网络层。
- 统一 response envelope 解析。
- token 注入。
- token refresh single-flight。
- SSE 解析。
- 网络错误归一化。

建议类型：

- `HTTPClient`
- `HTTPRequest`
- `HTTPMethod`
- `ResponseEnvelope<Data>`
- `APIError`
- `TokenProviding`
- `TokenRefreshCoordinator`
- `SSEClient`
- `SSEEvent`

规则：

- `401` 清理 session 并触发 root route 回登录。
- `402` 触发 refresh，成功后重试原请求。
- refresh 失败时统一 session invalidation。
- 所有 API path 来自 contract 或 repository descriptor。

### AppPersistence

职责：

- SwiftData schema。
- model container factory。
- cache repository。
- user preferences。
- testing in-memory container。

存储边界：

- Keychain 存 access token、refresh token、orgId、AccountUser 等受保护账号信息。
- SwiftData 存非敏感数据：
  - history list cache
  - history detail cache
  - template questions cache
  - local preferences
  - lightweight offline mirrors

规则：

- SwiftData model 不等同于 API DTO。
- SwiftData model 不直接进入 View。
- token 不进入 SwiftData。
- AccountUser 不进入 SwiftData，设置页从 Keychain-backed AccountUserStore 读取本地缓存并静默刷新远程用户信息。

### AppAccount

职责：

- 登录态管理。
- Keychain session storage。
- auto login。
- logout。
- session invalidation。

建议类型：

- `AccountSession`
- `AccountUser`
- `SessionStore`
- `KeychainSessionStore`
- `AccountUserStore`
- `KeychainAccountUserStore`
- `AccountRepository`
- `AccountService`
- `RootSessionCoordinator`

规则：

- `SessionStore` 可被 mock。
- Keychain 访问通过协议隔离，便于测试。
- 登录成功后统一归一化 snake_case token 字段。

### FeatureLogin

职责：

- Login use case adapter。
- Login store。
- Login view state。
- SwiftUI 登录页。

建议结构：

```text
FeatureLogin/
  Domain/
  Application/
  Data/
  Presentation/
  Tests/
```

交互：

- 账号密码输入。
- 隐私协议勾选。
- loading。
- 错误态。
- 登录成功触发 root route 切换。

### FeatureAIChat

职责：

- AI Chat 主流程。
- 模板问题。
- 新聊天。
- 发送消息。
- function analysis。
- chart loading。
- SSE streaming。
- feedback。

建议类型：

- `AIChatStore`
- `AIChatViewState`
- `ChatMessageViewState`
- `LoadTemplateQuestionsUseCase`
- `SendMessageUseCase`
- `StreamMessageUseCase`
- `LoadChartUseCase`
- `FeedbackUseCase`

规则：

- Store 使用 `@Observable` 和 `@MainActor`。
- SSE chunk 进入 Store 后以可控节奏更新 UI。
- 图表先使用 Swift Charts。
- 如果 Swift Charts 无法表达契约能力，再局部自定义 SwiftUI chart view。

### FeatureHistory

职责：

- 历史会话列表。
- 分组。
- 分页。
- 删除单条。
- 清空。
- 选择历史恢复 Chat。

规则：

- History 是 AI 工作台的一部分，不是完全独立的主产品。
- iPhone 可作为独立页面或 sheet。
- iPad/macOS/visionOS 作为 sidebar 或 split view column。

### FeatureSetting

职责：

- 账户信息。
- 应用版本。
- 隐私入口。
- 退出确认。
- 后续偏好设置入口。

规则：

- 使用 SwiftUI `Form` 或自定义 tokenized list。
- macOS 可映射到 Settings scene 或 command。

### FeaturePrivacy

职责：

- 隐私政策展示。
- 登录前后可访问。
- 内容来自 contract 或 repository。

规则：

- 不因已登录用户从设置进入而回登录。
- 支持长文本滚动、Dynamic Type 和 macOS selectable text。

### AppTestingSupport

职责：

- fixture loader。
- mock repositories。
- mock HTTP client。
- mock Keychain。
- in-memory SwiftData container。
- test clock。

规则：

- 测试工具不能进入 production target。
- fixtures 优先复用 `docs/cross-platform/contracts/fixtures`。

## 状态管理设计

默认使用 Observation。

Store 示例形态：

```swift
@MainActor
@Observable
final class AIChatStore {
    private let service: AIChatService
    private(set) var state: AIChatViewState

    func loadTemplateQuestions() async
    func sendMessage(_ text: String) async
    func startNewChat()
    func restoreHistory(id: String) async
}
```

规则：

- Store 是 feature presentation 的状态边界。
- Store 可以调用 application service / use case。
- Store 不直接拼 URL。
- Store 不直接读写 SwiftData context。
- View 不直接调用 repository。
- ViewState 使用值类型。
- Domain model 与 ViewState 分离。

为什么不采用 TCA：

- TCA 是优秀的三方架构，但本项目以 Apple 原生技术学习为主要目标。
- Observation + Swift Concurrency + Swift Testing 足以支撑本项目的中大型结构。
- 避免未来 Apple 官方方向与三方架构抽象发生偏离。

## 数据流

统一数据流：

```text
SwiftUI View
-> @Observable FeatureStore
-> Application Service / UseCase
-> Repository Protocol
-> Network / SwiftData / Keychain Implementation
-> Contract / Domain Mapper
-> Feature ViewState
-> SwiftUI View
```

原则：

- UI 消费 ViewState。
- UseCase 消费 Domain。
- Repository 处理 DTO / persistence model。
- Mapper 是显式层，不隐式散落在 View 中。
- 错误统一映射为 `AppError` 或 feature error state。

## 网络设计

环境矩阵：

| 环境 | 用途 |
| --- | --- |
| mock | Apifox mock，默认学习环境 |
| local | 本地 mock / fixture server |
| dev | 真实 DEV |
| test | 测试环境 |
| pre | 预发 |
| prod | 生产 |

HTTP client 能力：

- base URL 注入。
- header 注入。
- JSON body。
- query encoding。
- request timeout。
- cancellation。
- response envelope decoding。
- trace / tid 保留。

session 行为：

- 登录成功后归一化 token。
- 启动时从 Keychain 恢复 session。
- `401` 清 session。
- `402` refresh 后重试。
- refresh single-flight，避免并发刷新风暴。

SSE 行为：

- 使用 URLSession bytes 或等价 async sequence。
- 解析 `data:` event。
- 输出 chunk stream。
- 支持 cancel。
- 出错时 Store 可进入 retry state。

## SwiftData 设计

SwiftData 用途：

- template questions cache。
- history list cache。
- history detail cache。
- user preferences。
- non-sensitive local mirror。

不使用 SwiftData 存储：

- access token。
- refresh token。
- 密码。
- session secret。

建议 schema：

- `CachedTemplateQuestionSet`
- `CachedHistoryConversation`
- `CachedHistoryMessage`
- `CachedChartPayload`
- `UserPreferenceRecord`

设计规则：

- schema 简洁，不照搬所有远端 DTO。
- cache 允许被清理和重建。
- migration 首版保持最小。
- 所有 SwiftData 测试使用 in-memory container。

## 平台适配

### iPhone

体验目标：

- 单栏。
- Chat first。
- compact width 下 History 使用左侧抽屉，通过按钮或横向手势打开。
- 输入区键盘避让稳定。
- 适配 Dynamic Type。

### iPadOS

体验目标：

- `NavigationSplitView`。
- sidebar 放 History。
- detail 放 Chat。
- 可预留 inspector / setting column。
- 支持横竖屏、Stage Manager、多窗口。

### macOS

体验目标：

- 原生 SwiftUI macOS window。
- toolbar。
- menu commands，设置入口优先放入系统菜单语义。
- keyboard shortcuts。
- context menu。
- hover state。
- 合理最小窗口尺寸。

建议 command：

- New Chat。
- Focus Composer。
- Open History。
- Open Settings。
- Logout。

### visionOS

体验目标：

- Windowed App。
- 不做 Immersive Space 首版。
- 复用 split view 工作台。
- 控件尺寸、间距、滚动舒适。
- 不依赖 hover-only 操作。

## 实施阶段

下面阶段记录的是原始实施拆解。当前 `app-apple` 已完成阶段 0 到阶段 7 的可用版本落地；后续工作以测试扩展、视觉打磨和平台 smoke 为主。

### 阶段 0：工程准备

目标：

- 建立 `app-apple` 基础工程和文档入口。

任务：

1. Codex 创建 `app-apple` 目录。
2. 优先生成 Swift package-first 结构。
3. 在 Xcode project 可生成时补齐 `AIDataInsightApple.xcodeproj`。
4. 如本地 Xcode project 生成不可控，则用户用 Xcode 26.5 创建空模板后由 Codex 接管。
5. 新增 `app-apple/README.md`。
6. 更新根 README，记录 `app-apple` 定位。

验收：

- 目录结构稳定。
- Swift packages 可被 SwiftPM 识别。
- 文档说明如何打开和验证工程。

### 阶段 1：基础包

目标：

- 建立 Core、Contracts、DesignSystem、TestingSupport。

任务：

1. 创建 `AppCore`。
2. 创建 `AppContracts`。
3. 创建 `AppDesignSystem`。
4. 创建 `AppTestingSupport`。
5. 将 design tokens 映射为 Swift 类型。
6. 建立 fixture loader。

验收：

- `swift test` 可跑基础包测试。
- design token 基础映射有测试。
- fixture loader 能读取跨平台 fixtures。

### 阶段 2：网络与账号

目标：

- 完成可测试的 session 和网络基础。

任务：

1. 创建 `AppNetworking`。
2. 实现 response envelope。
3. 实现 HTTP client。
4. 实现 API error mapping。
5. 实现 token refresh coordinator。
6. 创建 `AppAccount`。
7. 实现 Keychain abstraction。
8. 实现 mock session store。

验收：

- `401` / `402` fixtures 测试通过。
- login snake_case token 归一化测试通过。
- refresh single-flight 有单元测试。

### 阶段 3：SwiftData 持久化

目标：

- 建立非敏感缓存层。

任务：

1. 创建 `AppPersistence`。
2. 定义 SwiftData cache schema。
3. 提供 model container factory。
4. 提供 in-memory test container。
5. 实现 template/history/preference cache repository。

验收：

- SwiftData in-memory 测试通过。
- token 不进入 SwiftData schema。

### 阶段 4：Login / Setting / Privacy

目标：

- 完成基础业务闭环。

任务：

1. 实现 `FeatureLogin`。
2. 实现 `FeatureSetting`。
3. 实现 `FeaturePrivacy`。
4. App root 根据 session 切换 Login / Workspace。
5. 登录前后隐私页均可访问。

验收：

- 登录成功进入工作台。
- 自动登录可恢复。
- 退出登录返回 Login。
- 隐私政策不错误跳回登录。

### 阶段 5：AI Chat

目标：

- 完成核心 AI Chat 主链路。

任务：

1. 创建 `FeatureAIChat`。
2. 加载模板问题。
3. 新聊天。
4. 发送自然语言消息。
5. 调用 function analysis。
6. 动态分发 chart endpoint。
7. Swift Charts 展示图表。
8. SSE 流式回复。
9. 点赞 / 点踩 feedback。

验收：

- contract AI Chat fixtures 可驱动 Store 状态。
- 发送消息后能看到文本或图表响应。
- 流式响应可取消和失败重试。

### 阶段 6：History 与多栏工作台

目标：

- 完成跨平台工作台体验。

任务：

1. 创建 `FeatureHistory`。
2. 实现历史分组、分页、删除、清空。
3. 选择历史恢复 Chat。
4. iPhone 单栏。
5. iPad/macOS/visionOS split view。
6. macOS command 和快捷键。

验收：

- History 与 Chat 状态协调稳定。
- 选择历史不销毁当前工作台 root。
- iPad/macOS/visionOS 具有桌面式工作台体验。

### 阶段 7：测试与收尾

目标：

- 形成可持续演进的质量体系。

任务：

1. Swift Testing 覆盖 mapper、store、use case、cache。
2. XCTest UI Tests 覆盖主流程。
3. 建立 smoke test scheme。
4. 补齐 README。
5. 补齐架构图和学习笔记。
6. 更新根 README 和跨平台文档索引。

验收：

- 核心 Swift package tests 通过。
- App 端主流程 UI Tests 通过。
- 四个平台可编译运行。

## 测试计划

### Swift Testing

覆盖：

- Contract fixtures decode。
- API envelope 解析。
- `401` / `402` session 行为。
- LoginStore 状态流转。
- AIChatStore 发送、流式、图表、失败。
- HistoryStore 分页、删除、清空。
- SwiftData in-memory cache。
- Keychain session mock adapter。

要求：

- 使用 `@Test`。
- 使用 `#expect`。
- 异步测试使用 async test。
- 支持参数化 fixture 测试。

### XCTest UI Tests

覆盖：

- iPhone 登录到 Chat。
- iPad 多栏 History + Chat。
- macOS 菜单和快捷键 smoke test。
- visionOS window smoke test。
- Privacy 登录前后访问。
- Setting 退出登录回到 Login。

定位：

- Swift Testing 负责业务逻辑。
- XCTest UI Tests 负责真实 App 交互和平台 smoke。

## 验收标准

首版完成时必须满足：

- `app-apple` 可在 iOS 17+、iPadOS 17+、macOS 14+、visionOS 1.0+ 编译运行。
- 主链路不依赖 UIKit。
- 不引入三方架构库。
- token 不进入 SwiftData。
- UI 遵守跨平台 design tokens。
- 业务事实来自 `docs/cross-platform/contracts`。
- 当前 `app-ios` 只作为行为参考，不作为源码依赖。
- Swift Testing 覆盖核心业务逻辑。
- XCTest UI Tests 覆盖主流程。
- README 能指导新工程师理解结构、运行和测试。

## 风险与应对

### Xcode project 生成风险

风险：

- 手写 `.xcodeproj/project.pbxproj` 容易出错。
- 当前命令行环境可能未启用完整 Xcode。

应对：

- 优先 package-first。
- 在 SwiftPM 层先完成可测试业务骨架。
- 必要时由用户用 Xcode 26.5 创建空 Multiplatform SwiftUI App 模板，再由 Codex 接管源码。

### 契约不足

风险：

- `app-apple` 需要的平台状态、文案或图表规则没有进入 contracts。

应对：

- 先更新 `docs/cross-platform/contracts`。
- 补 fixtures。
- 再实现 `app-apple`。

### SwiftData 过度使用

风险：

- 为了学习 SwiftData，把远端 DTO 和敏感 session 都塞进本地数据库。

应对：

- SwiftData 只做非敏感缓存和偏好。
- Keychain 管理 token。
- SwiftData model 与 DTO 分离。

### SwiftUI 多平台抽象过度

风险：

- 为了复用代码，把所有平台写成同一套 UI，导致 macOS / visionOS 体验不自然。

应对：

- 共享 Store、UseCase、DesignSystem。
- 平台 shell 可分化。
- 使用 conditional presentation，而不是复制业务逻辑。

## 建议提交顺序

1. `Add app-apple architecture plan`
2. `Scaffold app-apple package workspace`
3. `Add app-apple core contracts and design tokens`
4. `Add app-apple networking and session foundation`
5. `Add app-apple SwiftData persistence layer`
6. `Add app-apple login setting privacy flows`
7. `Add app-apple AI chat flow`
8. `Add app-apple history workspace`
9. `Add app-apple platform smoke tests`
10. `Finalize app-apple documentation`
