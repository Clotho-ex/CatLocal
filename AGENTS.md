# CatLocal Agent Guide

CatLocal is a private, local-first iOS cat journal. The core loop is:

`capture/import -> on-device Vision processing -> transparent cutout -> card reveal/editor -> local collection`

## Product Guardrails

- Keep v1 local-only: no accounts, backend, maps, GPS, cloud AI, ads, or social graph.
- Keep cat detection and foreground separation on device with Apple Vision.
- Keep saved images EXIF/GPS-free.
- Preserve the app's quiet, editorial design direction. Use native controls where possible.
- Preserve development team `5SN9TWDXQ4` and existing signing settings.

## Project Structure

- `CatLocal/App`: app entry point, root navigation, sheet routing.
- `CatLocal/Core/Models`: SwiftData/domain models.
- `CatLocal/Core/Services`: camera, image storage, Vision processing, and other app services.
- `CatLocal/Features`: feature screens grouped by product area.
- `CatLocal/Shared/DesignSystem`: semantic colors, surfaces, and shared styling tokens.
- `CatLocal/Shared/UI`: reusable UI components grouped by purpose.
- `CatLocal/Resources`: asset catalogs and bundled resources.
- `CatLocalTests`: unit tests for persistence, storage, Vision helpers, and card logic.
- `CatLocalUITests`: UI smoke tests for launch and primary flows.
- `docs`: architecture, design, and implementation notes.

## Navigation

The root shell uses SwiftUI `TabView` with `.tabViewStyle(.sidebarAdaptable)` so iOS owns the native Liquid Glass tab bar on iOS 26.

The camera action is represented as a native tab with `role: .search`, because this installed SDK exposes `TabRole.search` but not `TabRole.prominent`. Tapping the camera tab presents `CaptureView` and keeps the previous content tab selected.

Do not reintroduce a custom floating tab bar unless a native API cannot express the behavior.

## Storage And Vision

- `CatImageStore` owns Application Support paths, metadata stripping, downsampling, compression, thumbnails, and deletion cleanup.
- `CatVisionProcessor` owns on-device animal detection and foreground mask/cutout generation.
- `CatRecord` stores SwiftData metadata and references local image filenames, not remote URLs.

## UI Notes

- `CatLocalTheme` should remain semantic and dynamic for light/dark mode.
- Cards should be polished editorial surfaces, not Liquid Glass blobs.
- Liquid Glass belongs on native navigation and compact actions.
- `LiveInteractiveCardView` preserves one-shot boundary haptics. Do not alter the haptic gate or spring constants casually.

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
