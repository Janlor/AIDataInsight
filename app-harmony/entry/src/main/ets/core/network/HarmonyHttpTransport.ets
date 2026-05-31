import { http } from '@kit.NetworkKit'
import { ApiError, ApiErrorKind } from './ApiError'
import { HttpMethod, HttpTransport, ResolvedApiRequest } from './CommonRequester'

export class HarmonyHttpTransport implements HttpTransport {
  async send(request: ResolvedApiRequest): Promise<string> {
    let httpRequest = http.createHttp()
    try {
      // Harmony 原生 http 接口返回的 result 可能是字符串、对象或 ArrayBuffer，后面统一转文本。
      let response = await (httpRequest.request(request.url, {
        method: this.requestMethod(request.method),
        header: this.headers(request),
        extraData: this.extraData(request),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 60000
      }) as Promise<http.HttpResponse>)
      let statusCode = response.responseCode as number
      if (statusCode < 200 || statusCode >= 300) {
        throw new ApiError(ApiErrorKind.Transport, `HTTP ${statusCode}: ${request.url}`)
      }
      return this.responseText(response.result)
    } catch (error) {
      if (error instanceof ApiError) {
        throw error
      }
      throw new ApiError(ApiErrorKind.Transport, `网络请求失败: ${JSON.stringify(error)}`)
    } finally {
      // 每次请求结束都销毁 http 实例，避免底层资源泄露。
      httpRequest.destroy()
    }
  }

  private requestMethod(method: HttpMethod): http.RequestMethod {
    if (method === HttpMethod.Post) {
      return http.RequestMethod.POST
    }
    return http.RequestMethod.GET
  }

  private headers(request: ResolvedApiRequest): Object {
    let headers: Record<string, string> = {
      'content-type': 'application/json'
    }
    if (request.headers !== undefined) {
      // 业务请求可覆盖或追加认证、SSE 等特殊 header。
      request.headers.forEach((value: string, key: string) => {
        headers[key] = value
      })
    }
    return headers
  }

  private extraData(request: ResolvedApiRequest): string | Object | null {
    if (request.body === undefined || request.body === null) {
      return null
    }
    if (typeof request.body === 'string') {
      return request.body
    }
    // ArkTS http extraData 支持对象或字符串，这里统一序列化以匹配后端 JSON 接口。
    return JSON.stringify(request.body)
  }

  private responseText(result: string | Object | ArrayBuffer): string {
    if (typeof result === 'string') {
      return result
    }
    if (result instanceof ArrayBuffer) {
      return this.arrayBufferToString(result)
    }
    return JSON.stringify(result)
  }

  private arrayBufferToString(buffer: ArrayBuffer): string {
    // 当前接口返回 UTF-8 文本；这里做轻量转换，避免引入额外解码依赖。
    let bytes = new Uint8Array(buffer)
    let text = ''
    for (let index = 0; index < bytes.length; index++) {
      text += String.fromCharCode(bytes[index])
    }
    return text
  }
}
