import Foundation

struct APIError: LocalizedError, Sendable {
    let message: String
    var errorDescription: String? { message }
}

private struct APIErrorBody: Decodable {
    let error: String
}

private struct IdentifierBody: Encodable {
    let identifier: String
}

private struct VerifyBody: Encodable {
    let identifier: String
    let code: String
}

private struct NameBody: Encodable {
    let name: String
}

private struct ProgressBody: Encodable {
    let positionSeconds: Double
    let durationSeconds: Double
}

private struct CreateProfileBody: Encodable {
    let name: String
    let avatarColor: String
    let isKids: Bool
    let pin: String?
}

private struct UpdateProfileBody: Encodable {
    let name: String?
    let avatarColor: String?
    let isKids: Bool?
    let pin: String?
    let clearPin: Bool?
}

private struct PinBody: Encodable {
    let pin: String
}

struct APIClient: Sendable {
    static let shared = APIClient()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Auth

    func requestCode(identifier: String) async throws -> RequestCodeResponse {
        try await send(
            "v1/auth/request-code",
            method: "POST",
            body: JSONEncoder().encode(IdentifierBody(identifier: identifier))
        )
    }

    func verify(identifier: String, code: String) async throws -> AuthResponse {
        try await send(
            "v1/auth/verify",
            method: "POST",
            body: JSONEncoder().encode(VerifyBody(identifier: identifier, code: code))
        )
    }

    func logout() async throws -> OKResponse {
        try await send("v1/auth/logout", method: "POST")
    }

    func me() async throws -> AuthUser {
        try await send("v1/me")
    }

    func updateName(_ name: String) async throws -> AuthUser {
        try await send(
            "v1/me",
            method: "PATCH",
            body: JSONEncoder().encode(NameBody(name: name))
        )
    }

    func deleteAccount() async throws -> OKResponse {
        try await send("v1/me", method: "DELETE")
    }

    func session() async throws -> SessionResponse {
        try await send("v1/session")
    }

    // MARK: - Profiles

    func profiles() async throws -> [Profile] {
        try await send("v1/profiles")
    }

    func createProfile(
        name: String,
        avatarColor: String,
        isKids: Bool,
        pin: String?
    ) async throws -> Profile {
        try await send(
            "v1/profiles",
            method: "POST",
            body: JSONEncoder().encode(
                CreateProfileBody(
                    name: name,
                    avatarColor: avatarColor,
                    isKids: isKids,
                    pin: pin
                )
            )
        )
    }

    func updateProfile(
        id: String,
        name: String? = nil,
        avatarColor: String? = nil,
        isKids: Bool? = nil,
        pin: String? = nil,
        clearPin: Bool? = nil
    ) async throws -> Profile {
        try await send(
            "v1/profiles/\(encodedPath(id))",
            method: "PATCH",
            body: JSONEncoder().encode(
                UpdateProfileBody(
                    name: name,
                    avatarColor: avatarColor,
                    isKids: isKids,
                    pin: pin,
                    clearPin: clearPin
                )
            )
        )
    }

    func deleteProfile(id: String) async throws -> OKResponse {
        try await send("v1/profiles/\(encodedPath(id))", method: "DELETE")
    }

    func unlockProfile(id: String, pin: String) async throws -> OKResponse {
        try await send(
            "v1/profiles/\(encodedPath(id))/unlock",
            method: "POST",
            body: JSONEncoder().encode(PinBody(pin: pin))
        )
    }

    // MARK: - Catalog

    func home() async throws -> HomePayload {
        try await send("v1/catalog/home")
    }

    func search(_ query: String) async throws -> [MediaTitle] {
        try await send("v1/catalog/search", query: [URLQueryItem(name: "q", value: query)])
    }

    func title(id: String) async throws -> MediaTitle {
        try await send("v1/titles/\(encodedPath(id))")
    }

    // MARK: - Progress

    func progress() async throws -> [PlaybackProgress] {
        try await send("v1/progress")
    }

    func updateProgress(titleID: String, position: Double, duration: Double) async throws -> PlaybackProgress {
        try await send(
            "v1/progress/\(encodedPath(titleID))",
            method: "PUT",
            body: JSONEncoder().encode(ProgressBody(positionSeconds: position, durationSeconds: duration))
        )
    }

    // MARK: - Watchlist

    func watchlist() async throws -> [MediaTitle] {
        try await send("v1/watchlist")
    }

    func addToWatchlist(id: String) async throws -> OKResponse {
        try await send("v1/watchlist/\(encodedPath(id))", method: "POST")
    }

    func removeFromWatchlist(id: String) async throws -> OKResponse {
        try await send("v1/watchlist/\(encodedPath(id))", method: "DELETE")
    }

    // MARK: - Transport

    private func encodedPath(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private func send<T: Decodable>(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> T {
        var url = ServerConfig.baseURL
        for component in path.split(separator: "/") {
            url.appendPathComponent(String(component))
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError(message: "The server URL is invalid.")
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let finalURL = components.url else {
            throw APIError(message: "The server URL is invalid.")
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token = Keychain.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let profileID = ProfileContext.currentID {
            request.setValue(profileID, forHTTPHeaderField: "X-Nova-Profile")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError(message: "Can't reach the Nova server. Check the server URL and your connection.")
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "The server returned an invalid response.")
        }

        guard (200..<300).contains(http.statusCode) else {
            if let errorBody = try? JSONDecoder().decode(APIErrorBody.self, from: data) {
                throw APIError(message: errorBody.error)
            }
            throw APIError(message: "Server error (\(http.statusCode)).")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError(message: "The server returned data Nova couldn't read.")
        }
    }
}
