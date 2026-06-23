import SwiftUI

struct FloatingTabBar: View {
    @Binding var selection: AppTab
    let captureAction: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 14) {
                barContent
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
        } else {
            barContent
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.55), lineWidth: 1)
                }
        }
    }

    private var barContent: some View {
        HStack {
            tabButton(
                tab: .collection,
                symbol: "rectangle.stack.fill",
                label: "Collection"
            )

            Spacer()

            Button(action: captureAction) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(CatLocalTheme.forest)
                    .frame(width: 66, height: 66)
            }
            .accessibilityLabel("Photograph a cat")
            .background {
                Circle()
                    .fill(.thinMaterial)
                    .overlay {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [CatLocalTheme.cobalt, CatLocalTheme.apricot, .white],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                    .shadow(color: CatLocalTheme.ink.opacity(0.14), radius: 12, y: 5)
            }

            Spacer()

            tabButton(
                tab: .settings,
                symbol: "gearshape.fill",
                label: "Settings"
            )
        }
        .frame(height: 62)
    }

    private func tabButton(tab: AppTab, symbol: String, label: String) -> some View {
        Button {
            selection = tab
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(selection == tab ? CatLocalTheme.forest : .secondary)
                .frame(width: 54, height: 54)
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }
}

