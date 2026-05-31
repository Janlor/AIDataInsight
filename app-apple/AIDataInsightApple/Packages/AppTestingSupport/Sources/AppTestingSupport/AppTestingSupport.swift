import Foundation

/// 测试夹具加载错误。
public enum FixtureLoaderError: Error, Equatable, Sendable {
    case missingFixture(String)
}

/// 从指定根目录读取测试夹具，并提供 JSON 解码便捷方法。
public struct FixtureLoader: Sendable {
    public let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public func data(at relativePath: String) throws -> Data {
        let url = rootURL.appending(path: relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FixtureLoaderError.missingFixture(relativePath)
        }
        return try Data(contentsOf: url)
    }

    public func decode<Value: Decodable>(_ type: Value.Type, at relativePath: String, decoder: JSONDecoder = JSONDecoder()) throws -> Value {
        try decoder.decode(type, from: data(at: relativePath))
    }
}

/// 共享测试夹具路径，集中维护以避免各测试里散落字符串。
public enum ContractFixturePath {
    public static let loginSnakeCaseResponse = "api/login-response-snake-case.json"
    public static let response401 = "api/response-401.json"
    public static let response402 = "api/response-402.json"
    public static let aiChatInitial = "ui/ai-chat-initial.json"
    public static let historyInitial = "ui/history-initial.json"
}
