import SwiftUI

/// Applies native Liquid Glass on macOS 26+ (Tahoe / Golden Gate) and clean native
/// system materials on macOS 15 (Sequoia), avoiding fake blur effects.
struct AdaptiveCapsuleSurface: ViewModifier {
    var interactive: Bool = false

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(
                    interactive ? .regular.interactive() : .regular,
                    in: .capsule
                )
        } else {
            content
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
                )
        }
    }
}

struct AdaptiveCardSurface: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
                )
        }
    }
}

struct AdaptiveGlassContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer {
                content()
            }
        } else {
            content()
        }
    }
}

extension View {
    func adaptiveCapsuleSurface(interactive: Bool = false) -> some View {
        modifier(AdaptiveCapsuleSurface(interactive: interactive))
    }

    func adaptiveCardSurface(cornerRadius: CGFloat = 12) -> some View {
        modifier(AdaptiveCardSurface(cornerRadius: cornerRadius))
    }
}
