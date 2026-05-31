import SwiftUI

/// 账号展示信息，负责清理空白值并生成头像首字母。
public struct AccountDisplayState: Equatable, Sendable {
    public let displayName: String
    public let secondaryText: String?

    public init(displayName: String, secondaryText: String? = nil) {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecondary = secondaryText?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = trimmedName.isEmpty ? "用户" : trimmedName
        self.secondaryText = trimmedSecondary?.isEmpty == false && trimmedSecondary != self.displayName ? trimmedSecondary : nil
    }

    public static let placeholder = AccountDisplayState(displayName: "用户")

    public var initials: String {
        // 英文/拼音名称取前两个词首字母，中文或紧凑名称取前两个字符。
        let words = displayName
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" || $0 == "." })
            .map(String.init)

        if words.count >= 2 {
            return words
                .prefix(2)
                .compactMap(\.first)
                .map { String($0).uppercased() }
                .joined()
        }

        let compactName = displayName.filter { $0.isWhitespace == false }
        let prefix = compactName.prefix(2)
        return prefix.isEmpty ? "?" : prefix.uppercased()
    }
}

/// 使用账号首字母绘制的轻量头像组件。
public struct AccountInitialsAvatar: View {
    private let account: AccountDisplayState
    private let size: CGFloat

    public init(account: AccountDisplayState, size: CGFloat = 30) {
        self.account = account
        self.size = size
    }

    public var body: some View {
        Text(account.initials)
            .font(.system(size: max(size * 0.38, 11), weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: size, height: size)
            .background(AppColor.Accent.primary.color, in: Circle())
            .accessibilityHidden(true)
    }
}
