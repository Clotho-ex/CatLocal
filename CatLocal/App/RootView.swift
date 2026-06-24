import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .collection
    @State private var lastContentTab: AppTab = .collection
    @State private var presentedSheet: AppSheet?

    var body: some View {
        nativeTabs
        .fullScreenCover(item: $presentedSheet) { sheet in
            switch sheet {
            case .capture:
                CaptureView()
            }
        }
    }

    private var tabSelection: Binding<AppTab> {
        Binding {
            selectedTab
        } set: { newTab in
            guard newTab != .capture else {
                selectedTab = lastContentTab
                presentedSheet = .capture
                return
            }

            selectedTab = newTab
            lastContentTab = newTab
        }
    }

    @ViewBuilder
    private var nativeTabs: some View {
        if #available(iOS 26.0, *) {
            TabView(selection: tabSelection) {
                Tab("Collection", systemImage: "rectangle.stack", value: AppTab.collection) {
                    tabContent {
                        CollectionView()
                    }
                }

                Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                    tabContent {
                        SettingsView()
                    }
                }

                Tab("Camera", systemImage: "camera", value: AppTab.capture, role: .search) {
                    tabContent {
                        CollectionView()
                    }
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        } else {
            TabView(selection: tabSelection) {
                Tab("Collection", systemImage: "rectangle.stack", value: AppTab.collection) {
                    tabContent {
                        CollectionView()
                    }
                }

                Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                    tabContent {
                        SettingsView()
                    }
                }

                Tab("Camera", systemImage: "camera", value: AppTab.capture) {
                    tabContent {
                        CollectionView()
                    }
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        }
    }

    private func tabContent<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            CatLocalBackground()
            content()
        }
    }
}

enum AppTab: Hashable {
    case collection
    case settings
    case capture
}

enum AppSheet: String, Identifiable {
    case capture

    var id: String { rawValue }
}
