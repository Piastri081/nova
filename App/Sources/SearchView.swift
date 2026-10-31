import SwiftUI

struct SearchView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(AppRouter.self) private var router

    @State private var query = ""
    @State private var results: [MediaTitle] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let suggestions = ["Horror", "Film Noir", "Comedy", "Sci-Fi", "Silent Era", "Drama", "Adventure", "Family"]

    private var searchKey: String {
        "\(auth.selectedProfile?.id ?? "none")|\(query)"
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.searchPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        browseView
                    } else if isSearching && results.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                    } else if let errorMessage {
                        ContentUnavailableView(
                            "Search failed",
                            systemImage: "exclamationmark.magnifyingglass",
                            description: Text(errorMessage)
                        )
                        .padding(.top, 60)
                    } else if results.isEmpty {
                        ContentUnavailableView(
                            "No matches",
                            systemImage: "magnifyingglass",
                            description: Text("Try a title, genre, or year.")
                        )
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 108), spacing: 12)],
                            spacing: 18
                        ) {
                            ForEach(results) { title in
                                NavigationLink(value: Route.title(title.id)) {
                                    GridPosterCard(title: title)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color.novaBackground.ignoresSafeArea())
            .navigationTitle("Search")
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Titles, genres, years"
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .title(let id):
                    TitleDetailLoader(id: id)
                }
            }
            .task(id: searchKey) {
                await search()
            }
        }
    }

    private var browseView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Browse by mood")
                .font(.title3.weight(.bold))
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            query = suggestion
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.novaSurface)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("The whole catalog is free")
                    .font(.headline)
                Text("Nova indexes public-domain and Creative Commons films from the Internet Archive. No subscription, no ads, no paywall.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(Color.novaSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }

    @MainActor
    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            errorMessage = nil
            return
        }

        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }

        isSearching = true
        errorMessage = nil

        do {
            let matches = try await APIClient.shared.search(trimmed)
            guard !Task.isCancelled else { return }
            results = matches
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }
}
