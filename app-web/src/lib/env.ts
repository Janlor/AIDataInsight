import { mockApiEnvironment } from '@/contracts/generated/models';

export type AppEnv = 'local' | 'mock' | 'dev' | 'test' | 'sit' | 'uat' | 'staging' | 'pre' | 'prod';

export interface WebRuntimeConfig {
  appEnv: AppEnv;
  apiBaseUrl: string;
}

const appEnvs = ['local', 'mock', 'dev', 'test', 'sit', 'uat', 'staging', 'pre', 'prod'] as const;

const defaultApiBaseUrlByEnv: Partial<Record<AppEnv, string>> = {
  local: 'http://127.0.0.1:3000',
  mock: mockApiEnvironment.baseUrl,
};

function readAppEnv(): AppEnv {
  // Next.js 客户端优先读取 NEXT_PUBLIC_APP_ENV，服务端脚本可使用 APP_ENV。
  const value = process.env.NEXT_PUBLIC_APP_ENV ?? process.env.APP_ENV ?? 'local';
  if (isAppEnv(value)) {
    return value;
  }
  return 'mock';
}

function isAppEnv(value: string): value is AppEnv {
  return appEnvs.includes(value as AppEnv);
}

export function resolveApiBaseUrl(appEnv: AppEnv, explicitBaseUrl?: string): string {
  const normalizedExplicitBaseUrl = explicitBaseUrl?.trim();
  if (normalizedExplicitBaseUrl) {
    // 显式配置优先级最高，便于部署环境直接指定网关地址。
    return normalizedExplicitBaseUrl;
  }

  const defaultBaseUrl = defaultApiBaseUrlByEnv[appEnv];
  if (defaultBaseUrl) {
    // local/mock 提供默认地址，其它环境必须显式配置，避免误连。
    return defaultBaseUrl;
  }

  throw new Error(`NEXT_PUBLIC_API_BASE_URL is required for ${appEnv.toUpperCase()} environment.`);
}

export const runtimeConfig: WebRuntimeConfig = {
  appEnv: readAppEnv(),
  get apiBaseUrl() {
    // 用 getter 保持测试中修改环境变量后可重新解析。
    return resolveApiBaseUrl(this.appEnv, process.env.NEXT_PUBLIC_API_BASE_URL);
  },
};
