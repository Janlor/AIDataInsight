import type { AccountSession, AccountUser } from '@/contracts/generated/models';
import type { OAuthDto } from './account-types';

export function normalizeOAuthSession(
  dto: OAuthDto | null | undefined,
  previous?: AccountSession | null,
): AccountSession {
  // 后端 mock 和真实接口可能混用蛇形/驼峰字段，这里统一归一化。
  const accessToken = normalizeText(dto?.accessToken ?? dto?.access_token) ?? previous?.accessToken ?? null;
  const refreshToken =
    normalizeText(dto?.refreshToken ?? dto?.refresh_token) ?? previous?.refreshToken ?? null;
  const orgId = dto?.orgId ?? dto?.org_id ?? previous?.orgId ?? null;

  return {
    accessToken,
    refreshToken,
    orgId,
    username: previous?.username ?? null,
    isLogin: Boolean(accessToken),
  };
}

export function mergeUserIntoSession(
  session: AccountSession,
  user: AccountUser | null,
): AccountSession {
  // 会话自身只保证 token，展示用用户名优先从用户资料中补齐。
  return {
    ...session,
    username: user?.username ?? user?.nickname ?? session.username ?? null,
    isLogin: Boolean(session.accessToken),
  };
}

function normalizeText(value: string | null | undefined): string | null {
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
}
