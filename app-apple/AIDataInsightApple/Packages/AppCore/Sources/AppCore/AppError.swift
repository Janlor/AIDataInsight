import Foundation

/// 登录会话失效的来源，网络层和根视图通过它决定是否回到登录态。
public enum SessionInvalidationReason: Equatable, Sendable {
    case unauthorized
    case refreshFailed
    case logout
}

/// 会话失效通知的 userInfo 编解码工具，避免通知键名散落在各处。
public enum SessionInvalidationNotification {
    public static let reasonKey = "reason"

    public static func reason(from notification: Notification) -> SessionInvalidationReason? {
        notification.userInfo?[reasonKey] as? SessionInvalidationReason
    }
}

public extension Notification.Name {
    static let appSessionInvalidated = Notification.Name("AIDataInsightApple.sessionInvalidated")
}

/// 应用内统一错误类型，保留链路追踪信息，便于展示和问题排查。
public struct AppError: Error, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case unknown
        case dataFormat
        case server(code: Int, message: String)
        case transport(message: String)
        case sessionInvalid(SessionInvalidationReason)
    }

    public let kind: Kind
    public let traceID: String?
    public let transactionID: String?

    public init(kind: Kind, traceID: String? = nil, transactionID: String? = nil) {
        self.kind = kind
        self.traceID = traceID
        self.transactionID = transactionID
    }
}
