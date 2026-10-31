import SwiftUI

struct AsyncPoster: View {
    let urlString: String?

    var body: some View {
        AsyncImage(url: urlString.flatMap { URL(string: $0) }) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                placeholder
            case .empty:
                placeholder
                    .overlay {
                        ProgressView()
                            .tint(.white.opacity(0.5))
                    }
            @unknown default:
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.18), Color(white: 0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "film")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.25))
        }
    }
}

struct PosterCard: View {
    let title: MediaTitle
    var width: CGFloat = 118

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncPoster(urlString: title.posterURL)
                .frame(width: width, height: width * 1.5)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }

            Text(title.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .frame(width: width, alignment: .leading)

            if let year = title.year {
                Text(String(year))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: width, alignment: .leading)
            }
        }
    }
}

struct GridPosterCard: View {
    let title: MediaTitle

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay {
                    AsyncPoster(urlString: title.posterURL)
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }

            Text(title.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)

            if let year = title.year {
                Text(String(year))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.25))
                Capsule()
                    .fill(Color.novaRed)
                    .frame(width: max(3, geometry.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 3)
    }
}

struct HeroHeader: View {
    let title: MediaTitle
    let onPlay: () -> Void
    let onInfo: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            AsyncPoster(urlString: title.backdropURL ?? title.posterURL)
                .frame(height: 560)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [
                            .black.opacity(0.15),
                            .black.opacity(0.35),
                            Color.novaBackground
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [.black.opacity(0.75), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 150)
                }

            VStack(spacing: 16) {
                Text(title.title)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.6), radius: 12)

                HStack(spacing: 8) {
                    if let year = title.year {
                        Text(String(year))
                    }
                    if title.year != nil {
                        Text("•")
                    }
                    if let runtime = title.runtimeLabel {
                        Text(runtime)
                    }
                    if title.runtimeLabel != nil {
                        Text("•")
                    }
                    if let rating = title.rating {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

                HStack(spacing: 12) {
                    Button(action: onPlay) {
                        Label("Play", systemImage: "play.fill")
                    }
                    .buttonStyle(NovaPrimaryButtonStyle())
                    .disabled(title.streamURL == nil)

                    Button(action: onInfo) {
                        Label("More Info", systemImage: "info.circle")
                    }
                    .buttonStyle(NovaSecondaryButtonStyle())
                }
                .padding(.horizontal, 24)

                Text(title.overview)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 18)
        }
    }
}

struct ContinueWatchingRow: View {
    let items: [ContinueWatchingItem]
    let onPlay: (ContinueWatchingItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Continue Watching")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        Button {
                            onPlay(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                AsyncPoster(urlString: item.title.posterURL)
                                    .frame(width: 220, height: 124)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(alignment: .bottom) {
                                        ProgressBar(fraction: item.fraction)
                                            .padding(8)
                                    }
                                    .overlay {
                                        Image(systemName: "play.circle.fill")
                                            .font(.largeTitle)
                                            .foregroundStyle(.white.opacity(0.92))
                                            .shadow(color: .black.opacity(0.5), radius: 5)
                                    }

                                Text(item.title.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineLimit(1)
                                    .frame(width: 220, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct CatalogRowView: View {
    let row: CatalogRow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: row.title)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(row.items) { title in
                        NavigationLink(value: Route.title(title.id)) {
                            PosterCard(title: title)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
