import AppAccount
import AppContracts
import AppCore
import AppDesignSystem
import Observation
import SwiftUI

public struct LoginViewState: Equatable, Sendable {
    public var account: String
    public var password: String
    public var acceptedPrivacy: Bool
    public var isLoading: Bool
    public var hasResolvedLaunchSession: Bool
    public var errorMessage: String?
    public var isAuthenticated: Bool

    public init(
        account: String = "demo",
        password: String = "demo@123",
        acceptedPrivacy: Bool = true,
        isLoading: Bool = false,
        hasResolvedLaunchSession: Bool = false,
        errorMessage: String? = nil,
        isAuthenticated: Bool = false
    ) {
        self.account = account
        self.password = password
        self.acceptedPrivacy = acceptedPrivacy
        self.isLoading = isLoading
        self.hasResolvedLaunchSession = hasResolvedLaunchSession
        self.errorMessage = errorMessage
        self.isAuthenticated = isAuthenticated
    }
}

@MainActor
@Observable
public final class LoginStore {
    public private(set) var state: LoginViewState
    private let accountService: AccountServicing

    public init(
        state: LoginViewState = LoginViewState(),
        accountService: AccountServicing = PreviewAccountService()
    ) {
        self.state = state
        self.accountService = accountService
    }

    public func updateAccount(_ account: String) {
        state.account = String(account.prefix(30))
        state.errorMessage = nil
    }

    public func updatePassword(_ password: String) {
        state.password = String(password.prefix(30))
        state.errorMessage = nil
    }

    public func setPrivacyAccepted(_ accepted: Bool) {
        state.acceptedPrivacy = accepted
        state.errorMessage = nil
    }

    public func resolveLaunchSession() async {
        guard state.hasResolvedLaunchSession == false else {
            return
        }
        defer { state.hasResolvedLaunchSession = true }
        do {
            state.isAuthenticated = try await accountService.resolveLaunchSession()?.isLogin == true
        } catch {
            state.isAuthenticated = false
        }
    }

    public func login() async {
        guard state.acceptedPrivacy else {
            state.errorMessage = "请先阅读并同意隐私政策"
            return
        }
        guard state.account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              state.password.isEmpty == false
        else {
            state.errorMessage = "请输入账号和密码"
            return
        }

        state.isLoading = true
        state.errorMessage = nil
        do {
            _ = try await accountService.login(name: state.account, password: state.password)
            state.hasResolvedLaunchSession = true
            state.isAuthenticated = true
        } catch let error as AppError {
            state.errorMessage = error.messageForDisplay
        } catch {
            state.errorMessage = "登录失败，请稍后重试"
        }
        state.isLoading = false
    }

    public func logout() async {
        state.isLoading = true
        do {
            try await accountService.logout()
            state.hasResolvedLaunchSession = true
            state.isAuthenticated = false
        } catch {
            state.errorMessage = "退出登录失败，请稍后重试"
        }
        state.isLoading = false
    }

    public func markLoggedOut() {
        state.hasResolvedLaunchSession = true
        state.isAuthenticated = false
    }
}

public struct LoginScreen: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Bindable private var store: LoginStore
    private let privacyDestination: AnyView?

    public init(store: LoginStore, privacyDestination: AnyView? = nil) {
        self.store = store
        self.privacyDestination = privacyDestination
    }

    public var body: some View {
        GeometryReader { proxy in
            let isRegularLandscape = proxy.size.width >= 600 && proxy.size.width > proxy.size.height

            ScrollView {
                Group {
                    if isRegularLandscape {
                        HStack(alignment: .center, spacing: 56) {
                            brandHeader
                                .frame(maxWidth: 330)
                            VStack(spacing: 28) {
                                form
                                privacyAgreement
                            }
                            .frame(maxWidth: 390)
                        }
                        .frame(maxWidth: 820)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 0) {
                            brandHeader
                                .padding(.top, 60)
                            Spacer(minLength: 78)
                            form
                            Spacer(minLength: 24)
                            privacyAgreement
                                .padding(.bottom, 12)
                        }
                        .frame(maxWidth: 430)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, isRegularLandscape ? 40 : 38)
                .frame(minHeight: proxy.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(loginBackground.ignoresSafeArea())
        }
    }

    private var form: some View {
        VStack(spacing: 0) {
            underlinedField(
                placeholder: "请输入账号",
                text: Binding(
                    get: { store.state.account },
                    set: { store.updateAccount($0) }
                ),
                isSecure: false,
                accessibilityID: "login-account-field"
            )

            Spacer()
                .frame(height: 20)

            underlinedField(
                placeholder: "请输入密码",
                text: Binding(
                    get: { store.state.password },
                    set: { store.updatePassword($0) }
                ),
                isSecure: true,
                accessibilityID: "login-password-field"
            )

            Spacer()
                .frame(height: 30)

            loginButton

            if let errorMessage = store.state.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private func underlinedField(
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool,
        accessibilityID: String
    ) -> some View {
        VStack(spacing: 0) {
            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                        .textContentType(.password)
                } else {
                    TextField(placeholder, text: text)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                }
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(AppColor.Label.primary.color)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .disabled(store.state.isLoading)
            .frame(height: 45)
            .accessibilityIdentifier(accessibilityID)

            Rectangle()
                .fill(AppColor.Separator.default.color)
                .frame(height: 1)
        }
    }

    private var loginButton: some View {
        Button {
            Task {
                await store.login()
            }
        } label: {
            HStack(spacing: 8) {
                if store.state.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
                Text(store.state.isLoading ? "登录中…" : "登录")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(loginButtonBackground, in: RoundedRectangle(cornerRadius: 12))
        }
        .keyboardShortcut(.return, modifiers: [])
        .disabled(canLogin == false)
        .buttonStyle(.plain)
        .accessibilityIdentifier("login-submit-button")
    }

    private var privacyAgreement: some View {
        HStack(spacing: 0) {
            Toggle(isOn: Binding(
                get: { store.state.acceptedPrivacy },
                set: { store.setPrivacyAccepted($0) }
            )) {
                EmptyView()
            }
            .toggleStyle(PrivacyCheckboxToggleStyle())
            .accessibilityIdentifier("login-privacy-checkbox")

            Text("已阅读并同意")
                .font(.subheadline)
                .foregroundStyle(AppColor.Label.secondary.color)

            if let privacyDestination {
                NavigationLink {
                    privacyDestination
                } label: {
                    Text("《隐私政策》")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColor.Accent.primary.color)
            } else {
                Text("《隐私政策》")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.Accent.primary.color)
            }
        }
        .frame(minHeight: 44)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var brandHeader: some View {
        VStack(spacing: 0) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconCornerRadius))
                .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
                .padding(.bottom, 30)
            VStack(spacing: 8) {
                Text("AI数据分析助手")
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(AppColor.Label.primary.color)
                    .accessibilityIdentifier("login-title")
                Text("让工作更流畅更轻松")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppColor.Label.secondary.color)
            }
        }
    }

    private var loginBackground: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "#2F7BFF").opacity(0.08), location: 0),
                .init(color: Color(hex: "#18B8FF").opacity(0.02), location: 0.3),
                .init(color: Color(hex: "#18B8FF").opacity(0.02), location: 0.7),
                .init(color: Color(hex: "#2F7BFF").opacity(0.06), location: 1),
            ],
            startPoint: UnitPoint(x: 0.2, y: 0),
            endPoint: UnitPoint(x: 0.8, y: 1)
        )
        .background(AppColor.Background.secondary.color)
    }

    private var canLogin: Bool {
        store.state.account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        && store.state.password.isEmpty == false
        && store.state.isLoading == false
    }

    private var loginButtonBackground: Color {
        canLogin ? AppColor.Accent.primary.color : Color(hex: "#8EA8D8")
    }

    private var iconSize: CGFloat {
        horizontalSizeClass == .compact ? 86 : 88
    }

    private var iconCornerRadius: CGFloat {
        horizontalSizeClass == .compact ? 19 : 20
    }

    private var titleSize: CGFloat {
        horizontalSizeClass == .compact ? 30 : 32
    }
}

private struct PrivacyCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack {
                Circle()
                    .stroke(configuration.isOn ? AppColor.Accent.primary.color : AppColor.Label.tertiary.color, lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                if configuration.isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(AppColor.Accent.primary.color, in: Circle())
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

public struct PreviewAccountService: AccountServicing {
    public init() {}

    public func resolveLaunchSession() async throws -> AccountSession? {
        nil
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

private extension AppError {
    var messageForDisplay: String {
        switch kind {
        case .server(_, let message) where message.isEmpty == false:
            message
        case .sessionInvalid:
            "登录状态已失效，请重新登录"
        case .transport:
            "网络连接失败，请稍后重试"
        default:
            "登录失败，请稍后重试"
        }
    }
}
