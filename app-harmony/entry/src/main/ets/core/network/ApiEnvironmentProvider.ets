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
      return path
    }

    let baseUrl = this.environment.baseUrl.endsWith('/')
      ? this.environment.baseUrl.substring(0, this.environment.baseUrl.length - 1)
      : this.environment.baseUrl
    let relativePath = path.startsWith('/') ? path : `/${path}`
    return `${baseUrl}${relativePath}`
  }
}

export const localApiEnvironment: ApiEnvironment = {
  name: 'local',
  baseUrl: 'http://127.0.0.1:3000',
  description: 'Local FastAPI api-server used by AIDataInsight development clients.'
}

export const defaultApiEnvironmentProvider = new ApiEnvironmentProvider()
