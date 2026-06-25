# CatLocal Design

This file extracts CatLocal's current product and visual design from the app
source, README, and existing docs. It describes what is already true in
the codebase, including iOS 26 native capabilities, accessibility, and dynamic type requirements.

## Product Promise

CatLocal is a private, local-first iPhone journal that turns real cat
encounters into tactile collectible cards.

The product is organized around this loop:

1. Photograph a cat or choose a private photo.
2. Detect and separate the cat with Apple Vision on-device.
3. Reveal a card, choose a design, and add an optional name or note.
4. Save the cat and its images locally with SwiftData and Application Support.

The first screen should privilege the collection and the camera path. Settings,
storage, and privacy proof points support the loop, but they do not replace it.

## Design Direction

The selected visual direction is `Sunlit Gallery Archive`: the restraint of a
contemporary gallery catalogue with the warmth and energy of an Istanbul street
archive.

- Pale mineral and limestone surfaces.
- Ink and deep forest typography.
- Warm apricot and cobalt details used sparingly.
- Personal notes alongside structured metadata.
- Native Liquid Glass tab navigation with camera as the detached primary action.
- Foil light and depth reserved for focused cards.

Native behavior, legibility, and accessibility take priority over matching the
reference image literally.

## Accessibility & Dynamic Type (CRITICAL)

To meet Apple's editorial standards and ensure inclusive design, the UI must gracefully support VoiceOver and Dynamic Type.

1. **Dynamic Type Scaling:**
   - **No Fixed Heights:** Avoid using fixed `.frame(width:height:)` for cards containing text. Use `.frame(maxWidth:maxHeight:)` or `.minHeight` so elements can expand if the user increases system text size.
   - **Relative Font Sizing:** When using custom fonts, bind them to a standard text style (e.g., `font(.custom("FontName", size: 32, relativeTo: .title))`).
   - **Text Wrapping:** Ensure `lineLimit(nil)` or appropriate line wrapping is used on notes and descriptions so text does not clip.

2. **VoiceOver Grouping:**
   - Cards must not be read as disconnected arrays of text. Wrap the `CatCardView` content in `.accessibilityElement(children: .ignore)` and provide a cohesive `.accessibilityLabel` (e.g., "Cat Record, Nori. ID number 013.").
   - Add `.accessibilityHint("Double tap to open full gallery view.")` where appropriate.
3. **Interactive Control Accessibility:**
   - `LiveInteractiveCardView` utilizes `.accessibilityAdjustableAction`. This allows visually impaired users to swipe up/down to tilt the card and feel the haptic feedback, bypassing the visual `DragGesture`.

## Experience Shape

CatLocal's native shape is a capture-to-card pipeline:

- `Camera` and `Choose private photo` start the experience.
- `Looking for cats` and `Lifting the subject` make the on-device processing visible.
- `Which cat should CatLocal save?` appears when multiple cats are detected.
- `Make it yours` turns the cutout into a collectible card.
- `Add Cat` saves the cat privately.
- Home presents saved cats sorted by sequence number.
- `Edit Cat` keeps the focused-cat state editable without leaving the cat context.
- `Catlas` groups saved cats by manual place labels typed by the user.
- Settings explains local-only behavior, Local Storage, and destructive data controls.

## Color System

Use `CatLocalTheme` tokens instead of hardcoded colors.

| Token                            | Light            | Dark                | Role                               |
| -------------------------------- | ---------------- | ------------------- | ---------------------------------- |
| `background` / `limestone`       | `#FDFCF9`        | `#0B0C10`           | App background                     |
| `backgroundGlow`                 | `#FFFFFF`        | `#1E212B`           | Top-left radial glow               |
| `elevatedSurface` / `chalk`      | `#F5F5F7`        | `#16181F`           | Empty states, image stages, inputs |
| `cardSurface`                    | `#FFFFFF`        | `#1C1E26`           | Card and settings surfaces         |
| `primaryText` / `forest` / `ink` | `#0D1117`        | `#F0F2F5`           | Titles and primary content         |
| `secondaryText`                  | `#5C6573`        | `#8B95A5`           | Metadata and supporting text       |
| `separator`                      | `#0D1117` at 8%  | `#F0F2F5` at 12%    | Dividers                           |
| `imageOutline`                   | black at 8%      | white at 12%        | Image/card strokes                 |
| `shadow`                         | `#0D111F` at 12% | black at 55%        | Depth                              |
| `blueAction` / `cobalt`          | `#005EEC`        | `#4A90E2`           | Primary actions                    |
| `warning` / `apricot`            | `#FFA300`        | `#FFBD3D`           | Sunny warnings and warm card tones |
| `sage`                           | `#214D3B`        | `#579174`           | Archive tone and forest accents    |

The app background is layered: a limestone base, a soft top-left radial glow,
and a subtle diagonal sage-to-apricot wash. Avoid flat single-color screens.

## Typography

The app currently uses native SwiftUI system typography with semibold editorial
titles. Do not introduce a new type family without updating the design system.

- App title: `CatLocal`, large native SwiftUI title treatment.
- Settings title: `Settings`, native large navigation title that collapses while scrolling.
- Focused card name: 31pt semibold.
- Thumbnail card name: 18pt semibold.
- Empty-state title: 27pt semibold.
- Eyebrow labels: 12pt semibold with 2.4 tracking, or caption2 bold with 1.8 tracking.
- Sequence marks use bold monospaced digits.

## Layout

Shared screen rhythm:

- Main scroll screens use 22pt horizontal padding.
- Home and settings use 18pt top padding and 140pt bottom padding.
- Card grids use two flexible columns with 14pt column spacing and 18pt row spacing.
- Empty states and settings cards are generous, centered or left-aligned, and bounded by continuous rounded rectangles.

Card geometry:

- Thumbnail cards use an aspect ratio of `0.72`.
- Focused cards use an aspect ratio of `0.64`.
- Thumbnail card corner radius is 22pt.
- Focused card corner radius is 34pt.

## Components

### Native Shell

`RootView` uses a native SwiftUI `TabView` with `.tabViewStyle(.sidebarAdaptable)`.
Tabs are `Home`, `Settings`, and a camera tab. On iOS 26, the camera tab
uses `role: .search` (or `.prominent` where available) so the system renders it as a detached Liquid Glass action.

### Home

The empty state leads with `Meet Your First Cat`, the line `Capture a cat
encounter and keep it private on this iPhone.`, and three proof points:
`No Account`, `No Public Map`, and `No AI Training`.

Saved cats appear under the `Cats` segmented mode and sort ascending by sequence
number. `Catlas` groups the same saved cats by manual place labels without
requesting GPS or storing coordinates.

Home grid thumbnails are intentionally muted with blur/material treatment. The
premium foil and full-fidelity card surface should be revealed in the focused
card, not compete with Home navigation.

### Capture

The camera is full-screen and dark, with camera preview underneath a vertical
black gradient. Controls are icon-first and glass-backed.

### Cards

Cards are polished editorial surfaces with a finite theme set: `Archive`,
`Sunstamp`, `Clear`, `Garden`, `Midnight`, `Apricot`, `Midnight Prism`,
`Gold Leaf`, and `Topographic`.

Theme selection is exposed through a horizontal carousel in capture and editing.
The carousel should feel endless by repeating the style set and recentering near
the ends. It should give a small selection haptic as the centered style changes.

Card text is display-only on the card surface. Names, notes, and Catlas labels
are edited through capture/editor fields, not inline card `TextField`s.

The card number is a plain sequence number, not a padded collectible ID.

### Focused Card

Focused cards are full-screen, immersive, and interactive. They use
`LiveInteractiveCardView` for drag tilt, spotlight, and one-shot boundary
haptics. The supporting label is either `Drag to catch the light` or `Lighting
motion is reduced` when Reduce Motion is enabled.

Premium foil light should be calm at rest and fade in while touched. `Prism`,
`Gold`, and `Topographic` effects belong in focused cards and previews; grid
thumbnails should remain cheap and muted. Topographic must retain visible
contour lines, not just a rainbow gradient.

## Motion And Interaction

- Stage transitions in capture use ease-in-out animation over 0.22s.
- Draft card reveal uses scale from 0.9 combined with opacity.
- Focused card tilt clamps at 12 degrees.
- Drag tilt uses an interactive spring with response 0.25 and damping 0.65.
- The spotlight is a screen-blended radial gradient using white, faint cyan, and clear.
- Foil and spotlight opacity are tied to focused-card interaction state so the card has a quiet baseline before touch.
- Tilt haptics use thresholded selection feedback based on rotation magnitude; avoid continuous buzzing.
- Respect Reduce Motion by disabling tilt and showing the reduced-motion label.
- Preserve the one-shot haptic gate at card tilt limits.

## Privacy And Safety Language

Prefer existing language over new claims:

- `On-device only`
- `This happens entirely on your iPhone.`
- `The selected photo stays on this iPhone`
- `There is no account, public map, advertising identifier, GPS tracking, cloud AI, or model-training upload.`
- `Manual label only. CatLocal does not request GPS or save coordinates.`
