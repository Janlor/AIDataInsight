import { runtimeConfig } from '@/lib/env';
import { AppError } from '@/domain/errors';

export interface ResponseEnvelope<T> {
  msg?: string | null;
  code: number;
  data?: T | null;
  trace?: string | null;
  tid?: string | null;
}

// 统一 HTTP 层只支持业务接口当前需要的方法集合。
export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

export interface RequestOptions {
  method?: HttpMethod;
  query?: Record<string, string | number | boolean | null | undefined>;
  body?: unknown;
  skipAuth?: boolean;
  skipRefresh?: boolean;
  signal?: AbortSignal;
}

export interface HttpAuthBridge {
  getAccessToken(): string | null;
  refreshToken(): Promise<boolean>;
  clearSession(): void;
}

let authBridge: HttpAuthBridge | null = null;
// 多个请求同时收到 402 时共享同一个刷新任务，避免重复刷新 token。
let refreshTask: Promise<boolean> | null = null;

export function configureHttpAuthBridge(bridge: HttpAuthBridge) {
  // 由账号 store 注入 token 读取、刷新和清理能力，HTTP 层不直接依赖 Zustand。
  authBridge = bridge;
}

export async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  return requestInternal<T>(path, options, false);
}

export async function* streamText(path: string, options: RequestOptions = {}): AsyncGenerator<string> {
  // SSE 兜底接口返回的是文本流，不走统一 JSON 响应信封解析。
  const response = await fetch(buildRequestUrl(path, options.query), {
    method: options.method ?? 'GET',
    headers: buildHeaders(options),
    signal: options.signal,
  });

  if (!response.ok) {
    throw new AppError('unknown', `HTTP ${response.status}`);
  }

  if (!response.body) {
    return;
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';

  while (true) {
    const { value, done } = await reader.read();
    buffer += decoder.decode(value, { stream: !done });

    // buffer 可能只包含半个事件，解析函数会把未完成内容留到下一轮。
    const parsed = parseServerSentEventBuffer(buffer);
    buffer = parsed.remaining;
    for (const chunk of parsed.chunks) {
      yield chunk;
    }

    if (done) {
      break;
    }
  }

  const finalParsed = parseServerSentEventBuffer(`${buffer}\n\n`);
  for (const chunk of finalParsed.chunks) {
    yield chunk;
  }
}

async function requestInternal<T>(
  path: string,
  options: RequestOptions,
  hasRetriedAfterRefresh: boolean,
): Promise<T> {
  const response = await fetch(buildRequestUrl(path, options.query), {
    method: options.method ?? 'POST',
    headers: buildHeaders(options),
    body: options.body == null ? undefined : JSON.stringify(options.body),
    signal: options.signal,
  });

  if (!response.ok) {
    throw new AppError('unknown', `HTTP ${response.status}`);
  }

  const envelope = await parseEnvelope<T>(response);

  if (envelope.code === 200) {
    return envelope.data as T;
  }

  if (envelope.code === 402 && !options.skipRefresh && !hasRetriedAfterRefresh) {
    // 402 是后端约定的 access token 过期码；刷新成功后仅重试一次原请求。
    const refreshed = await refreshAccessToken();
    if (refreshed) {
      return requestInternal<T>(path, options, true);
    }
  }

  if (envelope.code === 401 || envelope.code === 402) {
    // 认证不可恢复或刷新失败时，清空本地会话，让页面回到登录流程。
    authBridge?.clearSession();
  }

  throw new AppError('server', envelope.msg ?? '服务端返回错误', {
    code: envelope.code,
    trace: envelope.trace,
    tid: envelope.tid,
  });
}

async function refreshAccessToken(): Promise<boolean> {
  if (!authBridge) {
    return false;
  }

  // refreshTask 使用空值合并，保证并发请求只触发一次 refreshToken。
  refreshTask ??= authBridge
    .refreshToken()
    .catch(() => false)
    .finally(() => {
      refreshTask = null;
    });

  return refreshTask;
}

export function buildRequestUrl(path: string, query?: RequestOptions['query']) {
  // 使用 URL 构造器拼接路径和查询参数，避免手写字符串遗漏编码。
  const baseUrl = runtimeConfig.apiBaseUrl.endsWith('/')
    ? runtimeConfig.apiBaseUrl
    : `${runtimeConfig.apiBaseUrl}/`;
  const normalizedPath = path.replace(/^\/+/, '');
  const url = new URL(normalizedPath, baseUrl);
  Object.entries(query ?? {}).forEach(([key, value]) => {
    if (value !== null && value !== undefined) {
      url.searchParams.set(key, String(value));
    }
  });
  return url;
}

export function parseServerSentEventBuffer(buffer: string): {
  chunks: string[];
  remaining: string;
} {
  // 一个 SSE 事件以空行结束，data 可跨多行，需要合并后作为单个 chunk。
  const normalized = buffer.replace(/\r\n/g, '\n');
  const events = normalized.split('\n\n');
  const remaining = events.pop() ?? '';
  const chunks = events.flatMap((event) => {
    const dataLines = event
      .split('\n')
      .filter((line) => line.startsWith('data:'))
      .map((line) => line.slice(5).trimStart());

    const data = dataLines.join('\n');
    if (!data || data === '[DONE]') {
      return [];
    }
    return [data];
  });

  return { chunks, remaining };
}

function buildHeaders(options: RequestOptions): HeadersInit {
  const headers: Record<string, string> = {
    Accept: 'application/json',
  };

  if (options.body != null) {
    headers['Content-Type'] = 'application/json';
  }

  const token = options.skipAuth ? null : authBridge?.getAccessToken();
  if (token) {
    // 后端和移动端统一使用 Bearer token 认证。
    headers.Authorization = `Bearer ${token}`;
  }

  return headers;
}

async function parseEnvelope<T>(response: Response): Promise<ResponseEnvelope<T>> {
  try {
    // 所有普通接口必须返回 { code, msg, data, trace, tid } 信封。
    const json = (await response.json()) as Partial<ResponseEnvelope<T>>;
    if (typeof json.code !== 'number') {
      throw new AppError('dataFormat', '响应缺少业务 code');
    }
    return {
      code: json.code,
      msg: json.msg ?? null,
      data: json.data ?? null,
      trace: json.trace ?? null,
      tid: json.tid ?? null,
    };
  } catch (error) {
    if (error instanceof AppError) {
      throw error;
    }
    throw new AppError('dataFormat', '响应格式不正确');
  }
}
