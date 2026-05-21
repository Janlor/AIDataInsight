import Testing
import AppAccount
import AppContracts
@testable import FeatureLogin

@MainActor
@Test func loginStoreUpdatesInputState() {
    let store = LoginStore()
    store.updateAccount("janlor")
    store.updatePassword("secret")
    store.setPrivacyAccepted(true)

    #expect(store.state.account == "janlor")
    #expect(store.state.password == "secret")
    #expect(store.state.acceptedPrivacy)
}

@MainActor
@Test func loginStateMatchesContractDefaultsAndLimitsInputLength() {
    let store = LoginStore()

    #expect(store.state.account == "demo")
    #expect(store.state.password == "demo@123")
    #expect(store.state.acceptedPrivacy)

    store.updateAccount(String(repeating: "a", count: 40))
    store.updatePassword(String(repeating: "b", count: 40))

    #expect(store.state.account.count == 30)
    #expect(store.state.password.count == 30)
}

@MainActor
@Test func loginStoreTracksLaunchSessionResolution() async {
    let store = LoginStore(accountService: StaticAccountService(session: AccountSession(
        accessToken: "token",
        refreshToken: "refresh",
        orgID: "1",
        username: "demo"
    )))

    #expect(store.state.hasResolvedLaunchSession == false)

    await store.resolveLaunchSession()

    #expect(store.state.hasResolvedLaunchSession)
    #expect(store.state.isAuthenticated)
}

private actor StaticAccountService: AccountServicing {
    let session: AccountSession?

    init(session: AccountSession?) {
        self.session = session
    }

    func resolveLaunchSession() async throws -> AccountSession? {
        session
    }

    func login(name: String, password: String) async throws -> AccountSession {
        session ?? AccountSession(accessToken: "token", refreshToken: "refresh", orgID: "1", username: name)
    }

    func cachedUserInfo() async throws -> AccountUserContract? {
        nil
    }

    func getUserInfo() async throws -> AccountUserContract {
        AccountUserContract(id: 1, username: "demo", nickname: nil, phone: nil)
    }

    func logout() async throws {}
}
