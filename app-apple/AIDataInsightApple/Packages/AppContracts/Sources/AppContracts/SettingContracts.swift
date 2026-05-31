/// 设置页展示的账号资料。
public struct SettingAccountInfoContract: Codable, Equatable, Sendable {
    public let nickname: String?
    public let username: String?
    public let phone: String?

    public init(nickname: String?, username: String?, phone: String?) {
        self.nickname = nickname
        self.username = username
        self.phone = phone
    }
}

/// 设置页能力开关，决定哪些入口或操作可展示。
public struct SettingCapabilityContract: Codable, Equatable, Sendable {
    public let canUpdatePassword: Bool
    public let canOpenPrivacy: Bool
    public let canLogout: Bool

    public init(canUpdatePassword: Bool, canOpenPrivacy: Bool, canLogout: Bool) {
        self.canUpdatePassword = canUpdatePassword
        self.canOpenPrivacy = canOpenPrivacy
        self.canLogout = canLogout
    }
}

/// 设置页快照，聚合账号资料、能力开关和版本号。
public struct SettingSnapshotContract: Codable, Equatable, Sendable {
    public let accountInfo: SettingAccountInfoContract
    public let capability: SettingCapabilityContract
    public let appVersion: String

    public init(accountInfo: SettingAccountInfoContract, capability: SettingCapabilityContract, appVersion: String) {
        self.accountInfo = accountInfo
        self.capability = capability
        self.appVersion = appVersion
    }
}

/// 隐私政策的一个段落。
public struct PrivacyPolicySectionContract: Codable, Equatable, Sendable {
    public let heading: String
    public let paragraphs: [String]

    public init(heading: String, paragraphs: [String]) {
        self.heading = heading
        self.paragraphs = paragraphs
    }
}

/// 隐私政策完整内容。
public struct PrivacyPolicyContract: Codable, Equatable, Sendable {
    public let title: String
    public let updatedAt: String
    public let sections: [PrivacyPolicySectionContract]

    public init(title: String, updatedAt: String, sections: [PrivacyPolicySectionContract]) {
        self.title = title
        self.updatedAt = updatedAt
        self.sections = sections
    }

    public static let current = PrivacyPolicyContract(
        title: "隐私政策",
        updatedAt: "2026-05-18",
        sections: [
            PrivacyPolicySectionContract(
                heading: "我们如何使用数据",
                paragraphs: [
                    "AIDataInsight Web 端仅在登录、会话恢复、经营分析问答、历史记录和设置展示所需范围内处理账号信息与业务数据。",
                    "账号信息用于识别当前用户、维持登录态和展示设置页账户信息；经营分析问题和返回结果用于完成用户主动发起的数据分析请求。",
                ]
            ),
            PrivacyPolicySectionContract(
                heading: "跨端一致性",
                paragraphs: [
                    "隐私政策入口、登录勾选规则、设置页隐私入口和退出登录行为应与 iOS、Android、HarmonyOS NEXT 保持一致。",
                    "各端实现可以采用页面、弹层或系统导航承载隐私政策，但展示文案和用户可访问性必须以跨平台契约为准。",
                ]
            ),
            PrivacyPolicySectionContract(
                heading: "本地与 Mock 环境",
                paragraphs: [
                    "开发环境支持本地 mock 与 Apifox mock。Mock 数据仅用于开发调试，不代表正式生产数据处理规则。",
                    "切换环境时应通过环境变量配置 API Base URL，不应在页面逻辑中硬编码隐私相关行为。",
                ]
            ),
            PrivacyPolicySectionContract(
                heading: "用户控制",
                paragraphs: [
                    "用户可以在设置中查看隐私政策并退出登录。退出登录后，本端会清理受保护的会话状态并返回登录入口。",
                    "未登录用户也可以从登录页访问隐私政策。",
                ]
            ),
        ]
    )
}
