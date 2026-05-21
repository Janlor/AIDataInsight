# AIDataInsight Apple

`app-apple` 是 AIDataInsight 的现代 Apple 全平台实现。它不是 UIKit `app-ios` 的迁移工程，而是基于 `docs/cross-platform/contracts` 重新组织的 SwiftUI / Swift Package first 项目，用于覆盖 iOS、iPadOS、macOS，并为 visionOS 保留同一套业务基础。

## 当前状态

截至 2026-05-21，`app-apple` 已完成可使用版本的收尾工作，并标注为跨平台契约 `0.2.1` 已对齐。

已落地能力：

- 登录、自动登录、隐私协议、设置、退出登录。
- Keychain-backed `AccountSession` / `AccountUser` 持久化，避免已登录启动时闪现登录页。
- AI Chat 模板问题、新对话、历史会话恢复、反馈。
- 推荐问题调用 `/chat/function`，解析 function 返回的 JSON 字符串参数，再调用业务图表接口渲染 SwiftUI 图表。
- iPhone compact 聊天页使用紧凑消息气泡和左侧历史抽屉。
- iPadOS / macOS 使用更适合大屏的分栏工作台。
- 历史列表支持分组、分页、选择恢复、上下文菜单删除；macOS 支持右键菜单删除。
- macOS 设置入口收敛到系统菜单 / commands 语义，避免把移动端设置页直接搬到桌面端。
- New Chat 在已处于空白新对话时进入不可交互状态。

已知后续优化：

- iPhone 聊天页全屏横向抽屉手势已可用，但横向手势识别过程中仍可能与内部纵向滚动或点击同时响应，后续可继续细化 gesture arbitration。
- 需要继续补充真实设备 / 多窗口 / Dynamic Type / visionOS 的视觉 smoke test。
- XCTest UI Tests 仍可继续扩展，当前主要依赖 Swift package tests 与 Xcode build smoke。

## Stack

- SwiftUI
- Observation
- Swift Concurrency
- SwiftData
- Keychain
- Swift Charts
- Swift Testing
- XCTest UI Tests
- Swift Package Manager

## Structure

```text
app-apple/
  README.md
  contract-alignment.json
  AIDataInsightApple/
    AIDataInsightApple.xcodeproj
    AIDataInsightApple/
    AIDataInsightAppleTests/
    AIDataInsightAppleUITests/
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

## Contract Alignment

当前对齐文件：

- `app-apple/contract-alignment.json`
- `docs/cross-platform/contracts/contract-manifest.yaml`
- `docs/cross-platform/contracts/migrations/0.2.1-ai-home-history-interaction-polish.yaml`

验证契约对齐：

```sh
scripts/validate-cross-platform-contracts.sh
scripts/generate-cross-platform-contracts.sh
scripts/check-contract-alignment.sh app-apple
```

## Validation

从仓库根目录验证契约：

```sh
scripts/check-contract-alignment.sh app-apple
```

从 `app-apple/AIDataInsightApple` 验证 app smoke build：

```sh
xcodebuild -scheme AIDataInsightApple -destination generic/platform=iOS build
xcodebuild -scheme AIDataInsightApple -destination platform=macOS build
```

从各 Swift package 目录验证单元测试：

```sh
env SWIFTPM_MODULECACHE_PATH=/private/tmp/swiftpm-module-cache \
  CLANG_MODULE_CACHE_PATH=/private/tmp/clang-module-cache \
  swift test
```

## Architecture Plan

实现计划和收尾状态见：

- [docs/architecture/apple-platform-implementation-plan.md](../docs/architecture/apple-platform-implementation-plan.md)
