import SwiftUI
import WidgetKit
import UIKit

private let novaRed = Color(red: 0.90, green: 0.04, blue: 0.08)

// MARK: - Bundle

@main
struct NovaWidgets: WidgetBundle {
    var body: some Widget {
        ContinueWatchingWidget()
        TrendingWidget()
    }
}

// MARK: - Timeline

struct NovaEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let featuredImage: Data?
    let continueImage: Data?
}

struct NovaProvider: TimelineProvider {
    func placeholder(in context: Context) -> NovaEntry {
        NovaEntry(date: Date(), snapshot: .placeholder, featuredImage: nil, continueImage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NovaEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }

        Task {
            completion(await loadEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NovaEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let next = Date().addingTimeInterval(30 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func loadEntry() async -> NovaEntry {
        var snapshot = SharedStore.loadIfAvailable() ?? WidgetPublicCache.load()

        if snapshot == nil || snapshot?.trending.isEmpty == true {
            if let remote = await fetchPublicCatalog() {
                snapshot = remote
                WidgetPublicCache.save(remote)
            }
        }

        let final = snapshot ?? .placeholder
        let featuredImage = await WidgetImageCache.data(for: final.featured)
        let continueImage = await WidgetImageCache.data(for: final.continueWatching.first?.title)

        return NovaEntry(
            date: Date(),
            snapshot: final,
            featuredImage: featuredImage,
            continueImage: continueImage
        )
    }

    private func fetchPublicCatalog() async -> WidgetSnapshot? {
        var url = ServerConfig.baseURL
        for component in "v1/catalog/public".split(separator: "/") {
            url.appendPathComponent(String(component))
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }

            let home = try JSONDecoder().decode(PublicHome.self, from: data)
            let trending = home.rows.first(where: { $0.id == "trending" })?.items
                ?? home.rows.first?.items
                ?? []

            return WidgetSnapshot(
                profileName: nil,
                featured: home.hero,
                continueWatching: [],
                trending: Array(trending.prefix(6)),
                updatedAt: Date().timeIntervalSince1970
            )
        } catch {
            return nil
        }
    }
}

private struct PublicHome: Decodable {
    let hero: MediaTitle?
    let rows: [CatalogRow]
}

private enum WidgetPublicCache {
    private static let key = "nova.widget.public.v1"

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

private enum WidgetImageCache {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("NovaWidgetImages", isDirectory: true)
    }

    private static func filename(for id: String) -> String {
        let safe = id.map { character -> Character in
            character.isLetter || character.isNumber ? character : "_"
        }
        return String(safe) + ".jpg"
    }

    static func data(for title: MediaTitle?) async -> Data? {
        guard let title else { return nil }

        let file = directory.appendingPathComponent(filename(for: title.id))
        if let cached = try? Data(contentsOf: file) {
            return cached
        }

        guard let raw = title.posterURL, let url = URL(string: raw) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  !data.isEmpty else { return nil }

            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
            return data
        } catch {
            return nil
        }
    }
}

// MARK: - Continue Watching

struct ContinueWatchingWidget: Widget {
    private let kind = "NovaContinue"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NovaProvider()) { entry in
            ContinueWatchingWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.black
                }
        }
        .configurationDisplayName("Continue Watching")
        .description("Resume a film from your Home Screen or Lock Screen.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular
        ])
    }
}

struct ContinueWatchingWidgetView: View {
    let entry: NovaEntry

    @Environment(\.widgetFamily) private var family

    private var item: WidgetContinueItem? {
        entry.snapshot.continueWatching.first
    }

    private var title: String {
        item?.title.title
            ?? entry.snapshot.featured?.title
            ?? entry.snapshot.trending.first?.title
            ?? "Nova"
    }

    private var fraction: Double {
        item?.fraction ?? 0
    }

    private var imageData: Data? {
        entry.continueImage ?? entry.featuredImage
    }

    private var deepLink: URL? {
        guard let id = item?.title.id ?? entry.snapshot.featured?.id ?? entry.snapshot.trending.first?.id else {
            return nil
        }
        return URL(string: "nova://title/\(id)")
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        case .accessoryRectangular:
            lockScreenRectangular
        case .accessoryInline:
            lockScreenInline
        case .accessoryCircular:
            lockScreenCircular
        default:
            smallView
        }
    }

    private var smallView: some View {
        ZStack(alignment: .bottomLeading) {
            poster(imageData, width: 170, height: 170)

            LinearGradient(
                colors: [.clear, .black.opacity(0.92)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("CONTINUE WATCHING")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.72))

                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(2)

                ProgressView(value: fraction)
                    .tint(novaRed)
            }
            .padding(10)
        }
        .widgetURL(deepLink)
    }

    private var mediumView: some View {
        HStack(spacing: 12) {
            poster(imageData, width: 82, height: 123)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("CONTINUE WATCHING")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.6))

                Text(title)
                    .font(.headline)
                    .lineLimit(2)

                Spacer(minLength: 0)

                ProgressView(value: fraction)
                    .tint(novaRed)

                Text(remainingLabel)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))

                Label("Tap to resume", systemImage: "play.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer(minLength: 0)
        }
        .widgetURL(deepLink)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 0) {
                    Text("N").foregroundStyle(novaRed)
                    Text("OVA").foregroundStyle(.white)
                }
                .font(.system(size: 18, weight: .black, design: .rounded))

                Spacer()

                Text(entry.snapshot.profileName.map { "Continue · \($0)" } ?? "Continue Watching")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            HStack(alignment: .top, spacing: 14) {
                poster(imageData, width: 104, height: 156)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .lineLimit(2)

                    if let year = item?.title.year ?? entry.snapshot.featured?.year {
                        Text(String(year))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    ProgressView(value: fraction)
                        .tint(novaRed)
                        .padding(.top, 2)

                    Text(remainingLabel)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))

                    Spacer(minLength: 0)

                    Label("Resume", systemImage: "play.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(novaRed)
                        .clipShape(Capsule())
                }
            }

            Divider()
                .overlay(.white.opacity(0.12))

            Text("TRENDING NOW")
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.5))

            ForEach(Array(entry.snapshot.trending.prefix(3))) { trending in
                HStack(spacing: 8) {
                    Text(trending.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)

                    Spacer()

                    if let year = trending.year {
                        Text(String(year))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .widgetURL(deepLink)
    }

    private var lockScreenRectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("CONTINUE WATCHING")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)
                .lineLimit(1)

            ProgressView(value: fraction)
                .tint(novaRed)
        }
        .widgetURL(deepLink)
    }

    private var lockScreenInline: some View {
        Text("Continue \(title)")
            .widgetURL(deepLink)
    }

    private var lockScreenCircular: some View {
        Gauge(value: fraction) {
            Image(systemName: "play.fill")
        } currentValueLabel: {
            Text("\(Int(fraction * 100))%")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetURL(deepLink)
    }

    private var remainingLabel: String {
        guard let item else { return "Start watching" }
        let remaining = max(0, item.durationSeconds - item.positionSeconds)
        if remaining < 60 {
            return "Almost finished"
        }
        return "\(Int(remaining / 60)) min left"
    }

    @ViewBuilder
    private func poster(_ data: Data?, width: CGFloat, height: CGFloat) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color(white: 0.18), Color(white: 0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(width: width, height: height)
        }
    }
}

// MARK: - Trending

struct TrendingWidget: Widget {
    private let kind = "NovaTrending"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NovaProvider()) { entry in
            TrendingWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.black
                }
        }
        .configurationDisplayName("Trending on Nova")
        .description("A rotating look at what's playing on Nova.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TrendingWidgetView: View {
    let entry: NovaEntry

    @Environment(\.widgetFamily) private var family

    private var titles: [MediaTitle] {
        if entry.snapshot.trending.isEmpty {
            return entry.snapshot.featured.map { [$0] } ?? []
        }
        return Array(entry.snapshot.trending.prefix(4))
    }

    private var featured: MediaTitle? {
        entry.snapshot.featured ?? titles.first
    }

    private var deepLink: URL? {
        guard let id = featured?.id else { return nil }
        return URL(string: "nova://title/\(id)")
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            largeView
        }
    }

    private var smallView: some View {
        ZStack(alignment: .bottomLeading) {
            poster(entry.featuredImage, width: 170, height: 170)

            LinearGradient(
                colors: [.clear, .black.opacity(0.92)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("TRENDING ON NOVA")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.65))

                Text(featured?.title ?? "Nova")
                    .font(.caption.weight(.bold))
                    .lineLimit(2)
            }
            .padding(10)
        }
        .widgetURL(deepLink)
    }

    private var mediumView: some View {
        HStack(spacing: 12) {
            poster(entry.featuredImage, width: 82, height: 123)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("TRENDING ON NOVA")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.55))

                Text(featured?.title ?? "Nova")
                    .font(.headline)
                    .lineLimit(2)

                Spacer(minLength: 0)

                ForEach(Array(titles.dropFirst().prefix(2))) { title in
                    Text(title.title)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .widgetURL(deepLink)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 0) {
                    Text("N").foregroundStyle(novaRed)
                    Text("OVA").foregroundStyle(.white)
                }
                .font(.system(size: 18, weight: .black, design: .rounded))

                Spacer()

                Text(entry.snapshot.profileName.map { "For \($0)" } ?? "Trending Now")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            HStack(alignment: .top, spacing: 14) {
                poster(entry.featuredImage, width: 112, height: 168)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(featured?.title ?? "Nova")
                        .font(.title3.weight(.bold))
                        .lineLimit(2)

                    if let year = featured?.year {
                        Text(String(year))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    if let overview = featured?.overview {
                        Text(overview)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(4)
                    }

                    Spacer(minLength: 0)

                    Label("Watch free", systemImage: "play.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(novaRed)
                        .clipShape(Capsule())
                }
            }

            Divider()
                .overlay(.white.opacity(0.12))

            ForEach(Array(titles.dropFirst().prefix(3))) { title in
                HStack(spacing: 8) {
                    Text(title.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)

                    Spacer()

                    if let year = title.year {
                        Text(String(year))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .widgetURL(deepLink)
    }

    @ViewBuilder
    private func poster(_ data: Data?, width: CGFloat, height: CGFloat) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color(white: 0.18), Color(white: 0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(width: width, height: height)
        }
    }
}
