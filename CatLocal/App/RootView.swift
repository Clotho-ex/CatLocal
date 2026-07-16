import SwiftUI

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(CatLocalUserDefaults.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @AppStorage(CatLocalUserDefaults.appearanceKey) private var appearance = CatLocalAppearance.system
    @AppStorage(CatLocalUserDefaults.cardMotionEnabledKey) private var cardMotionEnabled = true
    @AppStorage(CatLocalUserDefaults.hapticsEnabledKey) private var hapticsEnabled = true
    @State private var tabState: AppTabPresentationState
    @State private var homeReselectionID = 0
    @State private var contentTabFeedbackTrigger = 0

    init() {
        let initialTab: AppTab = CommandLine.arguments.contains("-ui-testing-open-settings") ? .settings : .home
        _tabState = State(initialValue: AppTabPresentationState(initialTab: initialTab))
    }

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                appShell
                    .transition(.opacity.combined(with: .scale(scale: 0.99)))
            } else {
                OnboardingView(onComplete: completeOnboarding)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.24, extraBounce: 0), value: hasCompletedOnboarding)
        .environment(\.catLocalCardMotionEnabled, cardMotionEnabled)
        .environment(\.catLocalHapticsEnabled, hapticsEnabled)
        .preferredColorScheme(appearance.preferredColorScheme)
    }

    private var appShell: some View {
        nativeTabs
            .catSensoryFeedback(.selection, trigger: contentTabFeedbackTrigger)
            .fullScreenCover(item: $tabState.presentedSheet, onDismiss: restoreContentTabSelection) { sheet in
                switch sheet {
                case .capture:
                    CaptureView()
                }
            }
    }

    private var tabSelection: Binding<AppTab> {
        Binding {
            tabState.selectedTab
        } set: { newTab in
            guard newTab != .capture else {
                presentCapture()
                return
            }

            if tabState.selectedTab == .home, newTab == .home {
                homeReselectionID += 1
            }

            playContentTabHaptic(from: tabState.selectedTab, to: newTab)
            tabState.selectContentTab(newTab)
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
                            selectedTab: tabState.selectedTab
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
                            selectedTab: tabState.selectedTab
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
                            selectedTab: tabState.selectedTab
                        )
                    }
                }

                Tab(value: AppTab.capture) {
                    tabContent {
                        CollectionView(
                            onCaptureRequested: presentCapture,
                            homeReselectionID: homeReselectionID,
                            selectedTab: tabState.selectedTab
                        )
                    }
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .accessibilityHint("Opens the camera and private photo import.")
                }

                Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                    tabContent {
                        SettingsView()
                    }
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            .tint(CatLocalTheme.blueAction)
            .toolbarBackground(.regularMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
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
        guard tabState.presentCapture() else { return }
    }

    private func restoreContentTabSelection() {
        tabState.restoreContentTabSelection()
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    private func playContentTabHaptic(from oldTab: AppTab, to newTab: AppTab) {
        guard oldTab != newTab else { return }
        guard oldTab.isContentTab, newTab.isContentTab else { return }
        contentTabFeedbackTrigger += 1
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

struct AppTabPresentationState: Equatable {
    var selectedTab: AppTab
    var lastContentTab: AppTab
    var presentedSheet: AppSheet?

    init(initialTab: AppTab) {
        selectedTab = initialTab
        lastContentTab = initialTab.isContentTab ? initialTab : .home
        presentedSheet = nil
    }

    mutating func selectContentTab(_ tab: AppTab) {
        guard tab.isContentTab else { return }
        selectedTab = tab
        lastContentTab = tab
    }

    @discardableResult
    mutating func presentCapture() -> Bool {
        guard presentedSheet == nil else { return false }
        selectedTab = .capture
        presentedSheet = .capture
        return true
    }

    @discardableResult
    mutating func restoreContentTabSelection() -> AppTab {
        presentedSheet = nil
        selectedTab = lastContentTab
        return lastContentTab
    }
}

enum AppSheet: String, Identifiable, Equatable {
    case capture

    var id: String { rawValue }
}
