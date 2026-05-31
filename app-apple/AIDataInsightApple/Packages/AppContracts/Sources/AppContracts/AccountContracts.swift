/// 登录和刷新 token 接口返回的会话契约。
public struct AccountSessionContract: Codable, Equatable, Sendable {
    public let accessToken: String?
    public let refreshToken: String?
    public let orgId: Int?
    public let username: String?
    public let isLogin: Bool

    public init(accessToken: String?, refreshToken: String?, orgId: Int?, username: String?, isLogin: Bool) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.orgId = orgId
        self.username = username
        self.isLogin = isLogin
    }

    private enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case orgId
        case username
        case isLogin
        case accessTokenSnake = "access_token"
        case refreshTokenSnake = "refresh_token"
        case orgIdSnake = "org_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
            ?? container.decodeIfPresent(String.self, forKey: .accessTokenSnake)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
            ?? container.decodeIfPresent(String.self, forKey: .refreshTokenSnake)
        orgId = try container.decodeIfPresent(Int.self, forKey: .orgId)
            ?? container.decodeIfPresent(Int.self, forKey: .orgIdSnake)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        isLogin = try container.decodeIfPresent(Bool.self, forKey: .isLogin)
            ?? ((accessToken?.isEmpty == false) || (refreshToken?.isEmpty == false))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(accessToken, forKey: .accessToken)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
        try container.encodeIfPresent(orgId, forKey: .orgId)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encode(isLogin, forKey: .isLogin)
    }
}

/// 登录请求体。
public struct LoginRequestContract: Codable, Equatable, Sendable {
    public let name: String
    public let pwd: String

    public init(name: String, pwd: String) {
        self.name = name
        self.pwd = pwd
    }
}

/// 无业务数据接口使用的空 payload。
public struct EmptyContract: Codable, Equatable, Sendable {
    public init() {}
}

/// 当前登录用户资料。
public struct AccountUserContract: Codable, Equatable, Sendable {
    public let id: Int?
    public let username: String?
    public let nickname: String?
    public let phone: String?

    public init(id: Int?, username: String?, nickname: String?, phone: String?) {
        self.id = id
        self.username = username
        self.nickname = nickname
        self.phone = phone
    }
}
