//
//  AppEnvironment.swift
//  AIDataInsightApple
//
//  Created by Codex on 5/19/26.
//

import AppAccount
import AppContracts
import AppCore
import AppNetworking
import AppPersistence
import FeatureAIChat
import FeatureHistory
import FeatureLogin
import FeatureSetting
import Observation
import SwiftData

@MainActor
@Observable
final class AppRuntimeEnvironment {
    let appEnvironment: AppEnvironment
    let loginStore: LoginStore
    let chatStore: AIChatStore
    let historyStore: HistoryStore
    let settingStore: SettingStore
    let sessionManager: AccountSessionManager
    let modelContainer: ModelContainer

    init(
        appEnvironment: AppEnvironment = .local,
        loginStore: LoginStore? = nil,
        chatStore: AIChatStore? = nil,
        historyStore: HistoryStore? = nil,
        settingStore: SettingStore? = nil,
        sessionManager: AccountSessionManager? = nil,
        modelContainer: ModelContainer? = nil,
        usePreviewRepositories: Bool = false
    ) {
        self.appEnvironment = appEnvironment
        self.modelContainer = modelContainer ?? AppRuntimeEnvironment.makeModelContainer()
        let userStore = KeychainAccountUserStore()
        let resolvedSessionManager = sessionManager ?? AccountSessionManager(store: KeychainSessionStore(), userStore: userStore)
        self.sessionManager = resolvedSessionManager
        let client = URLSessionHTTPClient(
            environment: APIEnvironment.resolve(appEnvironment),
            sessionManager: resolvedSessionManager
        )
        let accountService: AccountServicing
        let aiChatRepository: AIChatRepository
        let historyRepository: HistoryRepository

        if usePreviewRepositories {
            accountService = MockAccountService()
            aiChatRepository = PreviewAIChatRepository()
            historyRepository = PreviewHistoryRepository()
        } else {
            accountService = AccountService(client: client, sessionManager: resolvedSessionManager, userStore: userStore)
            aiChatRepository = RemoteAIChatRepository(client: client, streamer: client)
            historyRepository = RemoteHistoryRepository(client: client)
        }

        let defaultLoginState = usePreviewRepositories
            ? LoginViewState(acceptedPrivacy: true, hasResolvedLaunchSession: true)
            : LoginViewState()
        self.loginStore = loginStore ?? LoginStore(state: defaultLoginState, accountService: accountService)
        self.chatStore = chatStore ?? AIChatStore(repository: aiChatRepository)
        self.historyStore = historyStore ?? HistoryStore(repository: historyRepository)
        self.settingStore = settingStore ?? SettingStore(accountService: accountService)
    }

    private static func makeModelContainer() -> ModelContainer {
        do {
            return try AppModelContainerFactory.make()
        } catch {
            fatalError("Failed to create SwiftData model container: \(error)")
        }
    }
}

private actor MockAccountService: AccountServicing {
    private var session: AccountSession?

    func resolveLaunchSession() async throws -> AccountSession? {
        session
    }

    func login(name: String, password: String) async throws -> AccountSession {
        let nextSession = AccountSession(
            accessToken: "mock-access-token",
            refreshToken: "mock-refresh-token",
            orgID: "0",
            username: name
        )
        session = nextSession
        return nextSession
    }

    func cachedUserInfo() async throws -> AccountUserContract? {
        AccountUserContract(id: 1, username: "demo", nickname: "演示账号", phone: "18812341234")
    }

    func getUserInfo() async throws -> AccountUserContract {
        AccountUserContract(id: 1, username: "demo", nickname: "演示账号", phone: "18812341234")
    }

    func logout() async throws {
        session = nil
    }
}
