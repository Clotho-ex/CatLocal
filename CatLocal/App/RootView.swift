import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .collection
    @State private var isCapturePresented = false

    var body: some View {
        ZStack(alignment: .bottom) {
            CatLocalTheme.limestone
                .ignoresSafeArea()

            Group {
                switch selectedTab {
                case .collection:
                    CollectionView()
                case .settings:
                    SettingsPlaceholderView()
                }
            }

            FloatingTabBar(
                selection: $selectedTab,
                captureAction: { isCapturePresented = true }
            )
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
        }
        .fullScreenCover(isPresented: $isCapturePresented) {
            CaptureView()
        }
    }
}

enum AppTab: Hashable {
    case collection
    case settings
}

private struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CatLocal")
                .font(.system(size: 52, weight: .medium, design: .serif))
                .foregroundStyle(CatLocalTheme.forest)

            Text("Settings")
                .font(.title2.weight(.semibold))

            Label("Your collection stays on this iPhone.", systemImage: "lock.shield")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 120)
    }
}

#Preview {
    RootView()
}
