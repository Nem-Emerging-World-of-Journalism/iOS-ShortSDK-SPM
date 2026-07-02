//
//  GraphQLService.swift
//  JioNewsShortsSDK
//
//  Thin GraphQL client for the native (AVPlayer) shorts feed.
//  Only the `getNativeShorts` query is implemented; the Authorization
//  token is supplied per-request by the host app via `ShortsView.configure`.
//

import Foundation

// MARK: - Request payload

struct GraphQLRequest<Variables: Encodable>: Encodable {
    let operationName: String
    let query: String
    let variables: Variables
}

struct GetNativeShortsVariables: Encodable {
    let page: Int
    let size: Int
    let categoryId: String?
    let dateTime: String?
}

struct AddReactionVariables: Encodable {
    let newsBriefId: String
    let reactionType: String
    let contentType: String
}

struct ResetReactionVariables: Encodable {
    let newsBriefId: String
    let contentType: String
}

struct TapShareVariables: Encodable {
    let newsBriefId: String
    let contentType: String
}

struct NewsBriefByIdVariables: Encodable {
    let newsBriefByIdId: String
    let contentType: String?
}

struct LoginWebVariables: Encodable {
    let deviceName: String
    let deviceType: String
    let fingerprint: String
    let hId: String
}

// MARK: - loginWeb response

struct LoginWebResponseRoot: Decodable {
    let data: LoginWebData?
    let errors: [GraphQLErrorEntry]?
}

struct LoginWebData: Decodable {
    let loginWeb: LoginWebResult?
}

struct LoginWebResult: Decodable {
    let session: LoginSession?
}

struct LoginSession: Decodable {
    let id: String?
    let token: String?
    let refreshToken: String?
}

// MARK: - Errors

enum GraphQLServiceError: Error, LocalizedError {
    case invalidResponse
    case httpStatus(Int, body: String)
    case graphQLErrors([String])

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case .httpStatus(let code, _): return "HTTP \(code)"
        case .graphQLErrors(let msgs): return msgs.joined(separator: "\n")
        }
    }
}

// MARK: - Service

final class GraphQLService {
    static let shared = GraphQLService()
    private init() {}

    /// GraphQL endpoint; set per-session by `ShortsView.initData(env:)`. Defaults to production.
    var endpoint: URL = JioShortsEnvironment.prod.graphQLURL

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        return URLSession(configuration: config)
    }()

    private static let getNativeShortsQuery = """
    query GetNativeShorts($page: Int!, $size: Int!, $categoryId: ID, $dateTime: DateTime) {
        getNativeShorts(page: $page, size: $size, categoryId: $categoryId, dateTime: $dateTime) {
            cursor { prev curr next totalDocs totalPages size }
            dateTime
            newsBriefs {
                id
                video { duration url }
                title
                videoId
                shareCount { text unit count }
                publishedAt { date agoFromNow prettyDateTime }
                publisher { id name }
                type
                reactions {
                    total
                    userReaction
                    reactionType: reactions { type count text unit }
                }
                dataSource
                language { id name }
                thumbnailURL_v2 {
                    default { url }
                    medium { url }
                    high { url }
                    standard { url }
                    maxres { url }
                }
                redirectionURLV1
                source
                category { title id parentName }
            }
        }
    }
    """

    func fetchNativeShortsDecoded(token: String, page: Int = 1, size: Int = 10) async throws -> GetNativeShortsResult {
        let payload = GraphQLRequest(
            operationName: "GetNativeShorts",
            query: Self.getNativeShortsQuery,
            variables: GetNativeShortsVariables(page: page, size: size, categoryId: nil, dateTime: nil)
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GraphQLServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GraphQLServiceError.httpStatus(http.statusCode, body: body)
        }

        let root = try JSONDecoder().decode(GetNativeShortsResponseRoot.self, from: data)
        if let errors = root.errors, !errors.isEmpty {
            throw GraphQLServiceError.graphQLErrors(errors.map(\.message))
        }
        return root.data?.getNativeShorts ?? GetNativeShortsResult(newsBriefs: nil, cursor: nil, dateTime: nil)
    }

    // MARK: - Single brief (deep-link)

    private static let newsBriefByIdQuery = """
    query NewsBriefById($newsBriefByIdId: ID!, $contentType: NewsBriefType) {
        newsBriefById(id: $newsBriefByIdId, contentType: $contentType) {
            newsBrief {
                id
                type
                title
                source
                publisherLink
                redirectionURLV1
                thumbnail { url }
                video { duration url }
                shareCount { text unit count }
                publishedAt { date agoFromNow prettyDateTime }
                publisher { id name }
                category { id title }
                reactions {
                    total
                    userReaction
                    reactionType: reactions { type count text unit }
                }
            }
        }
    }
    """

    /// Fetches a single brief by id — used to pin a deep-linked short to the top of the feed.
    func fetchNewsBriefById(token: String, newsBriefId: String, contentType: String? = nil) async throws -> STBNewsBrief? {
        let payload = GraphQLRequest(
            operationName: "NewsBriefById",
            query: Self.newsBriefByIdQuery,
            variables: NewsBriefByIdVariables(newsBriefByIdId: newsBriefId, contentType: contentType)
        )
        let data = try await perform(token: token, payload: payload)
        let root = try JSONDecoder().decode(NewsBriefByIdResponseRoot.self, from: data)
        if let errors = root.errors, !errors.isEmpty {
            throw GraphQLServiceError.graphQLErrors(errors.map(\.message))
        }
        return root.data?.newsBriefById?.newsBrief
    }

    // MARK: - Reactions (like / remove like)

    private static let addReactionMutation = """
    mutation AddNewsBriefReaction($newsBriefId: ID!, $reactionType: ReactionType!, $contentType: NewsBriefType!) {
        addNewsBriefReaction(newsBriefId: $newsBriefId, reactionType: $reactionType, contentType: $contentType) {
            errors
            reactions {
                total
                userReaction
                reactions { id type count text }
                TotalPrettytext
            }
        }
    }
    """

    private static let resetReactionMutation = """
    mutation ResetNewsBriefReaction($newsBriefId: ID!, $contentType: NewsBriefType!) {
        resetNewsBriefReaction(newsBriefId: $newsBriefId, contentType: $contentType) {
            errors
            reactions {
                total
                userReaction
                reactions { id type count text }
                TotalPrettytext
            }
        }
    }
    """

    /// Adds a reaction (e.g. LIKE) to a brief and returns the updated reactions.
    func addReaction(token: String, newsBriefId: String, reactionType: String, contentType: String) async throws -> ReactionMutationReactions {
        let payload = GraphQLRequest(
            operationName: "AddNewsBriefReaction",
            query: Self.addReactionMutation,
            variables: AddReactionVariables(newsBriefId: newsBriefId, reactionType: reactionType, contentType: contentType)
        )
        let data = try await perform(token: token, payload: payload)
        let root = try JSONDecoder().decode(AddReactionResponseRoot.self, from: data)
        if let errors = root.errors, !errors.isEmpty {
            throw GraphQLServiceError.graphQLErrors(errors.map(\.message))
        }
        let result = root.data?.addNewsBriefReaction
        if let errs = result?.errors, !errs.isEmpty {
            throw GraphQLServiceError.graphQLErrors(errs)
        }
        guard let reactions = result?.reactions else { throw GraphQLServiceError.invalidResponse }
        return reactions
    }

    /// Removes the user's reaction from a brief and returns the updated reactions.
    func resetReaction(token: String, newsBriefId: String, contentType: String) async throws -> ReactionMutationReactions {
        let payload = GraphQLRequest(
            operationName: "ResetNewsBriefReaction",
            query: Self.resetReactionMutation,
            variables: ResetReactionVariables(newsBriefId: newsBriefId, contentType: contentType)
        )
        let data = try await perform(token: token, payload: payload)
        let root = try JSONDecoder().decode(ResetReactionResponseRoot.self, from: data)
        if let errors = root.errors, !errors.isEmpty {
            throw GraphQLServiceError.graphQLErrors(errors.map(\.message))
        }
        let result = root.data?.resetNewsBriefReaction
        if let errs = result?.errors, !errs.isEmpty {
            throw GraphQLServiceError.graphQLErrors(errs)
        }
        guard let reactions = result?.reactions else { throw GraphQLServiceError.invalidResponse }
        return reactions
    }

    // MARK: - Auth (hid -> authToken)

    private static let loginWebMutation = """
    mutation loginWeb($deviceName: String!, $deviceType: DeviceType!, $fingerprint: String!, $hId: String!) {
        loginWeb(deviceName: $deviceName, deviceType: $deviceType, fingerprint: $fingerprint, hId: $hId) {
            session {
                id
                token
                refreshToken
            }
        }
    }
    """

    /// Exchanges an `hid` for a session (Authorization token + id) via `loginWeb`.
    func loginWeb(hid: String, deviceName: String, deviceType: String, fingerprint: String) async throws -> LoginSession {
        let payload = GraphQLRequest(
            operationName: "loginWeb",
            query: Self.loginWebMutation,
            variables: LoginWebVariables(deviceName: deviceName, deviceType: deviceType, fingerprint: fingerprint, hId: hid)
        )
        // No Authorization yet — this call is what mints the token.
        let data = try await perform(token: "", payload: payload)
        let root = try JSONDecoder().decode(LoginWebResponseRoot.self, from: data)
        if let errors = root.errors, !errors.isEmpty {
            throw GraphQLServiceError.graphQLErrors(errors.map(\.message))
        }
        guard let session = root.data?.loginWeb?.session, let token = session.token, !token.isEmpty else {
            throw GraphQLServiceError.invalidResponse
        }
        return session
    }

    // MARK: - Share impression

    private static let tapShareMutation = """
    mutation TapShareNewsBrief($newsBriefId: ID!, $contentType: NewsBriefType!) {
        tapShareNewsBrief(newsBriefId: $newsBriefId, contentType: $contentType) {
            errors
            shareCount { text unit count }
        }
    }
    """

    /// Records a share impression. Fire-and-forget — the response is ignored.
    func tapShare(token: String, newsBriefId: String, contentType: String) async throws {
        let payload = GraphQLRequest(
            operationName: "TapShareNewsBrief",
            query: Self.tapShareMutation,
            variables: TapShareVariables(newsBriefId: newsBriefId, contentType: contentType)
        )
        _ = try await perform(token: token, payload: payload)
    }

    // MARK: - Transport

    private func perform<V: Encodable>(token: String, payload: GraphQLRequest<V>) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GraphQLServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GraphQLServiceError.httpStatus(http.statusCode, body: body)
        }
        return data
    }
}
