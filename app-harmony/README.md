# AIDataInsight HarmonyOS NEXT

AIDataInsight HarmonyOS NEXT 是多端契约的 ArkUI 原生实现端。当前目录已完成主要功能开发，并保留后续 Web 端生成可复用的契约边界。

## 当前状态

- 已建立 `app-harmony` 源码骨架。
- 已固定并生成 ArkTS contract models。
- 已补最小 contract mapper 和 golden fixture 单测。
- 已建立 `core:model`、`core:network`、`core:account`、`core:ui` 基础层。
- 已接入 Login 本地 `api-server` 登录、隐私入口和启动自动登录导航。
- 已补 AIHome 壳层，承接 AIChat 主入口、History 面板和 Setting route。
- 已补 Setting / Privacy 链路，支持账户信息、隐私政策和退出登录。
- 已补 History 本地后端列表链路，支持分组、无感刷新和选择会话。
- 已补 AIChat 本地后端链路，支持模板问题、输入发送、`/stream` 返回文本展示、图表 fallback 和反馈状态。
- 已建立 App 路由、Core、Feature 的命名边界。
- 当前默认连接本地 `api-server` 环境；后续如需接入其它环境，应先更新跨端契约和网络配置。
- 阶段 10 工程收尾已完成；后续工作以 bugfix、UI 细节和 SSE 体验优化为主。

## 目录结构

```text
app-harmony
├── README.md
├── docs
└── entry/src/main/ets
    ├── app
    │   ├── navigation      # AppDestination、导航状态和路由意图适配
    │   └── pages           # AIHome 等 App 壳页面
    ├── contracts/generated # 后续由契约生成的 ArkTS models
    ├── core
    │   ├── model           # 本端模型聚合入口
    │   ├── network         # local api-server baseURL、真实 HTTP transport、响应外壳、错误处理
    │   ├── account         # session store、自动登录判断
    │   └── ui              # 主题、背景、安全区、通用组件
    └── feature
        ├── login
        ├── setting
        ├── privacy
        ├── history
        └── ai_chat
```

## 生成目标

`scripts/generate-cross-platform-contracts.sh` 已支持输出 ArkTS contract models：

```text
app-harmony/entry/src/main/ets/contracts/generated/ContractModels.ets
```

不要手改生成文件。模型不对时先改 `docs/cross-platform/contracts`，再运行生成脚本。

## 开发规则

- 先读 `docs/ai-generation-guide.md`。
- 再读 `docs/architecture/harmonyos-next-implementation-plan.md`。
- HarmonyOS NEXT 工程说明优先读 `app-harmony/README.md` 和 `app-harmony/docs/module-boundaries.md`。
- HarmonyOS NEXT 只能从已验证契约生成，不能从 iOS UIKit 或 Android Compose 页面反推。
- ArkTS 不是 TypeScript，不能直接复制 Web 代码。
- 当前开源版本以本地 `api-server` 和 DevEco 构建验证为准。

## 验证

常用收尾验证：

```sh
ruby scripts/validate-cross-platform-contracts.rb
env DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk NODE_HOME=/Applications/DevEco-Studio.app/Contents/tools/node /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --mode module -p module=entry assembleHap --no-daemon
```

## 已知边界

- 当前默认接入本地 `api-server` URL：`http://127.0.0.1:3000`。真机调试时请改成电脑局域网 IP。
- `/stream` 当前按完整响应解析 `data:` 内容并一次性展示；实时 SSE / 打字机效果可作为后续体验优化。
- 后续维护以 bugfix、UI 细节、SSE 体验优化和 Web 端推进为主。
