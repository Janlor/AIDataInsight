# core/network

封装 local `api-server` baseURL、真实 HTTP 请求、响应外壳、错误处理和 token 刷新协作。

当前已实现：

- `ApiEnvironmentProvider.ets`：读取契约中的 mock baseURL，并负责拼接接口路径。
- `ApiEnvelope.ets`：统一接口响应外壳。
- `ApiError.ets`：统一错误类型，固定 401 / 402 的 session 语义。
- `CommonRequester.ets`：统一请求入口，通过 `HttpTransport` 解耦真实网络实现。
- `HarmonyHttpTransport.ets`：基于 HarmonyOS NetworkKit 的真实 HTTP transport。
- `MockHttpTransport.ets`：用于本地测试和 mock 链路验证。

规则：

- feature repository 不能自己拼 baseURL。
- mock URL 来自契约生成模型，不写死在子模块。
- 生产代码默认使用 `HarmonyHttpTransport`，测试代码可显式注入 `MockHttpTransport`。
- AIChat `/stream` 当前通过普通 HTTP 获取完整 SSE 文本后解析 `data:` 内容；实时 SSE / 打字机效果可作为后续体验优化。
