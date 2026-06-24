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
    Settings/
      SettingsView.swift
  Shared/
    DesignSystem/
      CatLocalTheme.swift
    UI/
      Card/
      Effects/
      Images/
  Resources/
    Assets.xcassets
```

## App Shell

`RootView` owns the app-level navigation state:

- `CollectionView` is the default tab.
- `SettingsView` is the secondary tab.
- `CaptureView` is presented as a full-screen cover.
- The camera entry is modeled as a `Tab` with `role: .search` so iOS 26 renders it as the detached right-side Liquid Glass control.

The app uses `.tabViewStyle(.sidebarAdaptable)` rather than a custom tab bar. This keeps navigation aligned with native iOS behavior and gives iOS 26 the system Liquid Glass treatment automatically.

## Data Flow

1. The user captures or imports an image in `CaptureView`.
2. `CatVisionProcessor` detects cats and generates a transparent cutout on device.
3. `CatImageStore` writes sanitized, downsampled image variants into Application Support.
4. A `CatRecord` stores metadata and local filenames with SwiftData.
5. `CollectionView` queries records and renders cards through shared UI components.

## Persistence

`CatRecord` is the SwiftData source of truth for card metadata:

- nickname
- notes
- capture date
- deterministic card style
- local filenames for original, cutout, and thumbnail variants

Image bytes are not stored in SwiftData. They live in Application Support so deletion and recompression can be handled by `CatImageStore`.

## Image Storage Policy

Future captures/imports should continue to use optimized local variants:

- Original: EXIF-free, downsampled long edge around 1800px, HEIC quality around 0.72.
- Cutout: transparent PNG, trimmed around non-empty alpha bounds, long edge around 1400px.
- Thumbnail: generated from cutout, long edge around 512px.

Do not add remote image storage, synced photos, GPS coordinates, or automatic
location metadata in v1. Manual Memory Atlas labels are user-entered card
metadata and stay in SwiftData.

## UI System

`CatLocalTheme` defines semantic dynamic tokens for light and dark mode. Feature screens should consume those tokens instead of hardcoded light colors.

Reusable UI belongs under `CatLocal/Shared/UI`:

- `Card`: card surfaces and focused-card presentation.
- `Effects`: interaction effects such as live drag tilt and motion lighting.
- `Images`: image loading/display helpers.

Keep Liquid Glass restrained:

- Use native iOS 26 glass for tab/navigation and compact actions.
- Keep card collection surfaces tactile and editorial, not glassy.
- Provide iOS 18-25 material/stroke/shadow fallbacks when custom glass is unavoidable.

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
