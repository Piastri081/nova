import SwiftUI
import Foundation

extension Color {
    static let novaBackground = Color(red: 0.035, green: 0.035, blue: 0.045)
    static let novaSurface = Color(red: 0.10, green: 0.10, blue: 0.115)
    static let novaRed = Color(red: 0.90, green: 0.04, blue: 0.08)

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: UInt64
        let green: UInt64
        let blue: UInt64

        switch cleaned.count {
        case 3:
            red = ((value >> 8) & 0xF) * 17
            green = ((value >> 4) & 0xF) * 17
            blue = (value & 0xF) * 17
        default:
            red = (value >> 16) & 0xFF
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: 1
        )
    }
}

struct NovaLogo: View {
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 0) {
            Text("N")
                .foregroundStyle(Color.novaRed)
                .tracking(size * 0.06)
            Text("OVA")
                .foregroundStyle(.white)
                .tracking(size * 0.06)
        }
        .font(.system(size: size, weight: .black, design: .rounded))
        .accessibilityLabel("Nova")
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 20)
    }
}

struct NovaChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.novaSurface)
            .clipShape(Capsule())
    }
}

struct NovaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .padding(.horizontal, 18)
            .background(Color.novaRed)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

struct NovaSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .padding(.horizontal, 18)
            .background(.white.opacity(configuration.isPressed ? 0.22 : 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ProfileAvatar: View {
    let profile: Profile
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: profile.avatarColor),
                            Color(hex: profile.avatarColor).opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(profile.initials)
                .font(.system(size: size * 0.34, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            if profile.hasPin {
                Image(systemName: "lock.fill")
                    .font(.system(size: max(8, size * 0.1), weight: .bold))
                    .foregroundStyle(.white)
                    .padding(max(4, size * 0.06))
                    .background(.black.opacity(0.55))
                    .clipShape(Circle())
                    .padding(max(4, size * 0.05))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if profile.isKids {
                Text("KIDS")
                    .font(.system(size: max(7, size * 0.09), weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, max(4, size * 0.06))
                    .padding(.vertical, max(2, size * 0.025))
                    .background(.black.opacity(0.62))
                    .clipShape(Capsule())
                    .padding(max(4, size * 0.05))
            }
        }
    }
}
