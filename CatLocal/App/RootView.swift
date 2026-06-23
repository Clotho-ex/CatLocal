import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .collection
    @State private var presentedSheet: AppSheet?

    var body: some View {
        ZStack(alignment: .bottom) {
            CatLocalBackground()

            Group {
                switch selectedTab {
                case .collection:
                    CollectionView()
                case .settings:
                    SettingsView()
                }
            }

            FloatingTabBar(
                selection: $selectedTab,
                captureAction: { presentedSheet = .capture }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .fullScreenCover(item: $presentedSheet) { sheet in
            switch sheet {
            case .capture:
                CaptureView()
            }
        }
    }
}

enum AppTab: Hashable {
    case collection
    case settings
}

enum AppSheet: String, Identifiable {
    case capture

    var id: String { rawValue }
}
