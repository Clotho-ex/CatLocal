import SwiftUI

struct FloatingTabBar: View {
    @Binding var selection: AppTab
    let captureAction: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    content
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .glassEffect(
                            .regular.tint(.white.opacity(0.06)).interactive(),
                            in: .capsule
                        )
                }
            } else {
                content
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.65), lineWidth: 1))
                    .shadow(color: CatLocalTheme.ink.opacity(0.13), radius: 22, y: 10)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var content: some View {
        HStack(spacing: 8) {
            tabButton(
                tab: .collection,
                symbol: "rectangle.stack.fill",
                label: "Collection"
            )

            Spacer(minLength: 8)

            Button(action: captureAction) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(CatLocalTheme.forest)
                    .frame(width: 68, height: 68)
                    .background(
                        Circle()
                            .fill(.thinMaterial)
                            .overlay(
                                Circle().stroke(
                                    LinearGradient(
                                        colors: [
                                            CatLocalTheme.cobalt,
                                            .white.opacity(0.8),
                                            CatLocalTheme.apricot
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                            )
                            .shadow(color: CatLocalTheme.ink.opacity(0.16), radius: 12, y: 6)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Photograph or import a cat")
            .accessibilityHint("Opens the private card creator")

            Spacer(minLength: 8)

            tabButton(
                tab: .settings,
                symbol: "gearshape.fill",
                label: "Settings"
            )
        }
        .frame(height: 64)
    }

    private func tabButton(tab: AppTab, symbol: String, label: String) -> some View {
        Button {
            selection = tab
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(selection == tab ? CatLocalTheme.forest : .secondary)
                .frame(width: 56, height: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }
}
