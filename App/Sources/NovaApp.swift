import SwiftUI
import UIKit

@main
struct NovaApp: App {
    @State private var auth = AuthStore()
    @State private var router = AppRouter()

    init() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(red: 0.035, green: 0.035, blue: 0.045, alpha: 1)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UINavigationBar.appearance().tintColor = .white
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(router)
                .preferredColorScheme(.dark)
                .tint(.novaRed)
        }
    }
}
