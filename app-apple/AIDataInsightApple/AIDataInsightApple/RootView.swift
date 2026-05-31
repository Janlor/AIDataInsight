//
//  RootView.swift
//  AIDataInsightApple
//
//  Created by Codex on 5/19/26.
//

import AppDesignSystem
import AppCore
import Foundation
import FeatureAIChat
import FeatureHistory
import FeatureLogin
import FeaturePrivacy
import FeatureSetting
import SwiftData
import SwiftUI

struct RootView: View {
    @Bindable var environment: AppRuntimeEnvironment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#if os(macOS)
    @Environment(\.openSettings) private var openSettings
#endif
    @State private var settingPath: [RootRoute] = []
    @State private var showsSetting = false
    @State private var showsHistory = false
    @State private var historyDrawerProgress: CGFloat = 0
    @State private var historyDragStartProgress: CGFloat?
    @State private var showsPrivacy = false
    @State private var showsLogoutConfirmation = false

    var body: some View {
        Group {
            if environment.loginStore.state.hasResolvedLaunchSession == false {
                launchResolvingView
            } else if environment.loginStore.state.isAuthenticated {
                if horizontalSizeClass == .compact {
                    compactWorkspace
                } else {
                    splitWorkspace
                }
            } else {
                NavigationStack {
                    LoginScreen(store: environment.loginStore, privacyDestination: AnyView(PrivacyScreen()))
                }
            }
        }
        .tokenizedBackground()
        .modelContainer(environment.modelContainer)
        .desktopContentSize()
        .task {
            // 启动后先恢复本地登录态，避免在登录页和主界面之间闪烁。
            await environment.loginStore.resolveLaunchSession()
        }
        .task(id: environment.loginStore.state.isAuthenticated) {
            guard environment.loginStore.state.isAuthenticated else {
                return
            }
            // 认证成功后再加载受保护数据，避免未登录时触发后端 401。
            await environment.settingStore.load()
            await environment.historyStore.loadFirstPage()
        }
        .onChange(of: environment.chatStore.state.isSending) { _, isSending in
            guard isSending == false, environment.chatStore.state.activeHistoryID != nil else {
                return
            }
            // 发送完成后刷新历史首页，让新会话或标题变化尽快反映到侧边栏。
            Task {
                await environment.historyStore.loadFirstPage()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .startNewChat)) { _ in
            environment.historyStore.clearSelection()
            environment.chatStore.startNewChat()
            closeCompactHistory()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPrivacyPolicy)) { _ in
            showsPrivacy = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestLogout)) { _ in
            showsLogoutConfirmation = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .appSessionInvalidated)) { notification in
            handleSessionInvalidation(SessionInvalidationNotification.reason(from: notification) ?? .unauthorized)
        }
        .onChange(of: environment.settingStore.state.didLogout) { _, didLogout in
            guard didLogout else {
                return
            }
            environment.loginStore.markLoggedOut()
            environment.settingStore.consumeLogoutSignal()
            clearProtectedStateForLogin()
        }
        .sheet(isPresented: $showsPrivacy) {
            NavigationStack {
                PrivacyScreen()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            closeButton {
                                showsPrivacy = false
                            }
                            .accessibilityIdentifier("privacy-close-button")
                        }
                    }
            }
            .frame(minWidth: 520, minHeight: 620)
        }
        .confirmationDialog(
            "退出后需要重新登录才能继续使用。",
            isPresented: $showsLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button(environment.settingStore.state.isLoggingOut ? "退出中..." : "退出登录", role: .destructive) {
                Task {
                    await environment.settingStore.logout()
                }
            }
            .disabled(environment.settingStore.state.isLoggingOut)

            Button("取消", role: .cancel) {}
        }
    }

    private var launchResolvingView: some View {
        AppColor.Background.secondary.color
            .ignoresSafeArea()
            .accessibilityIdentifier("launch-session-resolving")
    }

    private var splitWorkspace: some View {
                NavigationSplitView {
                    HistorySidebar(
                        store: environment.historyStore,
                        account: accountDisplay,
                        onNewChat: {
                            environment.chatStore.startNewChat()
                        },
                        onSelect: { historyID in
                            Task {
                                await environment.chatStore.loadHistory(historyID: historyID)
                            }
                        },
                        onDeletedSelected: {
                            environment.chatStore.startNewChat()
                        },
                        onOpenSetting: {
#if os(macOS)
                            openSettings()
#else
                            showsSetting = true
#endif
                        },
                        onOpenPrivacy: {
                            showsPrivacy = true
                        },
                        onLogout: {
                            showsLogoutConfirmation = true
                        }
                    )
                } detail: {
                    AIChatScreen(store: environment.chatStore, account: accountDisplay)
                        .toolbar {
                            ToolbarItem {
                                Button("New Chat", systemImage: "square.and.pencil") {
                                    startNewChat()
                                }
                                .disabled(canStartNewChat == false)
                                .accessibilityIdentifier("toolbar-new-chat-button")
                            }
                        }
                }
#if !os(macOS)
                .sheet(isPresented: $showsSetting) {
                    settingView
                        .frame(minWidth: 500, minHeight: 600)
                }
#endif
    }

    private var compactWorkspace: some View {
        GeometryReader { proxy in
            let drawerWidth = min(proxy.size.width * 0.86, 360)
            let dragX = compactHistoryDragX(drawerWidth: drawerWidth)

            // 紧凑尺寸下用自定义抽屉承载历史列表，保留聊天页的完整导航栈。
            ZStack(alignment: .leading) {
                NavigationStack {
                    AIChatScreen(store: environment.chatStore, account: accountDisplay)
                        .toolbar {
#if !os(macOS)
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("History", systemImage: "sidebar.left") {
                                    openCompactHistory()
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("New Chat", systemImage: "square.and.pencil") {
                                    startNewChat()
                                }
                                .disabled(canStartNewChat == false)
                                .accessibilityIdentifier("toolbar-new-chat-button")
                            }
#endif
                        }
                }
                .offset(x: dragX)
                .scaleEffect(historyDrawerProgress > 0 ? 0.98 : 1, anchor: .trailing)
                .contentShape(Rectangle())
                .simultaneousGesture(compactHistoryGesture(drawerWidth: drawerWidth))
                .overlay {
                    if dragX > 0 {
                        Color.black
                            .opacity(0.22 * min(dragX / drawerWidth, 1))
                            .ignoresSafeArea()
                            .onTapGesture {
                                closeCompactHistory()
                            }
                            .highPriorityGesture(compactHistoryGesture(drawerWidth: drawerWidth))
                    }
                }

                compactHistoryDrawer
                    .frame(width: drawerWidth)
                    .offset(x: dragX - drawerWidth)
                    .shadow(color: .black.opacity(0.18), radius: 18, x: 8, y: 0)
                    .simultaneousGesture(compactHistoryGesture(drawerWidth: drawerWidth))
            }
            .clipped()
            .ignoresSafeArea(.container, edges: [.top, .bottom])
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .sheet(isPresented: $showsSetting) {
            settingView
        }
    }

    private var compactHistoryDrawer: some View {
        NavigationStack {
            HistorySidebar(
                store: environment.historyStore,
                account: accountDisplay,
                onNewChat: {
                    environment.historyStore.clearSelection()
                    environment.chatStore.startNewChat()
                    closeCompactHistory()
                },
                onSelect: { historyID in
                    Task {
                        await environment.chatStore.loadHistory(historyID: historyID)
                        closeCompactHistory()
                    }
                },
                onDeletedSelected: {
                    environment.chatStore.startNewChat()
                },
                onOpenSetting: {
                    showsSetting = true
                },
                onOpenPrivacy: {
                    closeCompactHistory()
                    showsPrivacy = true
                },
                onLogout: {
                    closeCompactHistory()
                    showsLogoutConfirmation = true
                }
            )
        }
        .background(.bar)
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .accessibilityIdentifier("history-drawer")
    }

    private func compactHistoryDragX(drawerWidth: CGFloat) -> CGFloat {
        drawerWidth * min(max(historyDrawerProgress, 0), 1)
    }

    private func compactHistoryGesture(drawerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                if historyDragStartProgress == nil {
                    // 只接管横向手势，避免和聊天内容的纵向滚动互相抢占。
                    guard isHorizontalHistoryDrag(value.translation),
                          historyDrawerProgress > 0 || value.translation.width > 0
                    else {
                        return
                    }
                    historyDragStartProgress = historyDrawerProgress
                }
                guard let startProgress = historyDragStartProgress else {
                    return
                }
                historyDrawerProgress = min(max(startProgress + value.translation.width / drawerWidth, 0), 1)
                showsHistory = historyDrawerProgress > 0
            }
            .onEnded { value in
                guard let startProgress = historyDragStartProgress else {
                    return
                }
                let predictedProgress = min(max(startProgress + value.predictedEndTranslation.width / drawerWidth, 0), 1)
                let shouldOpen = predictedProgress > 0.45 || historyDrawerProgress > 0.55
                historyDragStartProgress = nil
                if shouldOpen {
                    openCompactHistory()
                } else {
                    closeCompactHistory()
                }
            }
    }

    private func isHorizontalHistoryDrag(_ translation: CGSize) -> Bool {
        abs(translation.width) > max(abs(translation.height) * 1.25, 1) // 18 to 1
    }

    private func openCompactHistory() {
        withAnimation(.easeOut(duration: 0.22)) {
            showsHistory = true
            historyDrawerProgress = 1
            historyDragStartProgress = nil
        }
    }

    private func closeCompactHistory() {
        withAnimation(.easeOut(duration: 0.22)) {
            showsHistory = false
            historyDrawerProgress = 0
            historyDragStartProgress = nil
        }
    }

    private var canStartNewChat: Bool {
        // 空白欢迎态不需要“新建会话”；已有草稿、消息或历史上下文时才启用。
        environment.chatStore.state.activeHistoryID != nil
        || environment.chatStore.state.messages.isEmpty == false
        || environment.chatStore.state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var accountDisplay: AccountDisplayState {
        let rows = environment.settingStore.state.sections.flatMap(\.rows)
        let nickname = rows.first(where: { $0.kind == .nickname })?.detail.nonEmptyAccountField
        let username = rows.first(where: { $0.kind == .username })?.detail.nonEmptyAccountField
        let phone = rows.first(where: { $0.kind == .phone })?.detail.nonEmptyAccountField
        return AccountDisplayState(
            displayName: nickname ?? username ?? phone ?? "用户",
            secondaryText: username ?? phone
        )
    }

    private func startNewChat() {
        environment.historyStore.clearSelection()
        environment.chatStore.startNewChat()
    }

    private func handleSessionInvalidation(_ reason: SessionInvalidationReason) {
        guard reason != .logout, environment.loginStore.state.isAuthenticated else {
            return
        }
        // token 失效来自网络层通知，根视图统一清理受保护状态并回到登录流程。
        environment.loginStore.markLoggedOut()
        clearProtectedStateForLogin()
    }

    private func clearProtectedStateForLogin() {
        environment.historyStore.clearCachedData()
        environment.chatStore.startNewChat()
        settingPath.removeAll()
        showsSetting = false
        closeCompactHistory()
        showsPrivacy = false
        showsLogoutConfirmation = false
    }

    private var settingView: some View {
        NavigationStack(path: $settingPath) {
            SettingScreen(
                store: environment.settingStore,
                onOpenPrivacy: {
                    settingPath.append(.privacy)
                }
            )
            .navigationDestination(for: RootRoute.self) { route in
                switch route {
                case .privacy:
                    PrivacyScreen()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    closeButton {
                        showsSetting = false
                    }
                    .accessibilityIdentifier("setting-close-button")
                }
            }
        }
    }

    private func closeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("Close", systemImage: "xmark")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .accessibilityLabel("关闭")
    }
}

#Preview {
    RootView(environment: AppRuntimeEnvironment(usePreviewRepositories: true))
}

private enum RootRoute: Hashable {
    case privacy
}

private extension View {
    @ViewBuilder
    func desktopContentSize() -> some View {
#if os(macOS)
        frame(minWidth: 1040, minHeight: 680)
#else
        self
#endif
    }
}

private extension Optional where Wrapped == String {
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
