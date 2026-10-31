import Foundation
import WidgetKit

enum SharedStore {
    static let appGroupID = "group.com.example.nova"
    private static let snapshotKey = "nova.widget.snapshot.v1"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func loadIfAvailable() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    static func load() -> WidgetSnapshot {
        loadIfAvailable() ?? .placeholder
    }

    static func clear() {
        defaults?.removeObject(forKey: snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

enum ProfileContext {
    private static let key = "nova.currentProfileID"

    static var currentID: String? {
        SharedStore.defaults?.string(forKey: key)
            ?? UserDefaults.standard.string(forKey: key)
    }

    static func set(_ id: String?) {
        if let id {
            UserDefaults.standard.set(id, forKey: key)
            SharedStore.defaults?.set(id, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
            SharedStore.defaults?.removeObject(forKey: key)
        }
    }
}

enum ServerConfig {
    static let defaultsKey = "nova.api.baseURL"
    static let fallback = URL(string: "https://nova-api.example.workers.dev")!

    static var baseURL: URL {
        let candidates: [String?] = [
            SharedStore.defaults?.string(forKey: defaultsKey),
            UserDefaults.standard.string(forKey: defaultsKey),
            Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        ]

        for case let raw? in candidates {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
               scheme == "https" || scheme == "http", url.host != nil {
                return url
            }
        }
        return fallback
    }

    static var isPlaceholder: Bool {
        baseURL.host?.contains("example.workers.dev") == true
    }

    @discardableResult
    static func set(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host != nil else {
            return false
        }
        UserDefaults.standard.set(trimmed, forKey: defaultsKey)
        SharedStore.defaults?.set(trimmed, forKey: defaultsKey)
        return true
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        SharedStore.defaults?.removeObject(forKey: defaultsKey)
    }
}
