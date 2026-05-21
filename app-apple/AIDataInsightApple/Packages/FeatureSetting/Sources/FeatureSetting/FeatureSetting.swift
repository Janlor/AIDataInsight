import AppAccount
import AppContracts
import AppDesignSystem
import Observation
import SwiftUI

public enum SettingSectionKind: String, Equatable, Sendable {
    case account
    case about
    case logout
}

public enum SettingRowKind: String, Equatable, Sendable {
    case nickname
    case username
    case phone
    case privacy
    case appVersion
    case logout
}

public enum SettingRowAction: Equatable, Sendable {
    case none
    case openPrivacy
    case confirmLogout
}

public struct SettingRowState: Equatable, Sendable, Identifiable {
    public var id: SettingRowKind { kind }
    public let kind: SettingRowKind
    public let title: String
    public let detail: String?
    public let action: SettingRowAction
    public let selectable: Bool
    public let destructive: Bool
    public let centered: Bool
    public let showsDisclosure: Bool
}

public struct SettingSectionState: Equatable, Sendable, Identifiable {
    public var id: SettingSectionKind { kind }
    public let kind: SettingSectionKind
    public let title: String?
    public let rows: [SettingRowState]
}

public struct LogoutDialogState: Equatable, Sendable {
    public var visible: Bool
    public let title: String
    public let cancelTitle: String
    public let confirmTitle: String

    public init(
        visible: Bool = false,
        title: String = "确认注销并退出系统吗？",
        cancelTitle: String = "取消",
        confirmTitle: String = "确定"
    ) {
        self.visible = visible
        self.title = title
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
    }
}

public struct SettingViewState: Equatable, Sendable {
    public var title: String
    public var isLoading: Bool
    public var isLoggingOut: Bool
    public var errorMessage: String?
    public var sections: [SettingSectionState]
    public var logoutDialog: LogoutDialogState
    public var didLogout: Bool

    public init(
        title: String = "设置",
        isLoading: Bool = false,
        isLoggingOut: Bool = false,
        errorMessage: String? = nil,
        sections: [SettingSectionState] = SettingViewState.sections(from: SettingViewState.defaultSnapshot),
        logoutDialog: LogoutDialogState = LogoutDialogState(),
        didLogout: Bool = false
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isLoggingOut = isLoggingOut
        self.errorMessage = errorMessage
        self.sections = sections
        self.logoutDialog = logoutDialog
        self.didLogout = didLogout
    }

    public static let defaultSnapshot = SettingSnapshotContract(
        accountInfo: SettingAccountInfoContract(nickname: "未设置", username: "demo", phone: nil),
        capability: SettingCapabilityContract(canUpdatePassword: false, canOpenPrivacy: true, canLogout: true),
        appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    )

    public static func sections(from snapshot: SettingSnapshotContract) -> [SettingSectionState] {
        let unset = "未设置"
        var sections: [SettingSectionState] = [
            SettingSectionState(
                kind: .account,
                title: "账户",
                rows: [
                    SettingRowState(kind: .nickname, title: "昵称", detail: snapshot.accountInfo.nickname.nonEmpty ?? unset, action: .none, selectable: false, destructive: false, centered: false, showsDisclosure: false),
                    SettingRowState(kind: .username, title: "登录名", detail: snapshot.accountInfo.username.nonEmpty ?? unset, action: .none, selectable: false, destructive: false, centered: false, showsDisclosure: false),
                    SettingRowState(kind: .phone, title: "手机号", detail: snapshot.accountInfo.phone.nonEmpty ?? unset, action: .none, selectable: false, destructive: false, centered: false, showsDisclosure: false),
                ]
            ),
        ]

        var aboutRows: [SettingRowState] = []
        if snapshot.capability.canOpenPrivacy {
            aboutRows.append(SettingRowState(kind: .privacy, title: "隐私政策", detail: nil, action: .openPrivacy, selectable: true, destructive: false, centered: false, showsDisclosure: true))
        }
        aboutRows.append(SettingRowState(kind: .appVersion, title: "App版本", detail: snapshot.appVersion, action: .none, selectable: false, destructive: false, centered: false, showsDisclosure: false))
        sections.append(SettingSectionState(kind: .about, title: "关于", rows: aboutRows))

        if snapshot.capability.canLogout {
            sections.append(SettingSectionState(
                kind: .logout,
                title: nil,
                rows: [
                    SettingRowState(kind: .logout, title: "退出登录", detail: nil, action: .confirmLogout, selectable: true, destructive: true, centered: true, showsDisclosure: false),
                ]
            ))
        }

        return sections
    }
}

@MainActor
@Observable
public final class SettingStore {
    public private(set) var state: SettingViewState
    private let accountService: AccountServicing

    public init(
        state: SettingViewState = SettingViewState(),
        accountService: AccountServicing = PreviewAccountService()
    ) {
        self.state = state
        self.accountService = accountService
    }

    public func load() async {
        state.isLoading = true
        state.errorMessage = nil
        do {
            let session = try await accountService.resolveLaunchSession()
            let cachedUser = try? await accountService.cachedUserInfo()
            if let cachedUser {
                state.sections = SettingViewState.sections(from: snapshot(session: session, user: cachedUser))
            }
            let user = (try? await accountService.getUserInfo()) ?? cachedUser
            state.sections = SettingViewState.sections(from: snapshot(session: session, user: user))
        } catch {
            state.errorMessage = "设置加载失败，请稍后重试"
        }
        state.isLoading = false
    }

    private func snapshot(session: AccountSession?, user: AccountUserContract?) -> SettingSnapshotContract {
        SettingSnapshotContract(
            accountInfo: SettingAccountInfoContract(
                nickname: user?.nickname,
                username: user?.username ?? session?.username,
                phone: user?.phone
            ),
            capability: SettingCapabilityContract(canUpdatePassword: false, canOpenPrivacy: true, canLogout: true),
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        )
    }

    public func confirmLogout() {
        state.logoutDialog.visible = true
    }

    public func cancelLogout() {
        state.logoutDialog.visible = false
    }

    public func logout() async {
        state.isLoggingOut = true
        state.errorMessage = nil
        do {
            try await accountService.logout()
            state.logoutDialog.visible = false
            state.didLogout = true
        } catch {
            state.errorMessage = "退出登录失败，请稍后重试"
        }
        state.isLoggingOut = false
    }

    public func consumeLogoutSignal() {
        state.didLogout = false
    }
}

public struct SettingScreen: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Bindable private var store: SettingStore
    private let onOpenPrivacy: () -> Void
    private let showsLogoutAction: Bool

    public init(store: SettingStore, onOpenPrivacy: @escaping () -> Void = {}, showsLogoutAction: Bool = true) {
        self.store = store
        self.onOpenPrivacy = onOpenPrivacy
        self.showsLogoutAction = showsLogoutAction
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    accountHeader

                    if let errorMessage = store.state.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColor.Status.mark.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                    }

                    ForEach(contentSections) { section in
                        sectionCard(section)
                    }
                }
                .padding(contentPadding)
                .padding(.bottom, logoutRow == nil ? 0 : 88)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }

            if let logoutRow {
                VStack(spacing: 0) {
                    Divider()
                    rowView(logoutRow)
                        .padding(16)
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity)
                }
                .background(.bar)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("setting-logout-area")
            }
        }
        .background(AppColor.Background.secondary.color)
        .navigationTitle(store.state.title)
        .accessibilityIdentifier("setting-screen")
#if os(macOS)
        .toolbarTitleDisplayMode(.inline)
#endif
        .task {
            await store.load()
        }
        .confirmationDialog(
            store.state.logoutDialog.title,
            isPresented: Binding(
                get: { store.state.logoutDialog.visible },
                set: { visible in
                    if visible == false {
                        store.cancelLogout()
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(store.state.logoutDialog.confirmTitle, role: .destructive) {
                Task {
                    await store.logout()
                }
            }
            Button(store.state.logoutDialog.cancelTitle, role: .cancel) {
                store.cancelLogout()
            }
        }
    }

    private var contentSections: [SettingSectionState] {
        store.state.sections.filter { $0.kind != .logout }
    }

    private var logoutRow: SettingRowState? {
        guard showsLogoutAction else {
            return nil
        }
        return store.state.sections
            .first(where: { $0.kind == .logout })?
            .rows
            .first
    }

    private var contentPadding: CGFloat {
        horizontalSizeClass == .compact ? 16 : 24
    }

    private var accountHeader: some View {
        HStack(spacing: 14) {
            AccountInitialsAvatar(account: accountDisplay, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(accountDisplay.displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColor.Label.primary.color)
                    .lineLimit(1)
                if let secondaryText = accountDisplay.secondaryText {
                    Text(secondaryText)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.Label.secondary.color)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(18)
        .background(AppColor.Background.tertiary.color, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColor.Separator.default.color)
        }
    }

    private var accountDisplay: AccountDisplayState {
        let rows = store.state.sections.flatMap(\.rows)
        let nickname = rows.first(where: { $0.kind == .nickname })?.detail.nonEmptyAccountField
        let username = rows.first(where: { $0.kind == .username })?.detail.nonEmptyAccountField
        let phone = rows.first(where: { $0.kind == .phone })?.detail.nonEmptyAccountField
        return AccountDisplayState(
            displayName: nickname ?? username ?? phone ?? "用户",
            secondaryText: username ?? phone
        )
    }

    private func sectionCard(_ section: SettingSectionState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = section.title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.Label.secondary.color)
                    .textCase(.uppercase)
            }

            VStack(spacing: 0) {
                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                    rowView(row)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    if index < section.rows.count - 1 {
                        Divider()
                            .padding(.leading, 14)
                    }
                }
            }
            .background(AppColor.Background.tertiary.color, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColor.Separator.default.color)
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: SettingRowState) -> some View {
        if row.selectable {
            Button {
                switch row.action {
                case .openPrivacy:
                    onOpenPrivacy()
                case .confirmLogout:
                    store.confirmLogout()
                case .none:
                    break
                }
            } label: {
                rowContent(row)
            }
            .disabled(store.state.isLoggingOut)
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(row.title)
            .accessibilityIdentifier("setting-row-\(row.kind.rawValue)")
        } else {
            rowContent(row)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(row.title)
                .accessibilityIdentifier("setting-row-\(row.kind.rawValue)")
        }
    }

    private func rowContent(_ row: SettingRowState) -> some View {
        HStack {
            if row.centered {
                Spacer()
            }
            Text(row.kind == .logout && store.state.isLoggingOut ? "退出中..." : row.title)
                .foregroundStyle(row.destructive ? .red : .primary)
                .font(.body.weight(row.kind == .logout ? .semibold : .regular))
            if row.centered {
                Spacer()
            } else {
                Spacer()
                if let detail = row.detail {
                    Text(detail)
                        .foregroundStyle(AppColor.Label.secondary.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                if row.showsDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

private extension String? {
    var nonEmpty: String? {
        guard let value = self, value.isEmpty == false else {
            return nil
        }
        return value
    }

    var nonEmptyAccountField: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isEmpty == false,
              value != "未设置"
        else {
            return nil
        }
        return value
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

public struct PreviewAccountService: AccountServicing {
    public init() {}

    public func resolveLaunchSession() async throws -> AccountSession? {
        AccountSession(accessToken: "preview-access", refreshToken: "preview-refresh", orgID: "0", username: "demo")
    }

    public func login(name: String, password: String) async throws -> AccountSession {
        AccountSession(accessToken: "preview-access", refreshToken: "preview-refresh", orgID: "0", username: name)
    }

    public func cachedUserInfo() async throws -> AccountUserContract? {
        AccountUserContract(id: 1, username: "demo", nickname: "演示账号", phone: "18812341234")
    }

    public func getUserInfo() async throws -> AccountUserContract {
        AccountUserContract(id: 1, username: "demo", nickname: "演示账号", phone: "18812341234")
    }

    public func logout() async throws {}
}
