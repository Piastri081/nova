import Foundation
import UIKit

enum PosterCache {
    private static var directory: URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedStore.appGroupID
        ) else { return nil }

        let directory = container.appendingPathComponent("Posters", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private static func filename(for id: String) -> String {
        let safe = id.map { character -> Character in
            character.isLetter || character.isNumber ? character : "_"
        }
        return String(safe) + ".jpg"
    }

    static func image(for id: String) -> UIImage? {
        guard let url = directory?.appendingPathComponent(filename(for: id)),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func store(_ data: Data, for id: String) {
        guard let url = directory?.appendingPathComponent(filename(for: id)) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func cache(_ title: MediaTitle) async {
        guard image(for: title.id) == nil,
              let raw = title.posterURL,
              let url = URL(string: raw) else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  !data.isEmpty else { return }
            store(data, for: title.id)
        } catch {
            // Posters are a progressive enhancement. Failure is non-fatal.
        }
    }

    static func cacheAll(_ titles: [MediaTitle]) async {
        for title in titles {
            await cache(title)
        }
    }
}
