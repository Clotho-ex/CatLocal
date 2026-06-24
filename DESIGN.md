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
4. Save the card and its images locally with SwiftData and Application Support.

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
- `Which cat gets the card?` appears when multiple cats are detected.
- `Make it yours` turns the cutout into a collectible card.
- `Add to Collection` saves the card privately.
- `YOUR COLLECTION` presents saved cards sorted by recent capture.
- `Edit Card` keeps the focused-card state editable without leaving the card context.
- `Memory Atlas` groups saved cards by manual place labels typed by the user.
- `PRIVACY & STORAGE` explains local-only behavior and destructive data controls.

## Color System

Use `CatLocalTheme` tokens instead of hardcoded colors.

| Token                            | Light            | Dark                | Role                               |
| -------------------------------- | ---------------- | ------------------- | ---------------------------------- |
| `background` / `limestone`       | `#F2EDE4`        | `#121413`           | App background                     |
| `backgroundGlow`                 | `#FAF8F5`        | `#1C1E1D`           | Top-left radial glow               |
| `elevatedSurface` / `chalk`      | `#E6DFD3`        | `#1C1E1D`           | Empty states, image stages, inputs |
| `cardSurface`                    | `#FAF8F5`        | `#262927`           | Card and settings surfaces         |
| `primaryText` / `forest` / `ink` | `#1A2F25`        | `#8FA89B`           | Titles and primary content         |
| `secondaryText`                  | `#6E6A61`        | `#91948F`           | Metadata and supporting text       |
| `separator`                      | `#1A2F25` at 12% | `#8FA89B` at 16%    | Dividers                           |
| `imageOutline`                   | black at 10%     | white at 10%        | Image/card strokes                 |
| `shadow`                         | `#1A2F25` at 16% | black at 45%        | Depth                              |
| `blueAction` / `cobalt`          | RGB `0, 0.32, 1` | RGB `0.30, 0.58, 1` | Primary action and Clear style     |
| `warning` / `apricot`            | `#D95B32`        | `#FF7A59`           | Warnings and Sunstamp style        |
| `sage`                           | `#1A2F25`        | `#8FA89B`           | Background wash and Archive tone   |

The app background is layered: a limestone base, a soft top-left radial glow,
and a subtle diagonal sage-to-apricot wash. Avoid flat single-color screens.

## Typography

The app currently uses native SwiftUI system typography with semibold editorial
titles. Do not introduce a new type family without updating the design system.

- App title: `CatLocal`, 42pt semibold via `catEditorialTitle`.
- Settings title: `Settings`, 40pt semibold via `catEditorialTitle`.
- Focused card name: 31pt semibold.
- Thumbnail card name: 18pt semibold.
- Empty-state title: 27pt semibold.
- Eyebrow labels: 12pt semibold with 2.4 tracking, or caption2 bold with 1.8 tracking.
- Sequence marks use bold monospaced digits.

## Layout

Shared screen rhythm:

- Main scroll screens use 22pt horizontal padding.
- Collection and settings use 18pt top padding and 140pt bottom padding.
- Card grids use two flexible columns with 14pt column spacing and 18pt row spacing.
- Empty states and settings cards are generous, centered or left-aligned, and bounded by continuous rounded rectangles.

Card geometry:

- Thumbnail cards use an aspect ratio of `0.72`.
- Focused cards use an aspect ratio of `0.67`.
- Thumbnail card corner radius is 22pt.
- Focused card corner radius is 34pt.

## Components

### Native Shell

`RootView` uses a native SwiftUI `TabView` with `.tabViewStyle(.sidebarAdaptable)`.
Tabs are `Collection`, `Settings`, and a camera tab. On iOS 26, the camera tab
uses `role: .search` (or `.prominent` where available) so the system renders it as a detached Liquid Glass action.

### Collection

The empty state leads with `Meet Your First Local`, the line `Capture a cat
encounter and keep the card private on this iPhone.`, and three proof points:
`No Account`, `No Public Map`, and `No Model Training`.

### Capture

The camera is full-screen and dark, with camera preview underneath a vertical
black gradient. Controls are icon-first and glass-backed.

### Cards

Cards are polished editorial surfaces. Card styles:

- `Archive`: card surface with a subtle white-to-sage diagonal gradient.
- `Sunstamp`: card surface with a warm apricot radial glow.
- `Clear`: card surface with a light cobalt gradient.

### Focused Card

Focused cards are full-screen, immersive, and interactive. They use
`LiveInteractiveCardView` for drag tilt, spotlight, and one-shot boundary
haptics. The supporting label is either `Drag to catch the light` or `Lighting
motion is reduced` when Reduce Motion is enabled.

## Motion And Interaction

- Stage transitions in capture use ease-in-out animation over 0.22s.
- Draft card reveal uses scale from 0.9 combined with opacity.
- Focused card tilt clamps at 12 degrees.
- Drag tilt uses an interactive spring with response 0.25 and damping 0.65.
- The spotlight is a screen-blended radial gradient using white, faint cyan, and clear.
- Respect Reduce Motion by disabling tilt and showing the reduced-motion label.
- Preserve the one-shot haptic gate at card tilt limits.

## Privacy And Safety Language

Prefer existing language over new claims:

- `On-device only`
- `This happens entirely on your iPhone.`
- `The selected photo stays on this iPhone`
- `There is no account, public map, advertising identifier, GPS tracking, cloud AI, or model-training upload.`
- `Manual label only. CatLocal does not request GPS or save coordinates.`
