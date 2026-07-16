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

- Original: redrawn into a normalized raster and re-encoded without source EXIF,
  GPS, TIFF camera/device, orientation, or other source metadata; downsampled
  long edge around 1800px; HEIC quality around 0.72. ImageIO may regenerate
  structural color, pixel, tile, and normalized-orientation properties required
  by the HEIC container, but source photo metadata is not copied.
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
- After the atomic temporary-to-final move, apply
  `FileProtectionType.completeUntilFirstUserAuthentication` to the final UUID
  directory and every stored file. Set and verify `isExcludedFromBackup` on the
  final record directory with URL resource values.
- Keep deletion cleanup explicit: removing a `CatRecord` removes its entire UUID
  image directory, including the sanitized original, cutout, thumbnail, and any
  future associated file. Deleting all cats removes the storage root before
  saving the empty metadata state.
- Once per launch, after SwiftData opens successfully, compare its record IDs
  with immediate, exact canonical UUID directories under the image root. Remove
  unmatched UUID directories as orphans, while ignoring active `.tmp-`
  directories, non-UUID entries, nested entries, and valid record directories.
  Cleanup is actor-serialized; enumeration or removal failures are logged and
  thrown from the store, then logged without blocking app launch.
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
- Keep the active image-processing `Task` cancellable from lifecycle exits and
  expose `Stop and return` after a short delay on the immersive lifting screen.
  Vision's synchronous request may finish in the background, so cancellation
  checks run before and after each request before UI state changes.
- Reset the in-flight session on every exit path: successful Vision handoff,
  import/capture failure, user cancellation, close, and reset.
- Keep expensive image preparation off the main actor. Decode and downsample
  imported/captured images before sending them into Vision or card rendering.
- Keep post-shutter framing consistent across processing, reveal, inspection,
  and save. The photo delegate hands encoded bytes to `CaptureView`, which
  orientation-normalizes and downsamples the complete sensor photograph off-main
  without cropping it to the aspect-fill camera preview. SwiftUI aspect-fits that
  same complete photo throughout the accepted-image flow; do not substitute a
  differently cropped source midway through processing or persistence.
- The rear camera uses the best available AVFoundation virtual device (triple,
  dual-wide, dual, then wide). User-facing zoom factors are translated through
  `displayVideoZoomFactorMultiplier`; discovery, camera locking, and zoom changes
  remain serialized on the session queue. The preview stays visually quiet with
  no preset lens row; pinch zoom remains clamped inside the device range.
- Preserve explicit stage transitions: `camera -> analyzing -> choosingCat` or
  `creatingCutout -> stickerReveal (dusting -> lifting -> settling) ->
  stickerInspecting -> cardCelebrating`.
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
- `FullScreenDustRevealView` owns the aligned photo and background-only Metal
  pass. `SubjectToCardTransitionView` owns the single temporary sticker and its
  measured handoff into the real draft card. Dust erosion and emission share one
  roughly 1.10-second timeline with no separate photo hold or terminal fade.
  The outline appears at about 0.68 seconds, and the card lift begins at about
  0.92 seconds. It overlaps the final dust, lands at about 1.56 seconds, and
  settles by about 1.84 seconds so each stage remains readable.
- Prepare one immutable transition bundle off-main. Its full-canvas aligned
  cutout, background-only image, and softly dilated protection mask share the
  same downsampled dimensions. Inspection and card editing use the matching
  alpha-trimmed sticker and outline-mask canvases so subjects do not inherit
  transparent sensor-frame margins. Release full-canvas transition-resolution
  assets when the transition completes or is cancelled; retain only the
  sanitized original, trimmed sticker, and outline needed by the draft flow.
- `MetalBackgroundDustView` owns `DustParticleRenderer` for exactly one reveal.
  Its representable returns an inactive transparent `MTKView` immediately, then
  prepares immutable Metal textures and pipelines in a cancellable
  user-initiated task before attaching the renderer on the main actor.
  Metal receives only the background-only and subject-protection images; the
  source texture never contains the cat. While setup runs, SwiftUI shows the
  aligned original beneath the one stable temporary sticker. A thread-safe gate reports
  the first frame only after both its
  command buffer succeeds and its drawable's presented handler fires, then
  SwiftUI swaps the placeholder for the Metal layer in a single animation-free
  transaction so preparation never flashes an empty frame. The card choreography
  clock starts from that same first-presented-frame signal, so Metal resource
  preparation cannot consume the dust-only portion of the transition.
  The renderer derives its centered aspect-fit viewport from the texture size
  and its own `drawableSize`; SwiftUI point-space rectangles never cross into
  Metal. Only the aligned photo rect is rendered by Metal. The sampled SwiftUI
  backdrop stays static, and particle fragments are discarded at the photo
  edges, so portrait, landscape, and square imports never animate letterboxed
  or app-background pixels. A directional erosion front uses smoothly
  interpolated turbulence instead of quantized noise cells, while particle
  lifetimes consume the remaining reveal timeline. The softly dilated subject
  mask attenuates particle opacity continuously by inverse protection; only
  effectively fully protected pixels are skipped. This keeps source erosion,
  dust emission, forward-depth growth, and fading in one continuous motion
  without a separate terminal fade. Particle depth is simulated entirely in
  the vertex shader: deterministic speed variation, restrained aspect-correct
  expansion from the photograph center, and unbiased seeded micro-motion grow
  each sprite toward a conservative point-size cap before it fades. There is no
  shared screen-space wind vector, and the photograph and stable cat cutout do
  not scale with the particles.
  Dismantling invalidates late preparation results, stops the display loop, and
  releases the coordinator reference. Setup or draw failures are logged and
  switch to a simple crossfade from the current visible state into the completed
  draft card; no secondary renderer attempts to recreate intermediate particles.
- `DraftCatCardView` reports its actual image-stage anchor in the transition's
  named coordinate space. The temporary mask-outlined sticker maps from the
  padded aspect-fit source crop into that measured destination. The real card's
  cat stays at zero opacity until landing, then an animation-free transaction
  reveals it and removes the temporary sticker atomically. Save and Edit remain
  absent until this handoff and settle are complete. The transition container
  preserves the inspection layout's safe-area geometry; only the photo and Metal
  reveal layer extend behind system chrome. Reduce Motion and disabled
  card motion skip Metal, travel, and spring motion and use a 0.25-second
  crossfade into the identical inspection layout. The completion gate triggers
  one restrained success haptic and one `Cat card ready.` VoiceOver announcement
  at most once on both paths. A capture-owned transition identifier is consumed
  with that handoff so cancellation or a newer capture cannot accept a stale
  completion callback from an outgoing reveal.
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
- source metadata stripping and normalized orientation
- image downsampling/compression
- cutout trimming
- file protection, backup exclusion, and whole-directory deletion cleanup
- launch-time orphan-directory cleanup
- Vision selection/failure handling
- persistence across relaunch

UI tests should cover launch, empty state, capture/import path, editing, deletion, and persistence smoke checks.
