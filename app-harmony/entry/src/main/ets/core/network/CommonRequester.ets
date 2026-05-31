import { apiErrorFromCode, ApiError, ApiErrorKind } from './ApiError'
import { ApiEnvelope, requireEnvelopeData } from './ApiEnvelope'
import { ApiEnvironmentProvider, defaultApiEnvironmentProvider } from './ApiEnvironmentProvider'

export enum HttpMethod {
  Get = 'GET',
  Post = 'POST'
}

// 业务层传入的轻量请求描述，最终由环境配置解析成完整 URL。
export interface ApiRequest {
  path: string
  method: HttpMethod
  headers?: Map<string, string>
  body?: Object | string | null
}

export interface HttpTransport {
  // 传输层只返回原始字符串，统一响应信封在 CommonRequester 中解析。
  send(request: ResolvedApiRequest): Promise<string>
}

export interface ResolvedApiRequest extends ApiRequest {
  url: string
}

export class CommonRequester {
  private environmentProvider: ApiEnvironmentProvider
  private transport: HttpTransport

  constructor(
    transport: HttpTransport,
    environmentProvider: ApiEnvironmentProvider = defaultApiEnvironmentProvider
  ) {
    this.transport = transport
    this.environmentProvider = environmentProvider
  }

  async request<T>(request: ApiRequest): Promise<T> {
    let responseText = await this.requestRaw(request)

    // 普通业务接口都需要返回统一响应信封。
    let envelope = this.decodeEnvelope<T>(responseText)
    this.throwIfEnvelopeError(envelope)

    return requireEnvelopeData(envelope)
  }

  async requestEmpty(request: ApiRequest): Promise<void> {
    let responseText = await this.requestRaw(request)
    let envelope = this.decodeEnvelope<null>(responseText)
    this.throwIfEnvelopeError(envelope)
  }

  async requestRaw(request: ApiRequest): Promise<string> {
    // raw 请求用于 SSE 等非标准 JSON 信封场景。
    let resolvedRequest: ResolvedApiRequest = {
      path: request.path,
      method: request.method,
      headers: request.headers,
      body: request.body,
      url: this.environmentProvider.resolve(request.path)
    }
    return this.transport.send(resolvedRequest)
  }

  private decodeEnvelope<T>(responseText: string): ApiEnvelope<T> {
    try {
      return JSON.parse(responseText) as ApiEnvelope<T>
    } catch (error) {
      throw new ApiError(ApiErrorKind.Decode, `接口响应解析失败: ${JSON.stringify(error)}`)
    }
  }

  private throwIfEnvelopeError<T>(envelope: ApiEnvelope<T>): void {
    // code 到 ApiError 的映射集中在网络层，业务层只处理异常。
    let error = apiErrorFromCode(envelope.code, envelope.msg)
    if (error !== null) {
      throw error
    }
  }
}
