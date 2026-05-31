export interface ApiEnvelope<T> {
  code: number
  msg?: string | null
  data?: T | null
  trace?: string | null
  tid?: string | null
}

export function requireEnvelopeData<T>(envelope: ApiEnvelope<T>): T {
  // 业务接口声明有 data 时，空值视为契约异常。
  if (envelope.data === null || envelope.data === undefined) {
    throw new Error('ApiEnvelope data is empty')
  }
  return envelope.data
}
