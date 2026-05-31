import type { AccountUser } from '@/contracts/generated/models';
import { emptySession, type AccountState } from './account-types';

const STORAGE_KEY = 'aidatainsight.web.account';

export function readAccountState(): AccountState {
  if (typeof window === 'undefined') {
    // SSR 阶段没有 localStorage，返回空会话等待客户端 hydrate。
    return { session: emptySession, user: null };
  }

  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) {
    return { session: emptySession, user: null };
  }

  try {
    const parsed = JSON.parse(raw) as Partial<AccountState>;
    const accessToken = parsed.session?.accessToken ?? null;
    // 只信任必要字段，避免旧版本 localStorage 结构污染运行时状态。
    return {
      session: {
        accessToken,
        refreshToken: parsed.session?.refreshToken ?? null,
        orgId: parsed.session?.orgId ?? null,
        username: parsed.session?.username ?? null,
        isLogin: Boolean(accessToken),
      },
      user: normalizeUser(parsed.user),
    };
  } catch {
    // 本地缓存损坏时主动清理，防止反复解析失败。
    clearAccountState();
    return { session: emptySession, user: null };
  }
}

export function writeAccountState(state: AccountState) {
  if (typeof window === 'undefined') {
    return;
  }
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

export function clearAccountState() {
  if (typeof window === 'undefined') {
    return;
  }
  window.localStorage.removeItem(STORAGE_KEY);
}

function normalizeUser(user: AccountUser | null | undefined): AccountUser | null {
  // 预留归一化入口，后续如果用户字段扩展可以集中兼容。
  if (!user) {
    return null;
  }
  return user;
}
