# HarmonyOS NEXT 模块边界

这份文档记录 `app-harmony` 第一阶段骨架的职责边界，避免后续 AI 生成代码时把业务逻辑写进页面。

## app

- 应用壳、全局页面入口、路由 destination。
- 不直接解析接口 DTO。
- 不直接持久化 session。

## contracts/generated

- 只放契约生成产物。
- 不手改。
- 由 `docs/cross-platform/contracts` 驱动。

## core/model

- 聚合 generated models 和本端轻量类型别名。
- 不依赖 ArkUI 页面。

## core/network

- 负责 local `api-server` baseURL、真实 HTTP transport、请求、响应外壳和错误处理。
- 子模块 path 放在对应 feature 的 repository / API descriptor 语义中。
- AIChat `/stream` 当前按完整响应解析；实时 SSE / 打字机效果可作为后续体验优化。

## core/account

- 负责 session store、自动登录判断、登录态清理。
- 不负责渲染 Login 或 Setting。

## core/ui

- 负责主题 token、背景、安全区、基础控件。
- 不包含业务 use case。

## feature/*

- 每个 feature 后续按 `domain -> data -> application -> presentation/page state -> page` 演进。
- 页面只消费 page state，不直接解析 DTO。
