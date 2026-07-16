# Pre-iOS 26 UI Polish Design

## Status

Approved direction: restrained shipping polish for iOS 18 through iOS 25.

This work improves CatLocal’s presentation on older supported systems without changing its product flow, information architecture, card experience, or iOS 26 Liquid Glass implementation.

## Product Intent

CatLocal is a quiet, tactile, local-first field journal.

On iOS 18 through iOS 25, the app should feel intentionally designed for Apple’s established material system—not like a reduced or partially unsupported version of the iOS 26 interface.

The polish should improve readability, interaction clarity, and visual consistency while keeping the user’s cats and the capture-to-card loop visually dominant.

## Quality Bar

This is a restrained production pass, not a redesign.

- Preserve familiar native controls and navigation.
- Resolve repeated compatibility-layer issues at their shared source.
- Make targeted screen-level adjustments only when a shared fix cannot express the intended hierarchy.
- Keep motion brief, state-driven, interruptible, and optional.
- Preserve existing product copy unless a label is inaccessible or misleading.
- Avoid new features, custom navigation chrome, decorative effects, and imitation Liquid Glass.
- Do not make pre-iOS 26 appear visually identical to iOS 26.
- Do not regress the iOS 26 experience while changing shared code.

# Scope

## Included

- The iOS 18 through iOS 25 `RootView` tab and system-bar presentation.
- Shared material-backed controls that currently use `catGlass` fallbacks.
- Home empty, collection, Cards, and Catlas surfaces affected by shared fallback changes.
- Settings navigation and grouped-list legibility.
- Capture entry controls, camera overlays, recovery actions, and editor actions using shared material surfaces.
- Shared sheets, action rows, buttons, pills, and reusable compatibility-layer controls.
- Light mode and dark mode.
- Dynamic Type.
- VoiceOver naming and reading order.
- Reduce Motion.
- Reduce Transparency.
- Increase Contrast.
- Differentiate Without Color Alone.
- Minimum touch-target behavior.
- iOS 26 regression verification.

## Excluded

- iOS 26 Liquid Glass layout, tab roles, effects, materials, and navigation behavior.
- Card artwork and procedural card themes.
- Focused-card foil, glint, tilt, and physics.
- Capture, Vision, storage, persistence, and privacy behavior.
- Onboarding structure or copy, except where a shared token or reusable-control fix applies automatically.
- Custom floating tab bars.
- Raised center buttons or tab-bar notches.
- Custom selection capsules.
- Attempts to imitate Liquid Glass on older systems.
- New user-facing features or navigation destinations.
- Broad spacing or typography redesigns unrelated to compatibility.

# Design Approach

## 1. Shared Legacy Material Hierarchy

The main source of older-system visual drift is that a modifier designed around Liquid Glass currently falls back to a highly translucent material while retaining large geometry, wide shadows, and decorative depth.

Refine the pre-iOS 26 branch of the shared surface modifier so it has an intentional native material character.

### Material Selection

Do not establish one material as the universal fallback.

Start with `thinMaterial` for compact controls, then choose the least opaque system material that still provides sufficient contrast over every supported background.

Material selection should account for context:

- Compact controls over calm CatLocal surfaces may use `thinMaterial`.
- Controls over photographs or live camera imagery may require a more opaque material.
- Grouped actions and sheets may use a stronger system-managed material when needed for separation.
- Reduce Transparency must replace material-dependent surfaces with sufficiently opaque semantic colors.

Do not hard-code material decisions separately across many screens when the same semantic control role can be expressed through a shared modifier.

### Geometry

For iOS 18 through iOS 25:

- Compact material controls should generally use a continuous corner radius of `16 pt`.
- Grouped action surfaces should generally use a continuous corner radius no larger than `20 pt`.
- Do not change card radii.
- Do not force unrelated controls into the same geometry merely because they share a material.
- Preserve circular controls as circles.
- Avoid geometry changes that cause labels or icons to shift between pressed and resting states.

### Outlines

- Use a semantic one-point outline only when it materially improves separation.
- Prefer `CatLocalTheme.imageOutline` or the appropriate existing semantic theme token.
- Do not hard-code light or dark outline colors.
- Do not combine decorative borders with wide shadows.
- Ensure Increase Contrast can strengthen necessary separation without changing layout.

### Shadows

Keep shadow depth quiet and local.

A legacy fallback surface may use:

- A small vertical offset.
- No more than approximately `6 pt` of blur.
- Low semantic opacity appropriate to light or dark mode.

Avoid:

- Wide floating shadows.
- Multiple simultaneous shadows.
- Glow effects.
- Shadows used as the only means of separating a control from its background.

### Pressed Feedback

Keep pressed feedback inside the existing tactile button style.

Pressed states must:

- Avoid shifting surrounding layout.
- Remain visible with Reduce Motion enabled.
- Not rely only on color.
- Avoid excessive scaling.
- Return cleanly when an interaction is cancelled.

### iOS 26 Isolation

iOS 26 continues using the existing `glassEffect` implementation without visual or behavioral changes.

Changes to shared modifiers must preserve a clear availability boundary so legacy properties do not accidentally alter the iOS 26 branch.

# 2. Native Navigation and Bars

On iOS 18 through iOS 25, retain the native tab order:

`Home → Camera → Settings`

## Tab Bar

- Use the native tab bar.
- Give the tab bar a stable system-managed material background.
- Prevent content from visually merging with the home-indicator area.
- Preserve system safe-area behavior.
- Preserve native tab-item sizing and accessibility behavior.
- Do not add a floating camera button, notch, custom selection capsule, raised center item, or imitation glass treatment.
- Do not hide the tab-bar background when doing so reduces readability.

## Camera Action Behavior

Camera remains centered and uses the filled camera symbol.

It launches the existing full-screen capture flow without becoming a persistent content destination.

The implementation must maintain:

- The currently selected content tab.
- The last valid content tab: Home or Settings.
- A separate transient capture-presentation state.
- Protection against repeated presentation while capture is already opening or visible.

Verify:

- Activating Camera from Home returns to Home when capture closes.
- Activating Camera from Settings returns to Settings when capture closes.
- Camera never remains selected as an empty destination.
- Repeated taps do not present multiple capture flows.
- Scene or tab state restoration never launches capture automatically.
- Dismissing an error, permission prompt, or recovery state restores the expected content tab.

## Camera Accessibility

The camera tab or action must:

- Be announced as `Capture` or `Camera`.
- Have an accessibility trait that matches its interactive behavior.
- Avoid misleading VoiceOver users into expecting persistent tab content.
- Provide a concise hint only if the action is not otherwise clear.
- Preserve a predictable VoiceOver focus destination after capture dismisses.

## Navigation Bars

- Use system-managed navigation-bar material and scroll-edge behavior.
- Do not globally force navigation-bar backgrounds hidden.
- Allow Settings to retain title and content separation.
- Avoid screen-specific toolbar hacks when a shared navigation configuration is sufficient.
- Verify large-title transitions and scrolling in light and dark mode.
- Do not reproduce iOS 26 glass navigation effects on older systems.

# 3. Screen-Level Corrections

Shared modifier changes should be implemented first. Apply screen-specific corrections only after reviewing the result of the shared changes.

## Home — Empty State

- Keep the mascot, explanation, and capture action visually dominant.
- Ensure the primary capture action is clearly distinguishable from passive material surfaces.
- Prevent translucent controls from disappearing into the sage background.
- Preserve generous whitespace.
- Do not add decorative containers merely to fill empty space.
- Ensure the empty-state copy remains readable at large Dynamic Type sizes.
- Keep decorative mascot imagery out of the VoiceOver reading order.

## Home — Collection

- Preserve card artwork, ordering, size, and collection behavior.
- Ensure Cards and Catlas switching remains legible in light and dark mode.
- Ensure selected state is communicated by more than color alone.
- Keep sorting, selection, and camera actions visually subordinate to the cards.
- Avoid adding material backgrounds behind every card.
- Prevent bottom content from blending into the tab bar.
- Verify the collection at empty, partially populated, and densely populated states.

## Catlas

- Preserve existing place grouping and privacy behavior.
- Ensure section labels and place names remain readable over legacy materials.
- Keep Cats and places visually primary rather than surrounding chrome.
- Verify selection and grouping without relying only on tint.
- Avoid map-like decorative additions or precise-location implications.
- Ensure larger text does not truncate essential place labels without an accessible alternative.

## Settings

- Retain native grouped-list behavior.
- Use system-managed navigation-bar and list backgrounds.
- Do not hide the navigation-bar background when it weakens title separation.
- Ensure section headers, footers, rows, disclosure indicators, toggles, and destructive actions remain legible.
- Preserve native row heights unless a custom row requires additional space for Dynamic Type.
- Avoid placing every settings row inside a separate material card.
- Ensure disclosure rows expose useful VoiceOver values and hints where needed.
- Verify that long localized labels wrap or expand rather than clipping.

## Capture Entry

- Keep capture as the dominant action.
- Preserve native permission flows.
- Ensure close, retry, import, shutter, and recovery controls remain readable over live imagery.
- Use a more opaque material when `thinMaterial` does not maintain sufficient contrast over the camera feed.
- Do not rely on a shadow alone for camera-overlay legibility.
- Preserve safe-area placement around the Dynamic Island and home indicator.
- Keep every interactive camera control at least `44 × 44 pt`.

## Camera Overlays

- Use semantic foreground colors.
- Provide stable control silhouettes over light and dark live imagery.
- Ensure icons have accessible labels.
- Hide decorative layers from VoiceOver.
- Avoid material stacking where one translucent surface sits inside another.
- Ensure Increase Contrast can strengthen the overlay without changing its geometry.

## Capture Recovery

- Keep recovery messages concise and visually connected to their actions.
- Ensure retry and choose-another-photo actions are distinguishable.
- Keep destructive or dismissive actions visually secondary.
- Preserve Loci’s supportive role without allowing the mascot to compete with recovery actions.
- Ensure VoiceOver reads the error summary before the recovery actions.

## Card Editor

- Preserve card preview, theme selection, naming, Catlas labels, and save behavior.
- Keep the card visually dominant.
- Ensure action surfaces below the card remain distinct from the background.
- Prevent bottom actions from merging with the home-indicator area.
- Allow editor actions to stack vertically when Dynamic Type requires more space.
- Do not shrink text below accessible sizes to preserve a horizontal layout.
- Ensure the keyboard does not obscure the active field or primary save action.
- Keep pressed and selected states visible without depending only on color.

## Sheets and Shared Actions

- Use consistent legacy material roles for primary, secondary, and destructive actions.
- Preserve native sheet detents and dismissal behavior.
- Ensure the sheet background and action surfaces remain visually distinct.
- Avoid card-inside-card presentation.
- Ensure long localized action labels wrap or expand appropriately.
- Preserve minimum touch targets.
- Keep destructive actions semantically and visually clear.

# 4. Accessibility Adaptation

## Dynamic Type

Test at minimum:

- Default size.
- A large accessibility size.
- The largest supported accessibility size where the screen remains operational.

Requirements:

- Essential labels must not truncate without an accessible alternative.
- Primary actions must remain reachable.
- Horizontal action groups may become vertical.
- Text must not overlap icons, cards, safe areas, or adjacent controls.
- Do not reduce font size to make a fixed layout fit.
- Preserve scrolling where content no longer fits vertically.

## VoiceOver

Verify:

- Every interactive icon has a concise name.
- Values and selected states are announced.
- Decorative images and effects are hidden.
- Reading order follows the visual hierarchy.
- Capture recovery announces the problem before the actions.
- Tab selection and capture dismissal restore focus predictably.
- Card metadata is understandable without requiring visual interpretation.
- Duplicate labels are removed when a parent accessibility element already describes the control.

## Reduce Motion

When Reduce Motion is enabled:

- Disable nonessential scaling, tilting, bouncing, and spring-based travel.
- Preserve immediate pressed-state feedback.
- Prefer brief opacity or state changes only when they improve understanding.
- Ensure capture presentation and dismissal remain understandable.
- Do not remove necessary loading or progress communication.

## Reduce Transparency

When Reduce Transparency is enabled:

- Replace translucent material surfaces with opaque or sufficiently opaque semantic surfaces.
- Preserve clear separation in light and dark mode.
- Avoid falling back to hard-coded white or black.
- Ensure text and icons retain sufficient contrast.
- Keep geometry unchanged when swapping the material.

## Increase Contrast

When Increase Contrast is enabled:

- Strengthen semantic outlines and foreground contrast where necessary.
- Preserve layout and component geometry.
- Do not rely on shadow changes alone.
- Ensure selected, disabled, destructive, and pressed states remain distinguishable.
- Verify controls over camera imagery independently from controls over app backgrounds.

## Differentiate Without Color Alone

- Selected tabs, segmented controls, themes, and action states must use shape, iconography, weight, labels, or system selection behavior in addition to tint.
- Errors and destructive actions must not be communicated only by red.
- Disabled controls must remain understandable without relying solely on reduced opacity.

## Touch Targets

- All interactive controls must provide at least a `44 × 44 pt` hit area.
- Visual symbols may remain smaller when the invisible hit target is sufficient.
- Expanded hit targets must not overlap neighboring controls.
- Verify close, retry, camera, tab, editor, and sheet actions.

# 5. Implementation Strategy

## Step 1 — Audit Existing Compatibility Paths

Identify:

- The shared `catGlass` or equivalent compatibility modifier.
- Shared button and tactile-control styles.
- Root tab selection and capture-presentation state.
- Navigation and tab-bar visibility modifiers.
- Screen-specific fallback overrides.
- Existing semantic theme tokens.
- Existing accessibility environment handling.

Document which screens inherit shared behavior and which currently override it.

Do not begin with isolated screen patches before this audit.

## Step 2 — Centralize Legacy Surface Roles

Refactor the pre-iOS 26 compatibility branch around semantic surface roles such as:

- Compact control.
- Grouped action.
- Camera overlay.
- Sheet action.
- Navigation-adjacent control.

Reuse existing theme infrastructure where possible.

Avoid:

- Repeated hard-coded corner radii.
- Repeated material declarations.
- Repeated shadow definitions.
- Per-screen availability checks for the same visual role.

Keep iOS 26 behavior in its existing branch.

## Step 3 — Add Accessibility-Aware Fallback Resolution

The legacy surface resolver should account for:

- Light or dark appearance.
- Reduce Transparency.
- Increase Contrast.
- Camera or image-backed context.
- Control role.

Use semantic theme colors and system materials.

Do not make accessibility behavior dependent on device model.

## Step 4 — Stabilize Root Tab and Capture State

Separate:

- Selected persistent content tab.
- Last selected persistent content tab.
- Transient capture-presentation state.

Prevent re-entrant presentation.

Preserve expected selection and VoiceOver focus when capture closes.

Do not encode camera presentation as restorable selected-tab state.

## Step 5 — Apply Shared Changes

Apply and review the centralized changes across:

- Root navigation.
- Home.
- Cards.
- Catlas.
- Settings.
- Capture.
- Recovery.
- Editor.
- Shared sheets and actions.

Record any screen that remains visually incorrect after the shared pass.

## Step 6 — Apply Targeted Screen Corrections

Make only the smallest screen-specific changes required to resolve:

- Contrast.
- Safe-area collisions.
- Incorrect navigation-bar visibility.
- Dynamic Type overflow.
- VoiceOver order.
- Camera-overlay legibility.
- Action hierarchy.

Do not duplicate shared styling locally to achieve a one-off appearance.

## Step 7 — Verify iOS 26 Isolation

Compare iOS 26 before and after the work.

Confirm no changes to:

- Liquid Glass materials.
- Tab roles.
- Navigation behavior.
- Layout.
- Card presentation.
- Motion.
- Capture flow.
- Settings structure.

If a shared change affects iOS 26 unintentionally, move it behind the legacy availability boundary or separate the shared behavior from the legacy presentation.

# 6. Visual and Interaction Tokens

Prefer existing CatLocal semantic tokens. Add new tokens only when a repeated legacy role cannot be expressed clearly using existing ones.

Potential legacy tokens may include:

- Compact material radius.
- Grouped action radius.
- Legacy outline width.
- Legacy local shadow.
- Opaque accessibility surface.
- Camera-overlay surface.

Do not create tokens for isolated one-off values.

Do not expose legacy implementation details as public product-level concepts.

# 7. Verification Matrix

Test at minimum:

| System | Appearance | Required checks |
|---|---|---|
| iOS 18 | Light | Full legacy baseline |
| iOS 18 | Dark | Full legacy baseline |
| Latest available pre-iOS 26 runtime | Light | Compatibility and visual regression |
| Latest available pre-iOS 26 runtime | Dark | Compatibility and visual regression |
| iOS 26 | Light | Liquid Glass regression check |
| iOS 26 | Dark | Liquid Glass regression check |

Where every pre-iOS runtime is not locally available, prioritize:

1. Minimum deployment target.
2. Latest available pre-iOS 26 runtime.
3. iOS 26 regression runtime.
4. At least one physical device when practical.

## State Matrix

Verify:

- Home empty.
- Home with one card.
- Home with multiple cards.
- Cards selected.
- Catlas selected.
- Settings root.
- Settings pushed destination.
- Capture permission not determined.
- Capture permission denied.
- Capture ready.
- Capture processing.
- Capture recovery.
- Card editor.
- Shared sheet.
- Keyboard visible.
- Large Dynamic Type.
- VoiceOver enabled.
- Reduce Motion enabled.
- Reduce Transparency enabled.
- Increase Contrast enabled.

# 8. Automated and Manual Verification

## Automated Checks

Run the repository’s existing:

- Build checks.
- Unit tests.
- UI tests.
- Snapshot tests, if present.
- Formatting or lint checks.

Add focused tests where the architecture supports them, especially for:

- Persistent tab restoration after capture.
- Re-entrant capture prevention.
- Accessibility labels and selected values.
- Legacy-versus-iOS-26 availability behavior.
- Shared style role resolution.

Do not introduce a large snapshot-testing system solely for this polish pass.

## Manual Visual Checks

Inspect every affected screen for:

- Contrast.
- Material opacity.
- Corner-radius consistency.
- Shadow restraint.
- Safe-area behavior.
- Text wrapping.
- Tab-bar separation.
- Navigation-bar separation.
- Camera-overlay legibility.
- Touch-target spacing.
- Light and dark appearance.
- Accessibility settings.

Capture before-and-after evidence for representative screens.

# 9. Acceptance Criteria

The work is complete when:

- iOS 18 through iOS 25 present a coherent native-material interface.
- iOS 26 Liquid Glass presentation remains visually and behaviorally unchanged.
- Shared fallback issues are resolved at their common source.
- Legacy compact controls generally use restrained geometry and depth.
- Camera controls remain legible over varied live imagery.
- Tab selection is restored correctly after Capture closes.
- Capture cannot be presented multiple times by repeated taps.
- Settings navigation and grouped lists remain clearly separated.
- Dynamic Type does not hide essential actions.
- VoiceOver labels, values, order, and focus restoration are correct.
- Reduce Motion removes nonessential movement without removing feedback.
- Reduce Transparency produces opaque, readable semantic surfaces.
- Increase Contrast improves necessary separation without changing layout.
- Selection and error states do not rely only on color.
- Every interactive control provides at least a `44 × 44 pt` touch target.
- No new custom navigation chrome or imitation Liquid Glass is introduced.
- No card, capture, persistence, Vision, privacy, or storage behavior changes.
- Existing tests pass.
- New focused tests pass.
- Manual regression review is complete in light and dark mode.

# 10. Delivery Boundaries

Implementation should remain narrowly scoped.

Before considering the work complete:

- Review the final diff for unrelated changes.
- Confirm no generated assets or temporary screenshots are accidentally committed.
- Confirm no debugging flags remain enabled.
- Confirm availability checks are not unnecessarily scattered.
- Confirm legacy styling remains centralized.
- Present representative before-and-after captures for approval.
- Report any screen that could not be verified on an available runtime or physical device.
