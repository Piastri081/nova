import Foundation
import Observation

enum AppTab: Hashable {
    case home
    case search
    case list
    case profile
}

enum Route: Hashable {
    case title(String)
}

@Observable
@MainActor
final class AppRouter {
    var selectedTab: AppTab = .home
    var homePath: [Route] = []
    var searchPath: [Route] = []
    var listPath: [Route] = []

    func open(_ url: URL) {
        guard url.scheme?.lowercased() == "nova" else { return }

        if url.host?.lowercased() == "title" {
            guard let raw = url.pathComponents.dropFirst().first, !raw.isEmpty else { return }
            let id = raw.removingPercentEncoding ?? raw
            selectedTab = .home
            homePath.append(.title(id))
        }
    }
}
