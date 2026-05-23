import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  buildRequestUrl,
  configureHttpAuthBridge,
  parseServerSentEventBuffer,
  request,
} from './http-client';

describe('http-client', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('refreshes token and retries original request once when business code is 402', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(jsonResponse({ code: 402, msg: 'access token expired', data: null }))
      .mockResolvedValueOnce(jsonResponse({ code: 200, msg: 'ok', data: { value: 1 } }));

    vi.stubGlobal('fetch', fetchMock);

    const refreshToken = vi.fn().mockResolvedValue(true);
    configureHttpAuthBridge({
      getAccessToken: () => 'access-token',
      refreshToken,
      clearSession: vi.fn(),
    });

    await expect(request<{ value: number }>('/demo', { method: 'GET' })).resolves.toEqual({ value: 1 });
    expect(refreshToken).toHaveBeenCalledTimes(1);
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('clears session when business code is 401', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(jsonResponse({ code: 401, msg: '登录已失效', data: null })),
    );

    const clearSession = vi.fn();
    configureHttpAuthBridge({
      getAccessToken: () => 'access-token',
      refreshToken: vi.fn(),
      clearSession,
    });

    await expect(request('/demo', { method: 'GET' })).rejects.toMatchObject({
      kind: 'server',
      code: 401,
    });
    expect(clearSession).toHaveBeenCalledTimes(1);
  });

  it('builds local API URLs by default', () => {
    const url = buildRequestUrl('/oauth2/login', { page: 1 });

    expect(url.toString()).toBe('http://127.0.0.1:3000/oauth2/login?page=1');
  });

  it('keeps an explicitly injected base path when building absolute API URLs', () => {
    vi.stubEnv(
      'NEXT_PUBLIC_API_BASE_URL',
      'https://m1.apifoxmock.com/m1/3174267-1700689-default',
    );
    const url = buildRequestUrl('/oauth2/login', { page: 1 });

    expect(url.toString()).toBe(
      'https://m1.apifoxmock.com/m1/3174267-1700689-default/oauth2/login?page=1',
    );
  });

  it('parses server-sent event data frames and keeps incomplete buffers', () => {
    const parsed = parseServerSentEventBuffer('data: 你好\n\ndata: 世界\n\ndata: partial');

    expect(parsed.chunks).toEqual(['你好', '世界']);
    expect(parsed.remaining).toBe('data: partial');
  });
});

function jsonResponse(body: unknown) {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}
