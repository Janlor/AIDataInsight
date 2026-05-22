# AIDataInsight Web

这个目录是 AIDataInsight Web 端工程，基于 Next.js App Router、React、TypeScript 和 Tailwind CSS 搭建。

Web 端实现应该从下面这些源事实开始：

- `src/contracts/generated/models.ts`
- `docs/cross-platform/contracts/api/openapi.yaml`
- `docs/cross-platform/contracts/usecases/*.usecases.yaml`
- `docs/cross-platform/contracts/fixtures/**/*`

不要从 iOS UIKit 页面反推 Web 的领域模型或 use case 输出。如果缺少某个模型或行为，先更新 `docs/cross-platform/contracts`，再运行：

```sh
scripts/generate-cross-platform-contracts.sh
```

## 开发命令

```sh
pnpm install
pnpm dev
pnpm dev:mock
pnpm dev:local
pnpm typecheck
pnpm test
pnpm build
```

推荐本地提交前执行：

```sh
pnpm lint
pnpm typecheck
pnpm test
pnpm build
pnpm e2e
```

## 环境配置

默认不配置环境变量时，Web 端使用本地 `api-server`。

环境由 `NEXT_PUBLIC_APP_ENV` 和 `NEXT_PUBLIC_API_BASE_URL` 控制：

| 环境 | 用途 | 默认 base URL |
| --- | --- | --- |
| `local` | 默认本地开发，使用独立 `api-server` | `http://127.0.0.1:3000` |
| `mock` | Apifox mock 回退环境 | `https://m1.apifoxmock.com/m1/3174267-1700689-default` |
| `dev` | 真实 DEV 后端 | 必须显式配置 |
| `test` / `sit` / `uat` | 测试环境 | 必须显式配置 |
| `pre` | 预发环境 | 必须显式配置 |
| `prod` | 生产环境 | 必须显式配置 |

常用启动方式：

```sh
pnpm dev:local  # standalone api-server
pnpm dev:mock   # Apifox mock
```

也可以复制对应示例文件为 `.env.local`：

```sh
cp .env.mock.example .env.local
cp .env.local.example .env.local
cp .env.dev.example .env.local
cp .env.test.example .env.local
cp .env.pre.example .env.local
cp .env.prod.example .env.local
```

`dev/test/sit/uat/pre/prod` 如果没有配置 `NEXT_PUBLIC_API_BASE_URL`，启动或构建时会直接报错，避免误打默认 mock。

## 本地后端与 Mock API

使用 `local` 环境前，需要先启动仓库根目录的 `api-server`：

```sh
cd ../api-server
source .venv/bin/activate
uvicorn app.main:app --host 127.0.0.1 --port 3000 --reload
```

Web 内置的 Next.js mock API 仍保留给 Playwright E2E 作为稳定夹具，不替代独立 `api-server`。

它覆盖了第一阶段主链路：

- `POST /oauth2/login`
- `GET /oauth2/refresh`
- `GET /oauth2/logout`
- `GET /oauth2/getUserInfo`
- `GET /chat/template`
- `GET /chat/function`
- `GET /stream`
- `GET /chart/querySalesGroupByMonth`
- `GET /history/page`
- `GET /history/detail`
- `POST /history/like`
- `GET /history/delete`
- `GET /history/deleteAll`

Playwright E2E 固定使用本地 mock：

```sh
pnpm exec playwright install --only-shell chromium
pnpm e2e
```

## 当前进度

已完成第一版 Web 主链路：

- Next.js / React / TypeScript 工程骨架
- Tailwind CSS 基础主题
- `/login`、`/ai`、`/history`、`/setting`、`/privacy` 路由
- Web shell、导航和登录态守卫
- HTTP client、response envelope 和 `401` / `402` session 规则
- 登录、refresh、logout、getUserInfo 账户 API 封装
- 类 ChatGPT 左侧会话栏、New Chat、历史恢复和历史删除
- snake_case token 归一化测试
- `402` refresh 后重试测试
- AI Chat template / function / chart / feedback API 封装
- History page / detail / delete API 封装
- AI Chat 和 History contract fixtures mapper 测试
- AI Chat 发送流程和历史详情恢复
- SSE 流式响应、图表组件和本地 mock API
- Apifox mock / local mock / dev / test / pre / prod 环境矩阵
- 设置弹窗、契约驱动隐私政策、退出登录确认
- 系统深色模式适配
- 简体中文 / English 国际化

## 收尾验收

Web 端进入联调或提交前至少满足：

- `pnpm lint`
- `pnpm typecheck`
- `pnpm test`
- `pnpm build`
- `pnpm e2e`

GitHub Actions 已提供 Web CI workflow，会在 `app-web`、Web 计划文档和跨平台契约变化时运行上述质量门禁。

## 后续建议

- 将 DEV / TEST / PRE / PROD 的真实 `NEXT_PUBLIC_API_BASE_URL` 接入部署平台
- 增加 runtime validation 的覆盖面，优先覆盖 AI Chat、History 和 Setting 的远端响应
- 真实后端联调后补充错误态、超时态和空状态截图回归
