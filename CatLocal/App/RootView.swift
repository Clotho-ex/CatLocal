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
                presentCapture()
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
                        CollectionView(onCaptureRequested: presentCapture)
                    }
                }

                Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                    tabContent {
                        SettingsView()
                    }
                }

                Tab(value: AppTab.capture, role: .search) {
                    tabContent {
                        CollectionView(onCaptureRequested: presentCapture)
                    }
                } label: {
                    cameraTabLabel
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            .tint(CatLocalTheme.blueAction)
        } else {
            TabView(selection: tabSelection) {
                Tab("Collection", systemImage: "rectangle.stack", value: AppTab.collection) {
                    tabContent {
                        CollectionView(onCaptureRequested: presentCapture)
                    }
                }

                Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                    tabContent {
                        SettingsView()
                    }
                }

                Tab(value: AppTab.capture) {
                    tabContent {
                        CollectionView(onCaptureRequested: presentCapture)
                    }
                } label: {
                    cameraTabLabel
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            .tint(CatLocalTheme.blueAction)
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

    private func presentCapture() {
        selectedTab = lastContentTab
        presentedSheet = .capture
    }

    private var cameraTabLabel: some View {
        Label {
            Text("Camera")
        } icon: {
            Image("CameraTabIcon")
                .renderingMode(.original)
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
