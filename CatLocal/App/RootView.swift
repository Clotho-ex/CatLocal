import SwiftUI
import UIKit

struct RootView: View {
    @State private var selectedTab: AppTab = .home
    @State private var lastContentTab: AppTab = .home
    @State private var presentedSheet: AppSheet?
    @State private var homeReselectionID = 0

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

            if selectedTab == .home, newTab == .home {
                homeReselectionID += 1
            }

            playContentTabHaptic(from: selectedTab, to: newTab)
            selectedTab = newTab
            lastContentTab = newTab
        }
    }

    @ViewBuilder
    private var nativeTabs: some View {
        if #available(iOS 26.0, *) {
            TabView(selection: tabSelection) {
                Tab("Home", systemImage: "house", value: AppTab.home) {
                    tabContent {
                        CollectionView(
                            onCaptureRequested: presentCapture,
                            homeReselectionID: homeReselectionID,
                            selectedTab: selectedTab
                        )
                    }
                }

                Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                    tabContent {
                        SettingsView()
                    }
                }

                Tab(value: AppTab.capture, role: .search) {
                    tabContent {
                        CollectionView(
                            onCaptureRequested: presentCapture,
                            homeReselectionID: homeReselectionID,
                            selectedTab: selectedTab
                        )
                    }
                } label: {
                    Label("Camera", systemImage: "camera")
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            .tint(CatLocalTheme.blueAction)
        } else {
            TabView(selection: tabSelection) {
                Tab("Home", systemImage: "house", value: AppTab.home) {
                    tabContent {
                        CollectionView(
                            onCaptureRequested: presentCapture,
                            homeReselectionID: homeReselectionID,
                            selectedTab: selectedTab
                        )
                    }
                }

                Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                    tabContent {
                        SettingsView()
                    }
                }

                Tab(value: AppTab.capture) {
                    tabContent {
                        CollectionView(
                            onCaptureRequested: presentCapture,
                            homeReselectionID: homeReselectionID,
                            selectedTab: selectedTab
                        )
                    }
                } label: {
                    Label("Camera", systemImage: "camera")
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

    private func playContentTabHaptic(from oldTab: AppTab, to newTab: AppTab) {
        guard oldTab != newTab else { return }
        guard oldTab.isContentTab, newTab.isContentTab else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

}

enum AppTab: Hashable {
    case home
    case settings
    case capture

    var isContentTab: Bool {
        switch self {
        case .home, .settings:
            return true
        case .capture:
            return false
        }
    }
}

enum AppSheet: String, Identifiable {
    case capture

    var id: String { rawValue }
}
