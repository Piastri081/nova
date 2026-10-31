import Foundation

// MARK: - Catalog

struct MediaTitle: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let year: Int?
    let overview: String
    let genres: [String]
    let runtimeMinutes: Int?
    let posterURL: String?
    let backdropURL: String?
    let streamURL: String?
    let rating: Double?
    let source: String?
    let licenseURL: String?
    let tags: [String]

    var runtimeLabel: String? {
        guard let runtimeMinutes, runtimeMinutes > 0 else { return nil }
        let hours = runtimeMinutes / 60
        let minutes = runtimeMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var deepLink: URL? {
        URL(string: "nova://title/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)")
    }
}

struct CatalogRow: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let items: [MediaTitle]
}

struct ContinueWatchingItem: Codable, Identifiable, Hashable, Sendable {
    let title: MediaTitle
    let positionSeconds: Double
    let durationSeconds: Double

    var id: String { title.id }

    var fraction: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(max(positionSeconds / durationSeconds, 0), 1)
    }
}

struct HomePayload: Codable, Sendable {
    let hero: MediaTitle?
    let rows: [CatalogRow]
    let continueWatching: [ContinueWatchingItem]

    static let empty = HomePayload(hero: nil, rows: [], continueWatching: [])
}

// MARK: - Auth

struct AuthUser: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    let email: String?
    let phone: String?
    let createdAt: Int64

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "N" : letters.uppercased()
    }

    var handle: String {
        email ?? phone ?? "Nova member"
    }
}

struct RequestCodeResponse: Codable, Sendable {
    let ok: Bool
    let channel: String
    let expiresIn: Int
    let devCode: String?
}

struct Profile: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var avatarColor: String
    var isKids: Bool
    var hasPin: Bool
    let createdAt: Int64

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "N" : letters.uppercased()
    }
}

struct AuthResponse: Codable, Sendable {
    let token: String
    let account: AuthUser
    let profiles: [Profile]
    let isNewUser: Bool
}

struct SessionResponse: Codable, Sendable {
    let account: AuthUser
    let profiles: [Profile]
}

struct PlaybackProgress: Codable, Identifiable, Hashable, Sendable {
    let titleId: String
    let positionSeconds: Double
    let durationSeconds: Double
    let updatedAt: Int64

    var id: String { titleId }

    var fraction: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(max(positionSeconds / durationSeconds, 0), 1)
    }
}

struct OKResponse: Codable, Sendable {
    let ok: Bool
}

// MARK: - Widgets

struct WidgetContinueItem: Codable, Identifiable, Hashable, Sendable {
    let title: MediaTitle
    let positionSeconds: Double
    let durationSeconds: Double

    var id: String { title.id }

    var fraction: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(max(positionSeconds / durationSeconds, 0), 1)
    }
}

struct WidgetSnapshot: Codable, Sendable {
    var profileName: String?
    var featured: MediaTitle?
    var continueWatching: [WidgetContinueItem]
    var trending: [MediaTitle]
    var updatedAt: TimeInterval

    static let placeholder = WidgetSnapshot(
        profileName: "You",
        featured: MediaTitle(
            id: "night_of_the_living_dead",
            title: "Night of the Living Dead",
            year: 1968,
            overview: "A group of strangers barricade themselves in a farmhouse as the dead rise.",
            genres: ["Horror", "Classic"],
            runtimeMinutes: 96,
            posterURL: nil,
            backdropURL: nil,
            streamURL: nil,
            rating: 7.8,
            source: "Internet Archive",
            licenseURL: nil,
            tags: ["essential"]
        ),
        continueWatching: [],
        trending: [],
        updatedAt: 0
    )
}
