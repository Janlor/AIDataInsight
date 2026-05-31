import Foundation

/// App 可切换的后端环境枚举，和服务端部署阶段保持一一对应。
public enum AppEnvironment: String, CaseIterable, Identifiable, Sendable {
    case mock
    case local
    case dev
    case test
    case pre
    case prod

    public var id: String { rawValue }
}

/// 一个可请求的 API 环境，包含环境名、基础 URL 和面向开发者的说明。
public struct APIEnvironment: Equatable, Sendable {
    public let name: AppEnvironment
    public let baseURL: URL
    public let description: String?

    public init(name: AppEnvironment, baseURL: URL, description: String? = nil) {
        self.name = name
        self.baseURL = baseURL
        self.description = description
    }

    public static let mock = APIEnvironment(
        name: .mock,
        baseURL: URL(string: "https://m1.apifoxmock.com/m1/3174267-1700689-default")!,
        description: "Apifox mock host shared by AIDataInsight development clients."
    )

    public static let local = APIEnvironment(
        name: .local,
        baseURL: URL(string: "http://127.0.0.1:3000")!,
        description: "Local development server."
    )

    public static let dev = APIEnvironment(
        name: .dev,
        baseURL: URL(string: "https://dev-api.aidatainsight.local")!,
        description: "Development API host placeholder."
    )

    public static let test = APIEnvironment(
        name: .test,
        baseURL: URL(string: "https://test-api.aidatainsight.local")!,
        description: "Testing API host placeholder."
    )

    public static let pre = APIEnvironment(
        name: .pre,
        baseURL: URL(string: "https://pre-api.aidatainsight.local")!,
        description: "Pre-production API host placeholder."
    )

    public static let prod = APIEnvironment(
        name: .prod,
        baseURL: URL(string: "https://api.aidatainsight.local")!,
        description: "Production API host placeholder."
    )

    public static func resolve(_ environment: AppEnvironment) -> APIEnvironment {
        switch environment {
        case .mock:
            .mock
        case .local:
            .local
        case .dev:
            .dev
        case .test:
            .test
        case .pre:
            .pre
        case .prod:
            .prod
        }
    }
}

/// 当前客户端运行平台，用于跨端能力分支或上报。
public enum PlatformKind: String, Sendable {
    case iPhone
    case iPad
    case mac
    case vision
}
