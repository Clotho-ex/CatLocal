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
| `background` / `limestone`       | `#F6F2E8`        | `#101412`           | Warm field-journal background      |
| `backgroundGlow`                 | `#FFF8EA`        | `#24312A`           | Soft sunlit glow                   |
| `elevatedSurface` / `chalk`      | `#ECE4D3`        | `#1B241E`           | Empty states, image stages, inputs |
| `cardSurface`                    | `#FFFDF7`        | `#202820`           | Card and settings surfaces         |
| `primaryText` / `forest` / `ink` | `#1C241F`        | `#F4F0E6`           | Titles and primary content         |
| `secondaryText`                  | `#687169`        | `#AEB7AD`           | Metadata and supporting text       |
| `separator`                      | `#1C241F` at 10% | `#F4F0E6` at 13%    | Dividers                           |
| `imageOutline`                   | `#1C241F` at 13% | `#F4F0E6` at 16%    | Image/card strokes                 |
| `shadow`                         | `#1C241F` at 16% | black at 65%        | Depth                              |
| `blueAction` / `cobalt`          | `#2457A6`        | `#82AFFF`           | Primary actions and selected state |
| `warning` / `apricot`            | `#A64E2D`        | `#F29A6E`           | Warnings and warm card tones       |
| `sage`                           | `#D9E1CF`        | `#1F2A22`           | Archive wash and quiet fill        |
| `information`                    | `#2A6F8F`        | `#7DCAE0`           | Privacy and info symbols           |
| `positive`                       | `#2F7C4F`        | `#91D7A9`           | Success, saved, and place states   |

The app background is layered: a limestone base, a soft top-left radial glow,
and a subtle diagonal sage-to-apricot wash. Cobalt, terracotta, moss, and
Aegean blue are intentionally distinct so actions, warnings, saved states, and
privacy proof points do not compete with one another. Avoid flat single-color
screens and avoid using green as the default action color.

Color attention is semantic and restrained:

- `CatAttentionRole.action`: cobalt for primary actions, selected states, focused interaction hints, and current choices.
- `CatAttentionRole.info`: Aegean teal for privacy proof, on-device processing, storage, and manual/no-GPS education.
- `CatAttentionRole.success`: moss green for saved states, safe privacy outcomes, and completed/place-labeled states.
- `CatAttentionRole.warning`: terracotta for fallback paths, uncertain detection, and recoverable caution.
- `CatAttentionRole.destructive`: red for deletion only. Do not use warning/apricot for permanent deletion.

Each role provides a strong fill, quiet wash, stroke, text color, and strong
foreground color. Prefer those roles over one-off colors so important states
stay recognizable across Home, Capture, Catlas, Settings, and card editing.
Do not turn every semantic color into a bordered badge. CatLocal should use
colored symbols, text, and soft washes first; strokes are reserved for selected,
destructive, or genuinely separated states.

## Typography

The app uses native SwiftUI system typography through `CatTypography` in
`CatLocalTheme.swift`. Do not introduce a new type family without updating the
design system and this document.

- Screen title: large native SwiftUI title treatment for `CatLocal`.
- Moment and page titles: semibold native title styles for capture, reveal, empty state, and failure states.
- Panel and section titles: semibold headline styles for Settings, Catlas, and sheet sections.
- Body, supporting text, metadata, field labels, and compact badges use distinct semantic roles instead of one-off font literals.
- Card names, card dates, place labels, and sequence marks use card-specific roles; sequence marks stay rounded and monospaced.
- Field labels stay quiet and title case. Avoid tiny uppercase tracked eyebrow labels unless a future design system explicitly reintroduces them.

## Layout

Shared screen rhythm:

- Main scroll screens use 22pt horizontal padding.
- Home uses 18pt top padding; Settings can sit slightly tighter beneath the native title.
- Card grids use two flexible columns with 14pt column spacing and 18pt row spacing.
- Empty states and settings panels are generous but should feel baked into the limestone surface, not stacked as bordered cards.

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
`No Account`, `No Public Map`, and `No Model Training`.

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
