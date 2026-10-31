import SwiftUI

struct MyListView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(AppRouter.self) private var router

    @State private var items: [MediaTitle] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.listPath) {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Can't load your list",
                        systemImage: "wifi.exclamationmark",
                        description: Text(errorMessage)
                    )
                    .padding(.top, 60)
                } else if items.isEmpty {
                    ContentUnavailableView(
                        "Your list is empty",
                        systemImage: "bookmark",
                        description: Text("Tap + on any title to save it here.")
                    )
                    .padding(.top, 60)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 108), spacing: 12)],
                        spacing: 18
                    ) {
                        ForEach(items) { title in
                            NavigationLink(value: Route.title(title.id)) {
                                GridPosterCard(title: title)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await remove(title) }
                                } label: {
                                    Label("Remove from My List", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .background(Color.novaBackground.ignoresSafeArea())
            .navigationTitle("My List")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .title(let id):
                    TitleDetailLoader(id: id)
                }
            }
            .task(id: auth.selectedProfile?.id) {
                await load()
            }
            .refreshable {
                await load()
            }
        }
    }

    @MainActor
    private func load() async {
        errorMessage = nil
        do {
            items = try await APIClient.shared.watchlist()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func remove(_ title: MediaTitle) async {
        do {
            _ = try await APIClient.shared.removeFromWatchlist(id: title.id)
            items.removeAll { $0.id == title.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
