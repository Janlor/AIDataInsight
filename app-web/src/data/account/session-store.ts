'use client';

import { create } from 'zustand';
import type { AccountSession, AccountUser } from '@/contracts/generated/models';
import { configureHttpAuthBridge } from '@/data/http/http-client';
import { toAppError } from '@/domain/errors';
import { getUserInfo, loginAccount, logoutAccount, refreshAccountSession } from './account-api';
import { mergeUserIntoSession, normalizeOAuthSession } from './account-mappers';
import { emptySession, type LoginInput } from './account-types';
import { clearAccountState, readAccountState, writeAccountState } from './session-storage';

interface AccountStore {
  session: AccountSession;
  user: AccountUser | null;
  isHydrated: boolean;
  hydrate: () => void;
  login: (input: LoginInput) => Promise<void>;
  logout: () => Promise<void>;
  refreshToken: () => Promise<boolean>;
  clearSession: () => void;
  loadUserInfo: () => Promise<void>;
}

export const useAccountStore = create<AccountStore>((set, get) => ({
  session: emptySession,
  user: null,
  isHydrated: false,

  hydrate: () => {
    // 首次进入客户端后从 localStorage 恢复账号状态，避免 SSR 阶段访问 window。
    const state = readAccountState();
    set({ ...state, isHydrated: true });
  },

  login: async (input) => {
    const session = await loginAccount(input);
    const nextState = { session, user: null };
    set(nextState);
    writeAccountState(nextState);
    // 登录成功后尽量补齐用户资料；失败不阻断进入主界面。
    await get().loadUserInfo().catch(() => undefined);
  },

  logout: async () => {
    try {
      await logoutAccount();
    } finally {
      get().clearSession();
    }
  },

  refreshToken: async () => {
    const current = get().session;
    if (!current.refreshToken) {
      // 没有 refresh token 时无法续期，直接清空本地状态。
      get().clearSession();
      return false;
    }

    try {
      const refreshed = await refreshAccountSession(current.refreshToken);
      // refresh 接口可能只返回 token 字段，因此用当前会话补齐用户名等信息。
      const session = normalizeOAuthSession(refreshed, current);
      const nextState = { session, user: get().user };
      set(nextState);
      writeAccountState(nextState);
      return session.isLogin;
    } catch (error) {
      const appError = toAppError(error);
      if (appError.code === 401 || appError.code === 402) {
        // refresh token 失效时和移动端一致：清空会话，等待路由守卫跳回登录页。
        get().clearSession();
      }
      return false;
    }
  },

  clearSession: () => {
    clearAccountState();
    set({ session: emptySession, user: null, isHydrated: true });
  },

  loadUserInfo: async () => {
    const user = await getUserInfo();
    // 用户资料会同步写入 session.username，侧边栏和设置页都依赖这个展示名。
    const session = mergeUserIntoSession(get().session, user);
    const nextState = { session, user };
    set(nextState);
    writeAccountState(nextState);
  },
}));

configureHttpAuthBridge({
  // 将账号 store 能力桥接给 HTTP 层，避免 HTTP 层反向 import store 内部实现。
  getAccessToken: () => useAccountStore.getState().session.accessToken ?? null,
  refreshToken: () => useAccountStore.getState().refreshToken(),
  clearSession: () => useAccountStore.getState().clearSession(),
});
