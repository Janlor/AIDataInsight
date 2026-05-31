import Testing
import AppContracts
import AppCore
import Foundation
@testable import AppNetworking

@Test func httpRequestDefaultsToGet() {
    let request = HTTPRequest(path: "/oauth2/login")
    #expect(request.method == .get)
    #expect(request.path == "/oauth2/login")
}

@Test func clientRefreshesOnExpiredAccessTokenThenRetriesOriginalRequest() async throws {
    let session = MockSessionManager(
        accessToken: "expired",
        refreshToken: "refresh",
        orgID: "8"
    )
    let transport = MockHTTPTransport(responses: [
        response(code: 200, body: #"{"code":402,"msg":"expired"}"#),
        response(code: 200, body: #"{"code":200,"msg":"ok","data":{"accessToken":"fresh","refreshToken":"refresh","orgId":8}}"#),
        response(code: 200, body: #"{"code":200,"msg":"ok","data":{"value":"done"}}"#),
    ])
    let client = URLSessionHTTPClient(
        environment: .mock,
        transport: transport,
        sessionManager: session
    )

    let envelope = try await client.send(HTTPRequest(path: "/protected"), as: TestPayload.self)

    #expect(envelope.data?.value == "done")
    #expect(await session.accessToken == "fresh")
    #expect(await transport.requestCount == 3)
}

@Test func clientClearsSessionOnUnauthorizedEnvelope() async throws {
    let session = MockSessionManager(accessToken: "token", refreshToken: "refresh", orgID: "8")
    let transport = MockHTTPTransport(responses: [
        response(code: 200, body: #"{"code":401,"msg":"unauthorized","trace":"t","tid":"x"}"#),
    ])
    let client = URLSessionHTTPClient(
        environment: .mock,
        transport: transport,
        sessionManager: session
    )
    let notifications = NotificationCenter.default.notifications(named: .appSessionInvalidated)
    let notificationTask = Task {
        for await notification in notifications {
            return SessionInvalidationNotification.reason(from: notification)
        }
        return nil
    }

    await #expect(throws: AppError.self) {
        _ = try await client.send(HTTPRequest(path: "/protected"), as: TestPayload.self)
    }
    #expect(await session.didClear)
    #expect(await notificationTask.value == .unauthorized)
}

private struct TestPayload: Decodable, Equatable, Sendable {
    let value: String
}

private func response(code: Int, body: String) -> (Data, HTTPURLResponse) {
    (
        Data(body.utf8),
        HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    )
}

private actor MockHTTPTransport: HTTPTransport {
    private var responses: [(Data, HTTPURLResponse)]
    private(set) var requestCount = 0

    init(responses: [(Data, HTTPURLResponse)]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requestCount += 1
        return responses.removeFirst()
    }
}

private actor MockSessionManager: SessionCredentialManaging {
    private var storedAccessToken: String?
    private var storedRefreshToken: String?
    private var storedOrgID: String?
    private(set) var didClear = false

    init(accessToken: String?, refreshToken: String?, orgID: String?) {
        storedAccessToken = accessToken
        storedRefreshToken = refreshToken
        storedOrgID = orgID
    }

    var accessToken: String? {
        get async { storedAccessToken }
    }

    var refreshToken: String? {
        get async { storedRefreshToken }
    }

    var orgID: String? {
        get async { storedOrgID }
    }

    func persist(_ session: AccountSessionContract) async throws {
        storedAccessToken = session.accessToken
        storedRefreshToken = session.refreshToken
        storedOrgID = session.orgId.map(String.init)
    }

    func clear(reason: SessionInvalidationReason) async throws {
        didClear = true
        storedAccessToken = nil
        storedRefreshToken = nil
        storedOrgID = nil
    }
}
