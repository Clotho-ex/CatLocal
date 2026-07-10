# CatLocal Design System

## Sea-Glass Field Archive

CatLocal is a private, local-first iPhone journal that turns real cat
encounters into tactile collectible cards. The product loop is:

`capture/import -> on-device Vision -> transparent cutout -> card reveal/editor -> local collection`

Every screen should reinforce that loop before introducing secondary settings,
proof points, or decorative detail. The user's cat cards remain the hero.

## Audience And Purpose

CatLocal is for iPhone users who notice real cats in daily life and want a
private, tactile record of those encounters. It is not a social network, map,
camera utility, cloud organizer, or novelty generator.

The app should feel like a small field archive: personal, local, quiet, and
careful with the user's photos.

## Product Principles

- Lead with the capture-to-card loop: Camera, Choose private photo, Looking for
  cats, Lifting the subject, Make it yours, and Add Cat.
- Make privacy visible through behavior: on-device processing, EXIF/GPS removal,
  local storage, no account, no public map, and no cloud database.
- Keep the interface quiet enough that real saved cards carry the emotion.
- Prefer native iOS controls, navigation, haptics, materials, and accessibility
  behaviors over custom chrome.
- Preserve CatLocal's real data shape: `CatRecord.displayName`, sequence
  numbers, capture dates, optional notes, Catlas labels, and card styles.

## Visual Direction

- Restored archive materials: porcelain, limestone, frosted sea glass, aged
  paper, and subtle ink.
- Warm craft accents: apricot for attention, cobalt for action, restrained
  green for privacy and safety.
- Tactile cards: soft shadows, editorial labels, procedural material effects,
  and calm depth only where the user focuses a card.
- No sample cats, fake metrics, public-map language, account setup patterns, or
  social-feed affordances.
- No heavy glass blobs, dark sci-fi panels, loud gradients, or premium effects
  in scrolling grids.

The reference image `docs/design/sunlit-gallery-archive.png` is a mood target,
not a literal layout spec.

## Experience Shape

- Home opens as the private collection. Empty Home should make the first action
  clear without feeling like a marketing page.
- Capture and private import are equal first-class starts.
- Vision states should use the app's own language and transition explicitly:
  Looking for cats, Lifting the subject, Make it yours, Add Cat.
- Card editing happens in fields beside or around the card, not as inline text
  editing on the card surface.
- Settings explains privacy and storage plainly. It should stay dense,
  practical, and Loci-free except where a future explicit education moment
  warrants it elsewhere.

## Color System

Use `CatLocalTheme` semantic tokens instead of hardcoded colors.

| Role | Use |
| --- | --- |
| `limestone` / app background | Warm page base for the archive feel. |
| `chalk` / elevated surface | Quiet panels, empty states, and grouped content. |
| `cardSurface` | Card faces and tactile collection surfaces. |
| `forest` / `ink` | Primary text and editorial labels. |
| `secondaryText` | Supporting copy, timestamps, and explanatory details. |
| `separator` | Hairline structure and low-contrast borders. |
| `apricot` / warning | Warm attention, camera emphasis, and recoverable warnings. |
| `cobalt` / action | Primary actions and selected controls. |

Attention roles should stay semantic. Use privacy/safety greens for trust,
warning warmth for recoverable problems, and destructive styling only for
explicit destructive actions.

## Typography And Layout

- Use CatLocal's established typography helpers and native Dynamic Type.
- Keep editorial headings compact; reserve hero-scale type for onboarding or
  truly empty states.
- Keep collection and settings layouts scannable. Avoid card-inside-card
  structures and decorative panels that add no product information.
- Give fixed-format UI, card previews, and toolbar controls stable dimensions so
  labels, icons, and motion states do not shift layout.

## Component Guardrails

- `RootView` uses native SwiftUI tabs and iOS 26 Liquid Glass behavior. Do not
  reintroduce a custom floating tab bar without a platform limitation.
- `CollectionView` should keep grid thumbnails cheap, static, and muted until a
  card is focused.
- `CaptureView` owns the first-use product loop and should preserve explicit
  capture, processing, recovery, reveal, edit, and save states.
- `CatCardView` renders display text. Use edit sheets or adjacent fields for
  name, notes, Catlas, and style edits.
- `LiveInteractiveCardView` is the home for focused tilt, foil, and haptics.
  Keep those effects calm at rest and active only while focused or touched.
- `Loci` belongs in targeted state moments: empty collection, recovery,
  warnings, saved-card success, first-time hint education, and explicit privacy
  education.

## Motion And Feedback

- Motion should feel native and meaningful: page transitions, card reveal,
  subtle text transitions, focused-card tilt, and small haptics at important
  moments.
- Avoid continuous sensor work or per-frame effects in scrolling views.
- Respect Reduce Motion and VoiceOver. Important state cannot be communicated by
  animation, color, or mascot pose alone.
- Haptics should mark intent or completion, not every decorative change.

## Privacy Language

Use concrete, behavioral privacy copy:

- No Account
- No Map Tracking
- No Cloud Database
- On-device only
- Nothing leaves your iPhone
- EXIF and GPS removed before storage

Avoid abstract promises such as "secure by design" unless the surrounding copy
names the actual local behavior.
