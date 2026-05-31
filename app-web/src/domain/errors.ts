export type AppErrorKind = 'unknown' | 'dataFormat' | 'server';

export class AppError extends Error {
  readonly kind: AppErrorKind;
  readonly code?: number;
  readonly trace?: string | null;
  readonly tid?: string | null;

  constructor(
    kind: AppErrorKind,
    message: string,
    detail?: {
      code?: number;
      trace?: string | null;
      tid?: string | null;
    },
  ) {
    super(message);
    // 保留后端业务码和链路 id，UI 展示消息的同时也方便排查接口问题。
    this.name = 'AppError';
    this.kind = kind;
    this.code = detail?.code;
    this.trace = detail?.trace;
    this.tid = detail?.tid;
  }
}

export function toAppError(error: unknown): AppError {
  // 把未知异常统一转换成 AppError，调用方只需要处理一种错误形态。
  if (error instanceof AppError) {
    return error;
  }
  if (error instanceof Error) {
    return new AppError('unknown', error.message);
  }
  return new AppError('unknown', '未知错误');
}
