# CatLocal Architecture

CatLocal is a native SwiftUI app with a local-first data model and no server dependency. The architecture is intentionally small: SwiftUI screens coordinate user intent, Core services do camera/Vision/storage work, SwiftData persists card metadata, and Application Support stores sanitized image files.

## Source Layout

```text
CatLocal/
  App/
    CatLocalApp.swift
    RootView.swift
  Core/
    Models/
      CatRecord.swift
    Services/
      CameraController.swift
      CatImageStore.swift
      CatVisionProcessor.swift
  Features/
    Capture/
      CaptureView.swift
    Collection/
      CollectionView.swift
    Onboarding/
      OnboardingView.swift
    Settings/
      SettingsView.swift
  Shared/
    DesignSystem/
      CatLocalTheme.swift
    UI/
      Card/
      Effects/
      Images/
      Loci/
  Resources/
    AppIcon.icon
    Assets.xcassets
    PrivacyInfo.xcprivacy
```

## App Shell

`RootView` owns the app-level navigation state:

- `CollectionView` powers the Home tab.
- `SettingsView` is the secondary tab.
- `CaptureView` is presented as a full-screen cover.
- The camera entry is modeled as a `Tab` with `role: .search` so iOS 26 renders it as the detached right-side Liquid Glass control.

The app uses `.tabViewStyle(.sidebarAdaptable)` rather than a custom tab bar. This keeps navigation aligned with native iOS behavior and gives iOS 26 the system Liquid Glass treatment automatically.

Persisted app preferences use the keys and typed value catalogs in `CatLocalApp.swift`. `RootView` applies appearance, card-motion, and haptic choices through SwiftUI environment values. `CollectionView` persists Home view and sort changes where those controls are used, while `SettingsView` stays focused on app-wide preferences, local storage, privacy, and app information. System Reduce Motion always overrides the in-app Card Motion preference.

## Data Flow

1. The user captures or imports an image in `CaptureView`.
2. `CatVisionProcessor` detects cats and generates a transparent cutout on device.
3. The selected Vision detection bounding box is carried through the editor so the card renderer can center off-axis cats without mutating image bytes.
4. `CatImageStore` writes sanitized, downsampled image variants into Application Support.
5. A `CatRecord` stores metadata, the optional cat bounding box, and local filenames with SwiftData.
6. `CollectionView` queries records and renders cards through shared UI components.

Foreground instance masking runs against the full prepared photo. The selected
cat's detection bounds choose the matching Vision instance, but they must not
crop the image before masking because imperfect detector bounds can omit paws,
tails, or ear tips that the foreground mask would otherwise preserve.

## Persistence

`CatRecord` is the SwiftData source of truth for card metadata:

- nickname
- notes
- capture date
- selected card style
- optional normalized Vision bounding box for card cutout centering
- local filenames for original, cutout, and thumbnail variants

Image bytes are not stored in SwiftData. They live in Application Support so deletion and recompression can be handled by `CatImageStore`.

## Image Storage Policy

Future captures/imports should continue to use optimized local variants:

- Original: EXIF-free, downsampled long edge around 1800px, HEIC quality around 0.72.
- Cutout: transparent PNG, trimmed around non-empty alpha bounds, long edge around 1400px.
- Thumbnail: generated from cutout, long edge around 512px.

Do not add remote image storage, synced photos, GPS coordinates, or automatic
location metadata in v1. Manual Catlas labels are user-entered cat
metadata and stay in SwiftData.

### Storage Safety Guardrails

`CatImageStore` is a privacy and integrity boundary, not just a file helper.
Future storage changes should preserve these invariants:

- Validate local image reads with directory-aware URL containment. Do not use a
  raw string prefix check such as `path.hasPrefix(root.path)`, because sibling
  directories with the same prefix can pass that test.
- Treat file writes and SwiftData metadata saves as one logical transaction.
  If image variants are written but `modelContext.save()` fails, delete the new
  image directory before surfacing the error so Application Support does not
  accumulate orphaned cat files.
- Keep deletion cleanup explicit: removing a `CatRecord` should also remove its
  image directory, and deleting all cats should remove the storage root before
  saving the empty metadata state.
- Add unit coverage for path-containment and rollback behavior whenever
  storage path rules or save ordering changes.

### Capture Pipeline Guardrails

`CaptureView` coordinates camera capture, private photo import, Vision, the
reveal, editor, and persistence. Small state mistakes here can produce duplicate
saves or a stuck first-use flow.

- Gate camera shutter, private import, debug validation import, and cutout retry
  with one session-based in-flight coordinator. Each async operation keeps its
  session ID; completion from a cancelled or superseded session must be a no-op
  so it cannot clear or overwrite a newer retry.
- Keep the active image-processing `Task` cancellable. Analyzing and cutout
  screens expose `Stop and return`, invalidate the active session immediately,
  and preserve the source photo in `processingStopped` with explicit retry and
  retake actions. Vision's synchronous request may finish in the background, so
  cancellation checks run before and after each request before UI state changes.
- Reset the in-flight session on every exit path: successful Vision handoff,
  import/capture failure, user cancellation, close, and reset.
- Keep expensive image preparation off the main actor. Decode and downsample
  imported/captured images before sending them into Vision or card rendering.
- Preserve explicit stage transitions: `camera -> analyzing -> choosingCat` or
  `creatingCutout -> stickerReveal -> stickerInspecting -> cardCelebrating`,
  with `analyzing/creatingCutout -> processingStopped -> analyzing` as the
  cancellation and retry path.
  Avoid implicit fallthrough that lets UI controls from an earlier stage remain
  active while async work is running.

### Reveal And Image Loading Guardrails

The first successful save should feel tactile, but the animation path must not
delay the UI while doing image analysis.

- Do not scan full alpha buffers synchronously in SwiftUI initializers or body
  builders. Compute cutout bounds off-main or start the reveal with fallback
  bounds and update precise bounds asynchronously.
- Timed reveal tasks should always complete even if optional sampling work is
  slow or cancelled. The user must not get stuck waiting for a decorative
  effect.
- `StoredImageView` should keep disk reads and `UIImage(data:)` decoding off
  the main actor, reuse a small cache for repeated local paths, and expose a
  clear placeholder/error state instead of silently hiding failed image loads.

## UI System

`CatLocalTheme` defines semantic dynamic tokens for light and dark mode. Feature screens should consume those tokens instead of hardcoded light colors.

Reusable UI belongs under `CatLocal/Shared/UI`:

- `Card`: card surfaces and focused-card presentation.
- `Effects`: interaction effects such as live drag tilt and motion lighting.
- `Images`: image loading/display helpers.
- `Loci`: restrained mascot state, animation, and placement views.

Keep Liquid Glass restrained:

- Use native iOS 26 glass for tab/navigation and compact actions.
- Keep card collection surfaces tactile and editorial, not glassy.
- Provide iOS 18-25 material/stroke/shadow fallbacks when custom glass is unavoidable.

## Current Card Rendering Handoff

The card renderer now supports the expanded style set:

- `archive`, `sunstamp`, `clear`
- `garden`, `midnight`, `apricot`
- `prism`, `gold`, `topo`
- `topoEmber`, `topoLagoon`, `topoMoss`, `topoDusk`
- `pineShadow`, `cedarShade`, `fernTrace`, `mossVeil`
- `cobaltHalo`, `apricotBeam`, `auroraPool`

Implementation notes from the foil polish pass:

- `LiveInteractiveCardView` passes `rotateX`, `rotateY`, and `isInteracting` into its content closure. Keep this signature when adding focused-card effects.
- Focused foil and spotlight effects are intentionally hidden until touch. Static previews can show foil, but the focused baseline should stay calm.
- `prism` and `gold` use permanent dark base surfaces so blend modes do not wash out in light or dark mode.
- The contour-line family is procedural and asset-free: it uses seeded gradients plus lightweight `Shape` contour strokes. Do not replace it with a heavy per-frame `Canvas` in scrolling contexts. User-facing style titles should use names like `Contour Light`, `Ember Lines`, and `Lagoon Lines`, not implementation shorthand.
- The botanical material family is also procedural and asset-free: `Pine Shadow`, `Cedar Shade`, `Fern Trace`, and `Moss Veil` use lightweight seeded `Shape` strokes plus gradients for branch, frond, and moss-shadow effects.
- The light-effect family (`Cobalt Halo`, `Apricot Beam`, `Aurora Pool`) can lean on gradients, angular glow, and moving light bands without adding bitmap assets.
- `presentation == .thumbnail` must ignore live tilt and stay cheap. Home grid thumbnails are deliberately blurred/material-muted until a card is focused.
- The home grid wraps card buttons in an explicit aspect-ratio hit box. Preserve that wrapper so cards do not steal touches from the `Catlas` segmented control.
- Card style selection uses an infinite-feeling carousel by rendering repeated style cycles and recentering near the ends. Selection haptics fire when the centered style changes.

### Collection Performance Guardrails

Home and Catlas rendering scale with the saved-card count. Keep repeated work
out of hot render paths:

- Derive sorted records, Catlas groups, and animation ID arrays once per body
  path before passing them into `ForEach` or `.animation(value:)`.
- Do not repeatedly sort or filter `@Query` results from several computed
  properties in the same render pass when one local derived value can be reused.
- Keep premium card effects focused-only. Grid thumbnails should use static,
  cheap overlays and local thumbnails rather than full cutout images, live tilt,
  motion sensors, or layered foil effects.
- Avoid compiling unused effect models. If a motion/animation helper is no
  longer referenced, remove it from the project file too so future work does not
  accidentally start continuous sensors or timers.

## Editing Handoff

Card text is not directly editable on the card. The current accepted UX is:

- `CaptureView` shows a draft card preview plus separate nickname, note, and Catlas fields.
- `CatRecordEditSheet` keeps editing in sheet fields.
- `CatCardView` renders card text as display text only.

Avoid reintroducing inline card `TextField`s for cat names unless the editing model is redesigned intentionally.

## Testing Focus

Unit tests should prioritize deterministic behavior and local data safety:

- card style assignment
- EXIF/GPS stripping
- image downsampling/compression
- cutout trimming
- deletion cleanup
- Vision selection/failure handling
- persistence across relaunch

UI tests should cover launch, empty state, capture/import path, editing, deletion, and persistence smoke checks.
