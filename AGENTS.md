# CatLocal Agent Guide

CatLocal is a private, local-first iPhone journal that turns real cat
encounters into tactile collectible cards. The core loop is:

`capture/import -> on-device Vision processing -> transparent cutout -> card reveal/editor -> local collection`

The README leads with this product promise and the four-step flow:
photograph or privately import a cat, detect and separate it with Apple Vision
on-device, reveal/edit a card, then save the card and local image variants with
SwiftData and Application Support. Let that sequence dominate product, design,
and implementation decisions before adding secondary settings or metrics.

## Product Guardrails

- Keep v1 local-only: no accounts, backend, maps, GPS, cloud AI, ads, or social graph.
- Keep cat detection and foreground separation on device with Apple Vision.
- Keep saved images EXIF/GPS-free.
- Preserve the app's quiet, editorial design direction. Use native controls where possible.
- Preserve development team `5SN9TWDXQ4` and existing signing settings.

## Project Structure

- `CatLocal/App/CatLocalApp.swift`: app entry point and SwiftData container setup.
- `CatLocal/App/RootView.swift`: native tab shell, camera sheet routing, and iOS 26 sidebar-adaptable tab behavior.
- `CatLocal/Core/Models/CatRecord.swift`: SwiftData source of truth for card metadata, local image filenames, capture source, sequence, notes, optional Vision bounding box, and card styles (`Archive`, `Sunstamp`, `Clear`, `Garden`, `Midnight`, `Apricot`, `Midnight Prism`, `Gold Leaf`, `Topographic`).
- `CatLocal/Core/Services/CameraController.swift`: camera permission, preview, capture session, and camera error copy.
- `CatLocal/Core/Services/CatImageStore.swift`: Application Support storage, EXIF/GPS stripping, downsampling, HEIC/PNG encoding, thumbnails, storage size, and deletion cleanup.
- `CatLocal/Core/Services/CatVisionProcessor.swift`: on-device Apple Vision cat recognition, foreground mask generation, cutout creation, and Vision error copy.
- `CatLocal/Features/Capture/CaptureView.swift`: primary capture/import flow, processing states, multi-cat selection, card editor, fallback/error handling, and save path.
- `CatLocal/Features/Collection/CollectionView.swift`: default tab, empty state, privacy proof points, collection summary, and card grid.
- `CatLocal/Features/Settings/SettingsView.swift`: privacy/storage explanations, local storage size, destructive deletion, and version copy.
- `CatLocal/Shared/DesignSystem/CatLocalTheme.swift`: semantic dynamic colors, glass helper, background treatment, and editorial title helper.
- `CatLocal/Shared/UI/Card`: card surfaces, focused-card editing, and presentation details.
- `CatLocal/Shared/UI/Effects/LiveInteractiveCardView.swift`: live drag tilt, foil lighting, spring constants, and boundary haptics.
- `CatLocal/Shared/UI/Images/StoredImageView.swift`: local image loading/display helper.
- `CatLocal/Resources`: asset catalogs and bundled resources.
- `CatLocalTests`: unit tests for persistence, storage, Vision helpers, and card logic.
- `CatLocalUITests`: UI smoke tests for launch and primary flows.
- `docs`: architecture, design, and implementation notes.

## Product Goals

- Make the first-use path feel like a camera-first private field journal: `Camera`, `Choose private photo`, `Looking for cats`, `Lifting the subject`, `Make it yours`, and `Add to Collection`.
- Keep the collection organized around real saved cards: `CatRecord.displayName`, plain sequence numbers, capture dates, optional notes, and card styles are the product's native data shape.
- Treat privacy as visible product behavior, not a generic claim: use existing copy such as `On-device only`, `On this iPhone, by design`, `No Account`, `No Public Map`, and `No Model Training`.
- Preserve local data safety: originals, cutouts, and thumbnails stay in Application Support; SwiftData stores metadata and filenames only.
- Keep v1 focused on tactile card collecting rather than discovery, maps, sharing, feeds, accounts, or remote processing.

## Content And Design Grounding

- Before designing UI, read `README.md`, `docs/architecture.md`, `docs/design/README.md`, and the relevant Swift files. The repo is the source of truth.
- Pull product language from existing app strings and docs. Use real labels such as `CatLocal`, `YOUR COLLECTION`, `Meet Your First Local`, `Private import`, `Local storage`, `Edit Card`, `Delete Card`, and `A private field journal for the cats you meet`.
- Do not invent taglines, features, metrics, social claims, map concepts, cloud behavior, testimonials, placeholder cats, or fake sample data that the repo does not already support.
- Inherit the current visual identity: the design note is `Sunlit Gallery Archive`, with pale mineral/limestone surfaces, ink/deep forest typography, sparing warm apricot and cobalt details, personal notes beside structured metadata, native Liquid Glass tab navigation, and foil/depth reserved for focused cards.
- Use `CatLocalTheme` rather than hardcoded colors. Key tokens include limestone/background, chalk/elevated surface, card surface, forest/ink primary text, secondary text, separator, shadow, apricot/warning, and cobalt/blue action.
- Let the product's shape organize screens: capture/import pipeline, Vision processing, transparent cutout, card reveal/editor, local collection, and privacy/storage settings.

## Navigation

The root shell uses SwiftUI `TabView` with `.tabViewStyle(.sidebarAdaptable)` so iOS owns the native Liquid Glass tab bar on iOS 26.

The camera action is represented as a native tab with `role: .search`, because this installed SDK exposes `TabRole.search` but not `TabRole.prominent`. Tapping the camera tab presents `CaptureView` and keeps the previous content tab selected.

Do not reintroduce a custom floating tab bar unless a native API cannot express the behavior.

## Storage And Vision

- `CatImageStore` owns Application Support paths, metadata stripping, downsampling, compression, thumbnails, and deletion cleanup.
- `CatVisionProcessor` owns on-device animal detection and foreground mask/cutout generation.
- `CatRecord` stores SwiftData metadata, optional normalized Vision bounding boxes, and references local image filenames, not remote URLs.

## UI Notes

- `CatLocalTheme` should remain semantic and dynamic for light/dark mode.
- Cards should be polished editorial surfaces, not Liquid Glass blobs.
- Card text is display-only on the card surface. Keep name, note, and Catlas editing in capture/editor fields unless the editing model is intentionally redesigned.
- Home grid thumbnails are deliberately muted with blur/material and wrapped in explicit aspect-ratio hit boxes so they do not steal touches from the `Catlas` segmented control.
- Focused foil and spotlight effects should be calm at rest and fade in while touched. Thumbnail rendering must stay static and cheap.
- The Topographic style is procedural and asset-free: use seeded gradients plus visible contour strokes, not a flat rainbow wash or a heavy per-frame Canvas in scrolling views.
- The card style carousel repeats style cycles to feel infinite and fires a small selection haptic as the centered style changes.
- Liquid Glass belongs on native navigation and compact actions.
- `LiveInteractiveCardView` passes `rotateX`, `rotateY`, and `isInteracting` into card content. It preserves one-shot boundary haptics and thresholded tilt haptics; do not alter the haptic gate or spring constants casually.

## Verification

Preferred validation after code changes:

1. `git diff --check`
2. Build/run the `CatLocal` scheme on an iOS Simulator.
3. Run relevant unit/UI tests when behavior changes.
4. Visually inspect light/dark UI changes when touching design.

After any Simulator build, run, test, or screenshot:

1. Stop the CatLocal app.
2. Shut down every booted Simulator.
3. Confirm no Simulator remains booted.
4. Confirm no `/usr/bin/xcodebuild` process remains active.

When using XcodeBuildMCP, call `session_show_defaults` before build/run/test calls in a fresh session.

## Working Rules

- The worktree may already contain intentional uncommitted product changes. Do not revert user-owned changes.
- Stage only intentional files if asked to commit.
- Keep project organization aligned between filesystem paths and `CatLocal.xcodeproj/project.pbxproj`.
- Prefer small, explicit SwiftUI views and local state over unnecessary view models.
- Add docs when adding a new architectural convention.
