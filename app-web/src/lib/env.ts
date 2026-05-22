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
    return normalizedExplicitBaseUrl;
  }

  const defaultBaseUrl = defaultApiBaseUrlByEnv[appEnv];
  if (defaultBaseUrl) {
    return defaultBaseUrl;
  }

  throw new Error(`NEXT_PUBLIC_API_BASE_URL is required for ${appEnv.toUpperCase()} environment.`);
}

export const runtimeConfig: WebRuntimeConfig = {
  appEnv: readAppEnv(),
  get apiBaseUrl() {
    return resolveApiBaseUrl(this.appEnv, process.env.NEXT_PUBLIC_API_BASE_URL);
  },
};
