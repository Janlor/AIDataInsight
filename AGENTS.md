# Repository Guidelines

## Project Structure & Module Organization

AIDataInsight is a contract-first, multi-platform data analysis app. Shared contracts, schemas, use cases, fixtures, and design rules live under `docs/cross-platform/contracts`; update these before changing generated models. Platform implementations are split by directory: `api-server/` is the FastAPI backend, `app-web/` is Next.js, `app-android/` is Gradle/Kotlin, `app-ios/` is UIKit, `app-apple/` is SwiftUI multi-platform, and `app-harmony/` is HarmonyOS NEXT ArkTS. Root `scripts/` contains contract generation and validation utilities. Documentation images are in `images/`.

## Build, Test, and Development Commands

- `cd api-server && uvicorn app.main:app --host 127.0.0.1 --port 3000 --reload`: run the local backend.
- `cd api-server && pytest`: run backend API tests.
- `cd app-web && pnpm dev:local`: run Web against the local backend.
- `cd app-web && pnpm lint && pnpm typecheck && pnpm test && pnpm build`: run Web gates.
- `cd app-web && pnpm e2e`: run Playwright E2E tests.
- `cd app-android && ./gradlew :app:assembleDebug`: build Android.
- `./scripts/generate-cross-platform-contracts.sh`: regenerate platform contract models.
- `./scripts/validate-cross-platform-contracts.sh`: validate cross-platform contract alignment.

## Coding Style & Naming Conventions

Keep generated files generated; do not hand-edit files such as `app-web/src/contracts/generated/models.ts` or platform contract outputs. Web uses TypeScript, React, Tailwind CSS, ESLint, and `*.test.ts` Vitest tests. Backend code stays inside `api-server/app` with clear FastAPI/SQLModel boundaries. Android follows Kotlin/Compose module boundaries, Swift follows each Apple project layout, and Harmony uses ArkTS boundaries described in its README. Prefer feature-oriented names like `history-mappers.ts`, `use-ai-chat-controller.ts`, and `FeaturePrivacyTests.swift`.

## Testing Guidelines

Place tests next to the relevant implementation when that is the existing pattern. Web unit tests use Vitest with `*.test.ts`; E2E tests live in `app-web/tests/e2e`. Backend tests live in `api-server/tests`. Android unit tests run per Gradle module. When changing contracts or mappers, update fixture/golden coverage and run contract validation.

## Commit & Pull Request Guidelines

Recent commits use short Conventional Commit-style prefixes such as `feat:`, `fix:`, `test:`, and `docs(app-web):`. Keep messages imperative and specific. Pull requests should describe affected platform(s), list validation commands run, link issues or contract changes, and include screenshots or recordings for visible UI changes.

## Security & Configuration Tips

Local development defaults to `api-server` with demo credentials `demo` / `demo@123`. Do not commit local databases, secrets, or `.env.local` files. For real devices, replace loopback URLs with the host machine LAN IP; Android Emulator uses `http://10.0.2.2:3000`.
