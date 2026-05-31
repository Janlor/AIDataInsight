export enum ApiErrorKind {
  Unauthorized = 'unauthorized',
  TokenExpired = 'tokenExpired',
  Server = 'server',
  Decode = 'decode',
  Transport = 'transport'
}

export class ApiError extends Error {
  kind: ApiErrorKind
  code?: number

  constructor(kind: ApiErrorKind, message: string, code?: number) {
    super(message)
    this.kind = kind
    this.code = code
  }
}

export function apiErrorFromCode(code: number, message?: string | null): ApiError | null {
  // 后端业务 code 与客户端错误类型的集中映射。
  if (code === 200) {
    return null
  }
  if (code === 401) {
    return new ApiError(ApiErrorKind.Unauthorized, message ?? '登录已失效', code)
  }
  if (code === 402) {
    return new ApiError(ApiErrorKind.TokenExpired, message ?? 'Token 已过期', code)
  }
  return new ApiError(ApiErrorKind.Server, message ?? '服务器错误', code)
}
