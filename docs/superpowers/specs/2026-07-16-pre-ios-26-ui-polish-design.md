# Pre-iOS 26 UI Polish Design

## Status

Approved direction: restrained shipping polish for iOS 18 through iOS 25.

This design improves the older-system presentation without changing CatLocal's
product flow, information architecture, or iOS 26 Liquid Glass treatment.

## Product Intent

CatLocal is a quiet, tactile, local-first field journal. Older supported iOS
versions should feel deliberately designed for their native material system,
not like a reduced version of the iOS 26 interface.

The polish should make the interface easier to read and operate while keeping
the user's cats and the capture-to-card loop visually dominant.

## Quality Bar

This is a restrained production pass, not a visual redesign.

- Preserve familiar native controls and navigation.
- Resolve repeated compatibility-layer issues at their shared source.
- Make only targeted screen-level adjustments when a shared fix cannot express
  the intended hierarchy.
- Keep motion brief, state-driven, and optional.
- Avoid new features, new product copy, custom navigation chrome, and decorative
  effects.

## Scope

### Included

- The iOS 18 through iOS 25 `RootView` tab and system-bar presentation.
- Material-backed controls that currently use `catGlass` fallbacks.
- Home empty, collection, and Catlas surfaces where shared fallback changes are
  visible.
- Settings navigation and grouped-list legibility.
- Capture entry controls, camera overlays, recovery actions, and editor actions
  that use shared material surfaces.
- Shared sheet actions and other reusable compatibility-layer controls.
- Light mode, dark mode, Dynamic Type, VoiceOver naming, Reduce Motion, and
  minimum touch-target behavior.

### Excluded

- iOS 26 Liquid Glass layout, tab role, effects, and navigation behavior.
- Card artwork, procedural card styles, focused-card foil, or tilt physics.
- Capture, Vision, storage, persistence, or privacy behavior.
- Onboarding structure or copy, except where a shared token fix changes a
  reusable control automatically.
- Custom floating tab bars or attempts to imitate Liquid Glass.

## Design Approach

### 1. Shared Legacy Material Hierarchy

The root cause of most older-system drift is that one Liquid Glass-compatible
modifier currently falls back to a very translucent material while retaining
the same large geometry and decorative depth.

Refine the pre-iOS 26 branch of the shared surface modifier so it has its own
native material character:

- Use a legible system material appropriate for controls over the CatLocal
  background. Prefer `thinMaterial` for compact controls; use a more opaque
  material only where live camera imagery reduces contrast.
- Use a tighter continuous corner radius for older-system material surfaces.
  Legacy compact controls should generally remain at 16 points, while grouped
  action surfaces should not exceed 20 points. Do not change card radii.
- Keep a semantic one-point outline only when it separates the control from its
  background. Use `CatLocalTheme.imageOutline` rather than a hard-coded color.
- Keep shadow depth quiet and local. A fallback surface may use a small shadow
  with no more than 6 points of blur; it should not combine a wide soft shadow
  with a decorative border.
- Keep pressed feedback inside the existing tactile button style so interaction
  does not shift surrounding layout.

iOS 26 continues to use the existing `glassEffect` implementation without any
visual or behavioral change.

### 2. Native Navigation And Bars

On iOS 18 through iOS 25, keep the standard native tab order:

`Home -> Camera -> Settings`

- Camera remains centered, uses the filled camera symbol, and opens the same
  full-screen capture flow without becoming a persistent destination.
- Preserve Home or Settings as the selected content tab after Capture closes.
- Give the legacy tab bar a stable native material background so content does
  not visually merge with the home indicator area in light or dark mode.
- Let older-system navigation bars use system-managed material and scroll-edge
  behavior. Do not force a hidden navigation-bar background on Settings when it
  harms title and content separation.
- Do not add a floating center button, raised notch, custom selection indicator,
  or imitation glass capsule.

### 3. Screen-Level Corrections

Shared changes should carry most of the work. Screen-specific edits are limited
to the following responsibilities.

#### Home And Catlas

- Preserve the current header, mode picker, card grid, and empty-state
  information architecture.
- Keep one clear primary capture action in the empty state.
- Ensure the bottom of scrollable content clears the persistent legacy tab bar.
- Keep muted grid thumbnails and static overlays unchanged.
- Maintain single-column reflow at accessibility Dynamic Type sizes.

#### Settings

- Preserve native grouped lists and system controls.
- Improve navigation-title and first-section separation on pre-iOS 26 by using
  the native navigation-bar background rather than transparent custom chrome.
- Keep destructive actions separated and semantically red.
- Do not convert list sections into custom cards.

#### Capture And Editor

- Keep camera capture and private import as equal first-class entry paths.
- Material-backed camera controls must remain readable over both bright and dark
  imagery.
- Keep every icon-only control at least 44 by 44 points with a descriptive
  accessibility label or hint.
- Preserve the existing stage sequence, error recovery, cancel paths, and save
  behavior.
- Do not add decorative animation to camera controls or processing states.

## Typography And Color

- Continue using `CatTypography` and Dynamic Type-aware system styles.
- Continue using `CatLocalTheme` semantic colors; no new screen-local color
  constants or raw color literals.
- Primary text must remain at least 4.5:1 against its effective surface.
- Secondary text and inactive symbols must remain legible in both appearance
  modes and cannot be the sole carrier of state.
- Accent color remains reserved for primary action and selected state.

## Motion And Feedback

- Use the existing native-feeling motion vocabulary.
- UI state transitions should complete in roughly 150 to 220 milliseconds.
- Use smooth deceleration without bounce or elastic effects.
- Do not animate layout properties when opacity or transform expresses the same
  state change.
- Respect Reduce Motion by removing travel and scale where it is nonessential.
- Keep haptics tied to intent or completion, not decorative state changes.

## Architecture And Data Flow

The polish introduces no new model or service layer.

1. `RootView` continues to own selected-tab and capture-sheet state.
2. Shared appearance behavior stays in `CatLocalTheme.swift` through focused
   view modifiers and semantic tokens.
3. Home, Settings, and Capture consume those shared modifiers without learning
   about compatibility details that do not affect their layout.
4. Availability checks isolate iOS 26-only APIs and keep the older-system
   fallback explicit.
5. Persistence, camera, Vision, and image-storage data flow remains unchanged.

Avoid a new view model, global appearance object, or UIKit appearance proxy.

## Error And Edge-State Behavior

- Material changes must not obscure capture permission, camera unavailable,
  Vision failure, storage failure, or destructive confirmation copy.
- Existing recovery actions and modal escape routes remain visible and
  reachable.
- Long localized copy must wrap rather than clip.
- Accessibility text sizes must not place fixed controls over content.
- Dark mode must retain separation between background, material, outlines, and
  selected controls.

## Verification

### Automated

- Run `git diff --check`.
- Build the `CatLocal` scheme for the iOS 18 Simulator.
- Run the complete unit-test suite on iOS 18.
- Run all UI tests on iOS 18, splitting the suite only if the tool transport
  limit requires bounded batches.
- Keep or extend the pre-iOS 26 tab geometry and touch-target regression test.
- Run focused root-shell, Settings, and Capture UI coverage on iOS 26 to confirm
  the modern branch remains unchanged.

### Visual And Interaction

Inspect iOS 18 on a small or standard phone in:

- Light mode.
- Dark mode.
- Largest accessibility Dynamic Type.
- Home empty state.
- Home with seeded cards and Catlas content.
- Settings at the navigation top and after scrolling.
- Capture entry and camera-unavailable or permission recovery state.
- A representative editor or confirmation sheet.

Confirm that:

- Camera remains centered in the legacy tab bar.
- System bars are visually distinct without becoming heavy.
- Material controls remain legible over app backgrounds and camera imagery.
- Touch targets remain at least 44 points.
- No content is hidden behind bars or safe areas.
- Reduced Motion retains the same information and completion paths.

After Simulator work, stop CatLocal, shut down every booted Simulator, and
confirm no `xcodebuild` process remains.

## Acceptance Criteria

- iOS 18 through iOS 25 feels intentionally native rather than like simulated
  Liquid Glass.
- iOS 26 appearance and behavior is unchanged.
- The product hierarchy and all user flows are unchanged.
- Shared compatibility surfaces are more legible and geometrically restrained.
- Home, Settings, and Capture remain usable in both appearance modes and at
  accessibility text sizes.
- Automated verification passes with no new warnings or test failures.
- No custom tab bar, unsupported feature, or one-off design token is introduced.
