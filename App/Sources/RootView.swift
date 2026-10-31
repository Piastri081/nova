import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(AppRouter.self) private var router

    var body: some View {
        ZStack {
            Color.novaBackground.ignoresSafeArea()

            switch auth.stage {
            case .loading:
                SplashView()
            case .signedOut:
                SignInView()
            case .codeSent:
                SignInView()
            case .choosingProfile:
                ProfilePickerView()
            case .signedIn:
                MainTabView()
            }
        }
        .onOpenURL { url in
            router.open(url)
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.novaBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                NovaLogo(size: 46)
                ProgressView()
                    .tint(.white.opacity(0.55))
            }
        }
    }
}
