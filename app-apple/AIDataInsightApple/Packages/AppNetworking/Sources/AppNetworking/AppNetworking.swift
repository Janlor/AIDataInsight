import AppContracts
import AppCore
import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

public struct HTTPQueryItem: Equatable, Sendable {
    public let name: String
    public let value: String?

    public init(name: String, value: String?) {
        self.name = name
        self.value = value
    }
}

public struct HTTPRequest: Sendable {
    public let path: String
    public let method: HTTPMethod
    public let queryItems: [HTTPQueryItem]
    public let headers: [String: String]
    public let body: Data?

    public init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [HTTPQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
    }
}

public protocol TokenProviding: Sendable {
    var accessToken: String? { get async }
}

public protocol SessionCredentialManaging: TokenProviding {
    var refreshToken: String? { get async }
    var orgID: String? { get async }
    func persist(_ session: AccountSessionContract) async throws
    func clear(reason: SessionInvalidationReason) async throws
}

public struct SSEEvent: Equatable, Sendable {
    public let data: String

    public init(data: String) {
        self.data = data
    }
}

public protocol HTTPClient: Sendable {
    func send<Payload: Decodable & Sendable>(_ request: HTTPRequest, as payloadType: Payload.Type) async throws -> APIResponseEnvelope<Payload>
}

public protocol SSEStreaming: Sendable {
    func stream(_ request: HTTPRequest) -> AsyncThrowingStream<SSEEvent, Error>
}

public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError(kind: .transport(message: "Missing HTTP response."))
        }
        return (data, httpResponse)
    }
}

public actor TokenRefreshCoordinator {
    private var task: Task<AccountSessionContract, Error>?

    public init() {}

    public func refresh(using operation: @escaping @Sendable () async throws -> AccountSessionContract) async throws -> AccountSessionContract {
        if let task {
            return try await task.value
        }

        let task = Task {
            try await operation()
        }
        self.task = task
        defer { self.task = nil }
        return try await task.value
    }
}

public struct URLSessionHTTPClient: HTTPClient {
    private let environment: APIEnvironment
    private let transport: HTTPTransport
    private let sessionManager: SessionCredentialManaging?
    private let refreshCoordinator: TokenRefreshCoordinator
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(
        environment: APIEnvironment,
        transport: HTTPTransport = URLSessionHTTPTransport(),
        sessionManager: SessionCredentialManaging? = nil,
        refreshCoordinator: TokenRefreshCoordinator = TokenRefreshCoordinator(),
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.environment = environment
        self.transport = transport
        self.sessionManager = sessionManager
        self.refreshCoordinator = refreshCoordinator
        self.decoder = decoder
        self.encoder = encoder
    }

    public func send<Payload: Decodable & Sendable>(_ request: HTTPRequest, as payloadType: Payload.Type) async throws -> APIResponseEnvelope<Payload> {
        try await send(request, as: payloadType, allowsRefresh: true)
    }

    public func encodedRequest<Body: Encodable & Sendable>(path: String, body: Body) throws -> HTTPRequest {
        let data = try encoder.encode(body)
        return HTTPRequest(path: path, method: .post, headers: ["Content-Type": "application/json"], body: data)
    }

    private func send<Payload: Decodable & Sendable>(
        _ request: HTTPRequest,
        as payloadType: Payload.Type,
        allowsRefresh: Bool
    ) async throws -> APIResponseEnvelope<Payload> {
        let urlRequest = try await makeURLRequest(from: request)
        let (data, response) = try await transport.data(for: urlRequest)
        guard (200 ..< 300).contains(response.statusCode) else {
            throw AppError(kind: .transport(message: "HTTP \(response.statusCode)"))
        }

        let envelope = try decoder.decode(APIResponseEnvelope<Payload>.self, from: data)
        switch envelope.code {
        case 200:
            return envelope
        case 401:
            try await sessionManager?.clear(reason: .unauthorized)
            postSessionInvalidation(reason: .unauthorized)
            throw AppError(kind: .sessionInvalid(.unauthorized), traceID: envelope.trace, transactionID: envelope.tid)
        case 402 where allowsRefresh:
            _ = try await refreshAccessToken()
            return try await send(request, as: payloadType, allowsRefresh: false)
        case 402:
            try await sessionManager?.clear(reason: .refreshFailed)
            postSessionInvalidation(reason: .refreshFailed)
            throw AppError(kind: .sessionInvalid(.refreshFailed), traceID: envelope.trace, transactionID: envelope.tid)
        default:
            throw AppError(
                kind: .server(code: envelope.code, message: envelope.msg),
                traceID: envelope.trace,
                transactionID: envelope.tid
            )
        }
    }

    private func refreshAccessToken() async throws -> AccountSessionContract {
        guard let refreshToken = await sessionManager?.refreshToken, refreshToken.isEmpty == false else {
            try await sessionManager?.clear(reason: .refreshFailed)
            postSessionInvalidation(reason: .refreshFailed)
            throw AppError(kind: .sessionInvalid(.refreshFailed))
        }

        return try await refreshCoordinator.refresh {
            let refreshRequest = HTTPRequest(
                path: "/oauth2/refresh",
                queryItems: [HTTPQueryItem(name: "refreshToken", value: refreshToken)]
            )
            let urlRequest = try await makeURLRequest(from: refreshRequest, includesAccessToken: false)
            let (data, _) = try await transport.data(for: urlRequest)
            let envelope = try decoder.decode(APIResponseEnvelope<AccountSessionContract>.self, from: data)

            guard envelope.code == 200, let session = envelope.data else {
                try await sessionManager?.clear(reason: .refreshFailed)
                postSessionInvalidation(reason: .refreshFailed)
                throw AppError(kind: .sessionInvalid(.refreshFailed), traceID: envelope.trace, transactionID: envelope.tid)
            }

            try await sessionManager?.persist(session)
            return session
        }
    }

    private func postSessionInvalidation(reason: SessionInvalidationReason) {
        NotificationCenter.default.post(
            name: .appSessionInvalidated,
            object: nil,
            userInfo: [SessionInvalidationNotification.reasonKey: reason]
        )
    }

    private func makeURLRequest(from request: HTTPRequest, includesAccessToken: Bool = true) async throws -> URLRequest {
        let url = try makeURL(path: request.path, queryItems: request.queryItems)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if includesAccessToken, let accessToken = await sessionManager?.accessToken, accessToken.isEmpty == false {
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let orgID = await sessionManager?.orgID, orgID.isEmpty == false {
            urlRequest.setValue(orgID, forHTTPHeaderField: "Org-Id")
        }

        return urlRequest
    }

    private func makeURL(path: String, queryItems: [HTTPQueryItem]) throws -> URL {
        if path.hasPrefix("http") {
            guard var components = URLComponents(string: path) else {
                throw AppError(kind: .dataFormat)
            }
            components.queryItems = queryItems.isEmpty ? nil : queryItems.map { URLQueryItem(name: $0.name, value: $0.value) }
            guard let resolvedURL = components.url else {
                throw AppError(kind: .dataFormat)
            }
            return resolvedURL
        }

        guard var components = URLComponents(url: environment.baseURL, resolvingAgainstBaseURL: false) else {
            throw AppError(kind: .dataFormat)
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let requestPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, requestPath].filter { $0.isEmpty == false }.joined(separator: "/")
        components.queryItems = queryItems.isEmpty ? nil : queryItems.map { URLQueryItem(name: $0.name, value: $0.value) }
        guard let resolvedURL = components.url else {
            throw AppError(kind: .dataFormat)
        }
        return resolvedURL
    }
}

extension URLSessionHTTPClient: SSEStreaming {
    public func stream(_ request: HTTPRequest) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var urlRequest = try await makeURLRequest(from: request)
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    guard let httpResponse = response as? HTTPURLResponse, (200 ..< 300).contains(httpResponse.statusCode) else {
                        throw AppError(kind: .transport(message: "Invalid SSE response."))
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data:") else {
                            continue
                        }
                        let data = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard data.isEmpty == false, data != "[DONE]" else {
                            continue
                        }
                        continuation.yield(SSEEvent(data: data))
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

public struct UnimplementedHTTPClient: HTTPClient {
    public init() {}

    public func send<Payload: Decodable & Sendable>(_ request: HTTPRequest, as payloadType: Payload.Type) async throws -> APIResponseEnvelope<Payload> {
        throw AppError(kind: .unknown)
    }
}
