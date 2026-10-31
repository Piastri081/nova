import SwiftUI

struct HomeView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(AppRouter.self) private var router

    @State private var payload: HomePayload?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var playerTitle: MediaTitle?
    @State private var playerStart: Double = 0
    @State private var showProfiles = false

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.homePath) {
            ZStack {
                Color.novaBackground.ignoresSafeArea()

                if let payload {
                    homeContent(payload)
                } else if isLoading {
                    ProgressView("Loading Nova…")
                        .tint(.white)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Can't load the catalog", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") {
                            Task { await load() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.novaRed)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .title(let id):
                    TitleDetailLoader(id: id)
                }
            }
            .overlay(alignment: .top) {
                HStack(spacing: 12) {
                    NovaLogo(size: 24)
                        .shadow(color: .black.opacity(0.7), radius: 8)
                        .allowsHitTesting(false)

                    Spacer()

                    if let profile = auth.selectedProfile {
                        Button {
                            showProfiles = true
                        } label: {
                            ProfileAvatar(profile: profile, size: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Switch profile")
                        .shadow(color: .black.opacity(0.45), radius: 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
            }
        }
        .task(id: auth.selectedProfile?.id) {
            payload = nil
            await load()
        }
        .fullScreenCover(item: $playerTitle, onDismiss: {
            Task { await load(silent: true) }
        }) { title in
            PlayerScreen(title: title, startAt: playerStart)
        }
        .sheet(isPresented: $showProfiles) {
            ProfileSwitcherView()
        }
    }

    @ViewBuilder
    private func homeContent(_ payload: HomePayload) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if let hero = payload.hero {
                    HeroHeader(
                        title: hero,
                        onPlay: { play(hero) },
                        onInfo: { router.homePath.append(.title(hero.id)) }
                    )
                }

                let resumable = payload.continueWatching.filter {
                    $0.fraction > 0.01 && $0.fraction < 0.98
                }

                if !resumable.isEmpty {
                    ContinueWatchingRow(items: resumable) { item in
                        play(item.title, startAt: item.positionSeconds)
                    }
                }

                ForEach(payload.rows) { row in
                    CatalogRowView(row: row)
                }
            }
            .padding(.bottom, 28)
        }
        .ignoresSafeArea(edges: .top)
        .refreshable {
            await load(silent: true)
        }
    }

    private func play(_ title: MediaTitle, startAt: Double = 0) {
        guard title.streamURL != nil else { return }
        playerStart = startAt
        playerTitle = title
    }

    @MainActor
    private func load(silent: Bool = false) async {
        if !silent {
            isLoading = true
        }
        errorMessage = nil

        do {
            let home = try await APIClient.shared.home()
            payload = home
            updateWidgetSnapshot(home)
        } catch {
            if payload == nil {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func updateWidgetSnapshot(_ home: HomePayload) {
        let continueItems = home.continueWatching.map {
            WidgetContinueItem(
                title: $0.title,
                positionSeconds: $0.positionSeconds,
                durationSeconds: $0.durationSeconds
            )
        }

        let trending = home.rows.first(where: { $0.id == "trending" })?.items
            ?? home.rows.first?.items
            ?? []

        let snapshot = WidgetSnapshot(
            profileName: auth.selectedProfile?.name,
            featured: home.hero,
            continueWatching: continueItems,
            trending: Array(trending.prefix(6)),
            updatedAt: Date().timeIntervalSince1970
        )
        SharedStore.save(snapshot)

        var posters = home.hero.map { [$0] } ?? []
        posters.append(contentsOf: trending.prefix(8))
        Task {
            await PosterCache.cacheAll(posters)
            SharedStore.reloadWidgets()
        }
    }
}
