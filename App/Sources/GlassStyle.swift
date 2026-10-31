import SwiftUI

/// Liquid Glass on iOS 26+, with a material fallback on earlier releases.
/// The compiler guard keeps the project buildable with Xcode 16 while letting
/// Xcode 26+ pick up the native glass effect automatically.
extension View {
    @ViewBuilder
    func novaGlass(cornerRadius: CGFloat = 20) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            self.novaLegacyGlass(cornerRadius: cornerRadius)
        }
        #else
        self.novaLegacyGlass(cornerRadius: cornerRadius)
        #endif
    }

    func novaLegacyGlass(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
    }
}
