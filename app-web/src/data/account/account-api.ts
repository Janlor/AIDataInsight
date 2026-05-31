import type { AccountUser } from '@/contracts/generated/models';
import { request } from '@/data/http/http-client';
import { normalizeOAuthSession } from './account-mappers';
import type { LoginInput, OAuthDto } from './account-types';

export async function loginAccount(input: LoginInput) {
  // 登录接口不携带旧 token，成功后由 store 持久化新会话。
  const dto = await request<OAuthDto>('/oauth2/login', {
    method: 'POST',
    body: input,
    skipAuth: true,
  });
  return normalizeOAuthSession(dto);
}

export async function refreshAccountSession(refreshToken: string) {
  // 刷新请求禁止再次触发刷新，避免 402 递归。
  const dto = await request<OAuthDto>('/oauth2/refresh', {
    method: 'GET',
    query: { refreshToken },
    skipAuth: true,
    skipRefresh: true,
  });
  return normalizeOAuthSession(dto);
}

export async function logoutAccount() {
  await request<null>('/oauth2/logout', {
    method: 'GET',
    skipRefresh: true,
  });
}

export async function getUserInfo() {
  return request<AccountUser>('/oauth2/getUserInfo', {
    method: 'GET',
  });
}
