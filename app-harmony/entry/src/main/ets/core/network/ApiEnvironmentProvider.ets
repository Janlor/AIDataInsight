import { ApiEnvironment, aiChatEndpoint } from '../model/ContractModelExports'

export interface ApiEndpointSet {
  baseUrl: string
  streamPath: string
}

export class ApiEnvironmentProvider {
  private environment: ApiEnvironment

  constructor(environment: ApiEnvironment = localApiEnvironment) {
    this.environment = environment
  }

  current(): ApiEnvironment {
    return this.environment
  }

  endpoints(): ApiEndpointSet {
    return {
      baseUrl: this.environment.baseUrl,
      streamPath: aiChatEndpoint.streamPath
    }
  }

  resolve(path: string): string {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      // 已经是完整 URL 时直接使用，便于测试或特殊接口覆盖 baseUrl。
      return path
    }

    // 统一处理 baseUrl 和 path 的斜杠，避免出现双斜杠或漏斜杠。
    let baseUrl = this.environment.baseUrl.endsWith('/')
      ? this.environment.baseUrl.substring(0, this.environment.baseUrl.length - 1)
      : this.environment.baseUrl
    let relativePath = path.startsWith('/') ? path : `/${path}`
    return `${baseUrl}${relativePath}`
  }
}

export const localApiEnvironment: ApiEnvironment = {
  name: 'local',
  // Harmony 真机和模拟器可直接访问开发机局域网地址；本地默认先指向 127.0.0.1。
  baseUrl: 'http://127.0.0.1:3000',
  description: 'Local FastAPI api-server used by AIDataInsight development clients.'
}

export const defaultApiEnvironmentProvider = new ApiEnvironmentProvider()
