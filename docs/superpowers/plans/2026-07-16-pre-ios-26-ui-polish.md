# Pre-iOS 26 UI Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give iOS 18 through iOS 25 a coherent native-material interface with accessibility-aware legacy surfaces, stable capture presentation, and system-managed navigation while leaving iOS 26 Liquid Glass unchanged.

**Architecture:** Keep compatibility behavior in `CatLocalTheme.swift` through a small semantic legacy-surface role and a pure metrics resolver. Keep persistent tab selection and transient capture presentation in a testable value type owned by `RootView`; screen files only select the appropriate shared surface role or remove a legacy-specific override.

**Tech Stack:** Swift 6, SwiftUI `Tab`, SwiftData, Swift Testing, XCTest UI testing, XcodeBuildMCP, iOS 18 minimum deployment target.

## Global Constraints

- iOS 18 through iOS 25 use native materials; do not imitate Liquid Glass.
- iOS 26 `glassEffect`, search-role Camera tab, layout, and behavior remain unchanged.
- Preserve all capture, Vision, storage, persistence, privacy, card artwork, foil, tilt, and editor behavior.
- Use `CatLocalTheme` semantic colors and `CatTypography`; add no raw screen-local colors.
- Every interactive control retains at least a 44 by 44 point hit area.
- Respect Reduce Motion, Reduce Transparency, Increase Contrast, and Differentiate Without Color Alone.
- Preserve the existing untracked `AppStore/` and `FIX_DUST_REVEAL_AND_COMPLETE_CARD_TRANSITION.md` files.
- Stage only files named by the current task; never use `git add -A`.

---

## File Map

- Modify `CatLocal/App/RootView.swift`: testable persistent-tab/transient-capture state, legacy tab-bar material, and legacy VoiceOver focus restoration.
- Modify `CatLocal/Shared/DesignSystem/CatLocalTheme.swift`: legacy semantic surface roles, accessibility-aware metrics, material resolution, and shared action surfaces.
- Modify `CatLocal/Features/Collection/CollectionView.swift`: assign grouped-action role to the selection bar.
- Modify `CatLocal/Features/Settings/SettingsView.swift`: preserve the hidden navigation background on iOS 26 while returning pre-iOS 26 to system-managed navigation material.
- Modify `CatLocal/Features/Capture/CaptureView.swift`: assign camera-overlay and grouped-action roles to existing shared surfaces.
- Modify `CatLocalTests/CatLocalCoreTests.swift`: pure state and legacy metrics regression tests.
- Modify `CatLocalUITests/CatLocalUITests.swift`: retain centered-tab coverage and add Settings-origin capture restoration coverage if runtime accessibility permits a stable assertion.
- Modify `AGENTS.md`, `docs/architecture.md`, and `docs/design/README.md`: record the final compatibility-layer convention.

---

### Task 1: Stabilize Persistent Tabs And Transient Capture

**Files:**
- Modify: `CatLocal/App/RootView.swift`
- Test: `CatLocalTests/CatLocalCoreTests.swift`
- Test: `CatLocalUITests/CatLocalUITests.swift`

**Interfaces:**
- Produces: `AppTabPresentationState` with `selectedTab`, `lastContentTab`, `presentedSheet`, `selectContentTab(_:)`, `presentCapture()`, and `restoreContentTabSelection()`.
- Consumes: existing `AppTab`, `AppSheet`, `CaptureView`, and `CollectionView` contracts.

- [ ] **Step 1: Add failing state-machine tests**

Add Swift Testing cases to `CatLocalCoreTests`:

```swift
@Test
func capturePresentationRestoresTheOriginatingContentTabAndRejectsReentry() {
    var state = AppTabPresentationState(initialTab: .settings)

    #expect(state.presentCapture())
    #expect(state.selectedTab == .capture)
    #expect(state.lastContentTab == .settings)
    #expect(state.presentedSheet == .capture)
    #expect(!state.presentCapture())

    let restoredTab = state.restoreContentTabSelection()
    #expect(restoredTab == .settings)
    #expect(state.selectedTab == .settings)
    #expect(state.presentedSheet == nil)
}

@Test
func selectingContentTabsNeverMakesCaptureRestorable() {
    var state = AppTabPresentationState(initialTab: .home)

    state.selectContentTab(.settings)
    #expect(state.selectedTab == .settings)
    #expect(state.lastContentTab == .settings)

    state.selectContentTab(.capture)
    #expect(state.selectedTab == .settings)
    #expect(state.lastContentTab == .settings)
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run on the configured iOS 18 Simulator:

```text
test_sim extraArgs=[
  "-only-testing:CatLocalTests/CatLocalCoreTests/capturePresentationRestoresTheOriginatingContentTabAndRejectsReentry",
  "-only-testing:CatLocalTests/CatLocalCoreTests/selectingContentTabsNeverMakesCaptureRestorable"
]
```

Expected: compilation fails because `AppTabPresentationState` does not exist.

- [ ] **Step 3: Implement the state value and wire RootView**

Add beside `AppTab` in `RootView.swift`:

```swift
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
```

Add `Equatable` to `AppSheet` so the state value and its tests can compare the
optional presentation route:

```swift
enum AppSheet: String, Identifiable, Equatable {
    case capture

    var id: String { rawValue }
}
```

Replace the three separate RootView state properties with:

```swift
@State private var tabState: AppTabPresentationState
@AccessibilityFocusState private var accessibilityFocusedTab: AppTab?
```

Initialize it from the existing launch-argument-derived initial tab, bind the tab view to `tabState.selectedTab`, bind the cover to `tabState.presentedSheet`, and route content selection through `selectContentTab(_:)`. `presentCapture()` must return early when the state value rejects re-entry.

In the pre-iOS 26 tab labels, bind Home and Settings with `accessibilityFocused`. After capture dismissal, restore the originating tab and set `accessibilityFocusedTab` to that tab on the next main-actor turn. Do not change iOS 26 tab labels.

Apply a legacy-only native tab background after `.tabViewStyle(.sidebarAdaptable)`:

```swift
.toolbarBackground(.regularMaterial, for: .tabBar)
.toolbarBackground(.visible, for: .tabBar)
```

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the two tests from Step 2.

Expected: 2 tests pass, 0 fail.

- [ ] **Step 5: Retain and extend UI coverage**

Keep `testPreIOS26CameraTabIsCenteredAndAccessible`. Add a Settings-origin assertion to an isolated UI test only if the camera close control is stable on the simulator:

```swift
func testCaptureDismissalRestoresSettingsTab() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing-reset", "-ui-testing-open-settings"]
    app.launch()

    let settings = app.tabBars.buttons["Settings"]
    XCTAssertTrue(settings.waitForExistence(timeout: 8))
    XCTAssertTrue(settings.isSelected)

    tapWhenHittable(app.tabBars.buttons["Camera"])
    let close = app.buttons["Close camera"]
    XCTAssertTrue(close.waitForExistence(timeout: 8))
    tapWhenHittable(close)

    XCTAssertTrue(settings.waitForExistence(timeout: 8))
    XCTAssertTrue(settings.isSelected)
}
```

If simulator camera availability makes this assertion non-deterministic, keep the deterministic state-machine tests as the regression boundary and document the manual Settings-origin check in verification results.

- [ ] **Step 6: Checkpoint commit**

```bash
git add CatLocal/App/RootView.swift CatLocalTests/CatLocalCoreTests.swift CatLocalUITests/CatLocalUITests.swift
git commit -m "Stabilize legacy capture tab state"
```

---

### Task 2: Build The Accessibility-Aware Legacy Surface Resolver

**Files:**
- Modify: `CatLocal/Shared/DesignSystem/CatLocalTheme.swift`
- Test: `CatLocalTests/CatLocalCoreTests.swift`

**Interfaces:**
- Produces: `CatLegacySurfaceRole`, `CatLegacySurfaceMetrics.resolve(role:requestedCornerRadius:reduceTransparency:increasedContrast:)`, and `catGlass(cornerRadius:interactive:legacyRole:)`.
- Consumes: existing `CatLocalTheme` semantic colors and iOS 26 `glassEffect` branch.

- [ ] **Step 1: Add failing metrics tests**

```swift
@Test
func legacySurfaceMetricsCapGeometryBySemanticRole() {
    let compact = CatLegacySurfaceMetrics.resolve(
        role: .compactControl,
        requestedCornerRadius: 28,
        reduceTransparency: false,
        increasedContrast: false
    )
    let grouped = CatLegacySurfaceMetrics.resolve(
        role: .groupedAction,
        requestedCornerRadius: 28,
        reduceTransparency: false,
        increasedContrast: false
    )

    #expect(compact.cornerRadius == 16)
    #expect(grouped.cornerRadius == 20)
    #expect(grouped.shadowRadius <= 6)
}

@Test
func legacySurfaceMetricsStrengthenSeparationWithoutChangingGeometry() {
    let standard = CatLegacySurfaceMetrics.resolve(
        role: .cameraOverlay,
        requestedCornerRadius: 28,
        reduceTransparency: false,
        increasedContrast: false
    )
    let accessible = CatLegacySurfaceMetrics.resolve(
        role: .cameraOverlay,
        requestedCornerRadius: 28,
        reduceTransparency: true,
        increasedContrast: true
    )

    #expect(accessible.cornerRadius == standard.cornerRadius)
    #expect(accessible.outlineOpacity > standard.outlineOpacity)
    #expect(accessible.usesOpaqueSurface)
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Expected: compilation fails because the role and resolver types do not exist.

- [ ] **Step 3: Add semantic roles and pure metrics**

Define:

```swift
enum CatLegacySurfaceRole: Equatable {
    case compactControl
    case groupedAction
    case cameraOverlay
    case sheetAction
    case navigationAdjacent

    var maximumCornerRadius: CGFloat {
        switch self {
        case .compactControl, .navigationAdjacent:
            16
        case .groupedAction, .cameraOverlay, .sheetAction:
            20
        }
    }
}

struct CatLegacySurfaceMetrics: Equatable {
    let cornerRadius: CGFloat
    let outlineOpacity: Double
    let shadowOpacity: Double
    let shadowRadius: CGFloat
    let shadowYOffset: CGFloat
    let usesOpaqueSurface: Bool

    static func resolve(
        role: CatLegacySurfaceRole,
        requestedCornerRadius: CGFloat,
        reduceTransparency: Bool,
        increasedContrast: Bool
    ) -> CatLegacySurfaceMetrics {
        CatLegacySurfaceMetrics(
            cornerRadius: min(requestedCornerRadius, role.maximumCornerRadius),
            outlineOpacity: increasedContrast ? 0.92 : 0.68,
            shadowOpacity: reduceTransparency ? 0.08 : 0.13,
            shadowRadius: role == .cameraOverlay ? 4 : 6,
            shadowYOffset: role == .cameraOverlay ? 2 : 3,
            usesOpaqueSurface: reduceTransparency
        )
    }
}
```

- [ ] **Step 4: Refactor CatGlassModifier without changing iOS 26**

Add these environments to `CatGlassModifier`:

```swift
@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
@Environment(\.colorSchemeContrast) private var colorSchemeContrast
```

Add `legacyRole`. Keep the existing iOS 26 glass, outline, and 7-point shadow exactly as they are. In the older branch:

- Resolve metrics with `colorSchemeContrast == .increased`.
- Use `CatLocalTheme.cardSurface` when `usesOpaqueSurface` is true.
- Otherwise use `regularMaterial` for `.cameraOverlay` and `thinMaterial` for the other roles.
- Apply the resolved semantic outline and local shadow to the resolved legacy shape.

Update the extension signature:

```swift
nonisolated func catGlass(
    cornerRadius: CGFloat,
    interactive: Bool = false,
    legacyRole: CatLegacySurfaceRole = .compactControl
) -> some View
```

Update `catSingleActionIconSurface()` and `catSingleActionPillSurface()` to pass `.sheetAction`.

- [ ] **Step 5: Run focused metrics tests and the full unit suite**

Expected: focused tests pass; the existing 132-test baseline plus new tests passes with zero failures.

- [ ] **Step 6: Checkpoint commit**

```bash
git add CatLocal/Shared/DesignSystem/CatLocalTheme.swift CatLocalTests/CatLocalCoreTests.swift
git commit -m "Add accessible legacy material roles"
```

---

### Task 3: Apply Roles To Home, Settings, Capture, And Sheets

**Files:**
- Modify: `CatLocal/Features/Collection/CollectionView.swift`
- Modify: `CatLocal/Features/Settings/SettingsView.swift`
- Modify: `CatLocal/Features/Capture/CaptureView.swift`
- Modify: `CatLocal/Shared/DesignSystem/CatLocalTheme.swift`

**Interfaces:**
- Consumes: `catGlass(cornerRadius:interactive:legacyRole:)` from Task 2.
- Produces: consistent role assignments with no new screen-local material definitions.

- [ ] **Step 1: Assign grouped-action roles**

Change the collection selection action bar:

```swift
.catGlass(cornerRadius: 26, legacyRole: .groupedAction)
```

Change Cat Selection rows in Capture:

```swift
.catGlass(
    cornerRadius: 20,
    interactive: true,
    legacyRole: .groupedAction
)
```

- [ ] **Step 2: Assign camera-overlay roles**

Pass `.cameraOverlay` to the validation-photo button, zoom control, and Stop and return control. `catSingleActionIconSurface()` is sheet-oriented, so add a dedicated shared helper for camera icons:

```swift
nonisolated func catCameraOverlayIconSurface() -> some View {
    frame(width: 56, height: 56)
        .catGlass(
            cornerRadius: 28,
            interactive: true,
            legacyRole: .cameraOverlay
        )
}
```

Use it for the PhotosPicker camera control. Preserve the 82-point shutter and existing accessibility labels.

- [ ] **Step 3: Restore system-managed legacy Settings navigation**

Replace the unconditional hidden toolbar background with a focused modifier:

```swift
private struct SettingsNavigationBackgroundModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.toolbarBackground(.hidden, for: .navigationBar)
        } else {
            content
        }
    }
}
```

Apply `.modifier(SettingsNavigationBackgroundModifier())` after the large-title mode. This leaves iOS 26 unchanged and lets iOS 18 use native scroll-edge behavior.

- [ ] **Step 4: Verify accessibility behavior in source**

Confirm every changed icon-only control retains an accessibility label, all changed frames are at least 44 points, and no material role is expressed through a screen-local raw color.

- [ ] **Step 5: Build for iOS 18 and run relevant UI tests**

Run:

- `testPreIOS26CameraTabIsCenteredAndAccessible`
- `testEmptyHomeCaptureEntryAndSettingsReceipt`
- `testCameraExposesAccessibleZoomControl`
- `testCameraPrivacyBadgeReflowsAtAccessibilityTextSize`
- `testValidationLiftOffersStopAndReturnAfterShortDelay`

Expected: all selected tests pass.

- [ ] **Step 6: Checkpoint commit**

```bash
git add CatLocal/Features/Collection/CollectionView.swift CatLocal/Features/Settings/SettingsView.swift CatLocal/Features/Capture/CaptureView.swift CatLocal/Shared/DesignSystem/CatLocalTheme.swift
git commit -m "Polish pre-iOS 26 material surfaces"
```

---

### Task 4: Document And Verify The Full Compatibility Pass

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/architecture.md`
- Modify: `docs/design/README.md`
- Test: `CatLocalTests/CatLocalCoreTests.swift`
- Test: `CatLocalUITests/CatLocalUITests.swift`

**Interfaces:**
- Consumes: all implementation behavior from Tasks 1 through 3.
- Produces: handoff documentation and verification evidence.

- [ ] **Step 1: Update handoff rules**

Document:

- The five semantic legacy surface roles.
- Reduce Transparency uses opaque `CatLocalTheme.cardSurface`.
- Increase Contrast strengthens outlines without changing geometry.
- Camera overlays use stronger material than calm app-background controls.
- Settings uses system-managed legacy navigation material.
- iOS 26 glass behavior stays isolated and unchanged.

- [ ] **Step 2: Run static checks**

```bash
git diff --check
rg -n "catGlass\(" CatLocal
rg -n "#available\(iOS 26" CatLocal/App/RootView.swift CatLocal/Shared/DesignSystem/CatLocalTheme.swift CatLocal/Features/Settings/SettingsView.swift
```

Expected: no whitespace errors; every material call has an intentional default or explicit role; availability checks remain concentrated.

- [ ] **Step 3: Run complete iOS 18 automated verification**

- Build and launch the `CatLocal` scheme on the iOS 18 Simulator.
- Run all unit tests.
- Run all UI tests in bounded batches if the XcodeBuildMCP 300-second transport limit prevents one complete response.
- Record exact passed, failed, and skipped counts.

- [ ] **Step 4: Perform iOS 18 manual visual matrix**

Capture representative before-and-after evidence for:

- Home empty in light and dark.
- Seeded collection/Catlas.
- Settings at top and after scroll.
- Capture ready or simulator-unavailable recovery.
- A representative sheet.
- Largest accessibility Dynamic Type.

Use launch arguments and accessibility environment settings already supported by the UI tests where possible. Report Reduce Transparency, Increase Contrast, and VoiceOver checks that cannot be automated reliably.

- [ ] **Step 5: Verify iOS 26 isolation**

- Build and launch on the iOS 26 Simulator.
- Capture Home and Settings in light and dark.
- Confirm Home/Settings remain grouped and Camera remains the detached search-role tab.
- Run focused root-shell, Settings, and Capture UI tests.
- Compare against the pre-change iOS 26 appearance from the prior verified baseline.

- [ ] **Step 6: Clean Simulator state**

- Stop CatLocal.
- Shut down every booted Simulator.
- Confirm no Simulator reports `Booted`.
- Confirm no `/usr/bin/xcodebuild` process remains.

- [ ] **Step 7: Final checkpoint commit**

```bash
git add AGENTS.md docs/architecture.md docs/design/README.md
git commit -m "Document legacy UI compatibility rules"
```

- [ ] **Step 8: Final diff review**

Confirm only intended source, test, and documentation files changed. Leave `AppStore/` and `FIX_DUST_REVEAL_AND_COMPLETE_CARD_TRANSITION.md` untracked and untouched. Do not push without an explicit user request.
