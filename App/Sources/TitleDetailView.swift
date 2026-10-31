import SwiftUI

struct TitleDetailLoader: View {
    let id: String

    @State private var title: MediaTitle?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let title {
                TitleDetailView(title: title)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Can't load title",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("Loading…")
                    .tint(.white)
                    .task {
                        await load()
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.novaBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    @MainActor
    private func load() async {
        do {
            title = try await APIClient.shared.title(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct TitleDetailView: View {
    let title: MediaTitle

    @State private var progressFraction: Double = 0
    @State private var startAt: Double = 0
    @State private var isInList = false
    @State private var isBusy = false
    @State private var playerTitle: MediaTitle?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                HStack(spacing: 12) {
                    Button {
                        play()
                    } label: {
                        Label(
                            progressFraction > 0.02 && progressFraction < 0.95 ? "Resume" : "Play",
                            systemImage: "play.fill"
                        )
                    }
                    .buttonStyle(NovaPrimaryButtonStyle())
                    .disabled(title.streamURL == nil)

                    Button {
                        toggleList()
                    } label: {
                        Image(systemName: isInList ? "checkmark" : "plus")
                            .font(.headline)
                            .frame(width: 48, height: 48)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .foregroundStyle(.white)
                    .disabled(isBusy)
                    .accessibilityLabel(isInList ? "Remove from My List" : "Add to My List")
                }
                .padding(.horizontal, 20)

                if progressFraction > 0.02 && progressFraction < 0.95 {
                    VStack(alignment: .leading, spacing: 5) {
                        ProgressBar(fraction: progressFraction)
                        Text("\(Int(progressFraction * 100))% watched")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                }

                if title.streamURL == nil {
                    Text("No playable source is available for this title right now.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 20)
                }

                Text(title.overview)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(title.genres, id: \.self) { genre in
                            NovaChip(text: genre)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                VStack(spacing: 10) {
                    if let year = title.year {
                        infoRow("Year", String(year))
                    }
                    if let runtime = title.runtimeLabel {
                        infoRow("Runtime", runtime)
                    }
                    if let rating = title.rating {
                        infoRow("Rating", String(format: "%.1f / 10", rating))
                    }
                    infoRow("Source", title.source ?? "Internet Archive")

                    if let raw = title.licenseURL, let url = URL(string: raw) {
                        Link(destination: url) {
                            HStack {
                                Text("Source & license")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(Color.novaSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 20)

                Text("Nova streams this title from the Internet Archive. Nova does not host or upload media. Availability and public-domain status can vary by country.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
            }
        }
        .background(Color.novaBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.novaBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await loadState()
        }
        .fullScreenCover(item: $playerTitle, onDismiss: {
            Task { await loadState() }
        }) { item in
            PlayerScreen(title: item, startAt: startAt)
        }
    }

    private var header: some View {
        ZStack(alignment: .bottom) {
            AsyncPoster(urlString: title.backdropURL ?? title.posterURL)
                .frame(height: 330)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [.clear, Color.novaBackground],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }

            HStack(alignment: .bottom, spacing: 14) {
                AsyncPoster(urlString: title.posterURL)
                    .frame(width: 112, height: 168)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.6), radius: 12, y: 6)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title.title)
                        .font(.title2.weight(.bold))
                        .lineLimit(3)

                    HStack(spacing: 6) {
                        if let year = title.year {
                            Text(String(year))
                        }
                        if let runtime = title.runtimeLabel {
                            Text("•")
                            Text(runtime)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.white.opacity(0.9))
        }
        .font(.footnote)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.novaSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func play() {
        guard title.streamURL != nil else { return }
        if progressFraction > 0.95 {
            startAt = 0
        }
        playerTitle = title
    }

    @MainActor
    private func toggleList() {
        guard !isBusy else { return }
        let wasInList = isInList
        isInList.toggle()
        isBusy = true

        Task { @MainActor in
            do {
                if wasInList {
                    _ = try await APIClient.shared.removeFromWatchlist(id: title.id)
                } else {
                    _ = try await APIClient.shared.addToWatchlist(id: title.id)
                }
            } catch {
                isInList = wasInList
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    @MainActor
    private func loadState() async {
        async let progressTask = APIClient.shared.progress()
        async let watchlistTask = APIClient.shared.watchlist()

        do {
            let (items, list) = try await (progressTask, watchlistTask)

            if let item = items.first(where: { $0.titleId == title.id }), item.durationSeconds > 0 {
                progressFraction = item.fraction
                startAt = item.fraction > 0.95 ? 0 : item.positionSeconds
            }

            isInList = list.contains { $0.id == title.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
