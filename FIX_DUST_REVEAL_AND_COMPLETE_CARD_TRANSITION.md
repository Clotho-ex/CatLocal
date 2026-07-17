# Fix and Complete the CatLocal Dust-Reveal Transition

## Objective

Review and correct the existing camera, Vision, Core Image, Metal, and persistence implementation on:

```text
codex/fix-camera-dust-reveal
```

The current implementation successfully prepares an aligned cat cutout and performs a Metal-based background dust effect, but it has several correctness, lifecycle, rendering, and transition-completeness issues.

Implement the fixes below without rewriting unrelated parts of the capture pipeline.

---

# Scope

Primary files likely involved:

```text
CatLocal/Core/Services/CameraController.swift
CatLocal/Core/Services/CatVisionProcessor.swift
CatLocal/Features/Capture/CaptureView.swift
CatLocal/Shared/UI/Effects/DustingRevealView.swift
CatLocal/Shared/UI/Effects/DustRevealShaders.metal
CatLocal/Core/Services/CatImageStore.swift
```

Also update or add focused tests where appropriate.

Do not:

- Add third-party libraries.
- Add networking.
- Replace Vision with another segmentation system.
- Rewrite unrelated capture or card-editor UI.
- Raise the deployment target without explicit approval.
- Modify the persistence model unless required for correctness.
- Reformat unrelated files.

---

# Priority 1: Correct the Metal Background Rendering

## Problem

The current Metal background fragment samples the complete source photograph and erodes it:

```metal
float4 source = sourceTexture.sample(
    textureSampler,
    in.textureCoordinate
);
```

The cat is also displayed separately using the aligned transparent cutout.

This means the cat may exist in both:

1. The eroding source texture.
2. The SwiftUI or Metal cutout layer.

Semitransparent fur, whiskers, ears, and alpha edges can therefore be rendered twice, producing:

- Ghosting.
- Thickened fur edges.
- Dark halos.
- Bright halos.
- Visible disagreement between the source and cutout layers.

## Required Fix

The Metal background pass must contain only the photograph background.

Use one of the following approaches.

### Preferred Approach: Generate a Background-Only Image

During Core Image preparation, generate:

```text
backgroundOnly = original × inverse foreground mask
```

Extend the prepared transition assets:

```swift
struct PreparedCaptureCutouts: @unchecked Sendable {
    let background: UIImage
    let reveal: UIImage
    let sticker: UIImage
}
```

Where:

- `background` is the original photograph with the subject removed.
- `reveal` is the full-canvas aligned transparent cat cutout.
- `sticker` is the trimmed and optimized cutout.

Provide `background` to the Metal renderer as the source texture.

This is the preferred implementation because it cleanly separates responsibilities and prevents the shader from needing to classify subject pixels.

### Acceptable Alternative: Mask the Subject Inside Metal

If generating a separate background image would create excessive duplication, update the background fragment to also sample `cutoutTexture`.

Conceptually:

```metal
float4 source = sourceTexture.sample(
    textureSampler,
    in.textureCoordinate
);

float subjectAlpha = cutoutTexture.sample(
    textureSampler,
    in.textureCoordinate
).a;

float backgroundMask = 1.0 - smoothstep(
    uniforms.subjectProtectionLow,
    uniforms.subjectProtectionHigh,
    subjectAlpha
);

source *= backgroundMask;
```

The subject-protection range must preserve soft fur edges.

Do not use a single hard threshold that cuts through whiskers and semitransparent fur.

## Acceptance Criteria

- The cat is rendered only by the dedicated cutout layer.
- No cat silhouette remains in the dissolving background.
- No double-rendered fur is visible.
- No visible seam appears around the cat when the effect begins.
- Dark and light cats both render correctly.

---

# Priority 2: Correct Premultiplied Alpha Output

## Problem

The current fragment reduces alpha without reducing RGB:

```metal
return half4(
    half3(source.rgb),
    half(source.a * survival)
);
```

If the render pipeline uses premultiplied alpha blending, this produces invalid color values and can create bright or dark erosion edges.

## Required Fix

Confirm the alpha convention used by:

- Texture loading.
- Metal fragment output.
- Render pipeline blending.
- `MTKView` pixel format.
- Compositing over SwiftUI.

Prefer premultiplied alpha throughout.

Update the fragment output:

```metal
float outputAlpha = source.a * survival;

return half4(
    half3(source.rgb * survival),
    half(outputAlpha)
);
```

If the source texture is already premultiplied, multiply the complete sampled color by `survival`:

```metal
return half4(source * survival);
```

Do not mix straight-alpha textures with premultiplied blend factors.

## Required Verification

Test the dissolve over:

- Pure white.
- Pure black.
- CatLocal light background.
- CatLocal dark background.
- Light fur.
- Dark fur.
- Semitransparent whiskers.

## Acceptance Criteria

- No glowing erosion border.
- No black fringe.
- No white fringe.
- Particle colors match the source photograph.
- The final transparent output composites correctly in light and dark appearance.

---

# Priority 3: Fix Detached Task Cancellation

## Problem

The implementation uses detached tasks such as:

```swift
let preparationTask = Task.detached(priority: .userInitiated) {
    try CaptureImagePreparation.cutoutImages(from: input.value)
}

guard let prepared = try? await preparationTask.value else {
    return
}
```

Issues:

- Detached work may continue after the capture screen is dismissed.
- Parent cancellation does not automatically guarantee detached-task cancellation.
- `try?` hides real failures.
- The capture state may remain incomplete after a swallowed error.
- Stale processing may overwrite a newer capture.

## Required Fix

Replace silent detached-task handling with structured cancellation.

Example:

```swift
let preparationTask = Task.detached(priority: .userInitiated) {
    try Task.checkCancellation()
    return try CaptureImagePreparation.cutoutImages(
        from: input.value
    )
}

do {
    let prepared = try await withTaskCancellationHandler {
        try await preparationTask.value
    } onCancel: {
        preparationTask.cancel()
    }

    try Task.checkCancellation()

    guard processingGate.isCurrent(sessionID) else {
        return
    }

    selectedBoundingBox = detection?.boundingBox
    revealCutoutImage = prepared.reveal
    cutoutImage = prepared.sticker
    stage = .stickerReveal
} catch is CancellationError {
    return
} catch {
    guard processingGate.isCurrent(sessionID) else {
        return
    }

    fail(with: error)
}
```

If several image-processing operations use detached tasks, prefer introducing a dedicated actor:

```swift
actor CaptureImageProcessor {
    func prepareCutouts(
        from image: UIImage
    ) throws -> PreparedCaptureCutouts {
        try Task.checkCancellation()
        return try CaptureImagePreparation.cutoutImages(from: image)
    }
}
```

## Required State Protection

Before committing any result, verify:

```swift
guard processingGate.isCurrent(sessionID),
      !Task.isCancelled else {
    return
}
```

Cancel the active processing task when:

- The capture screen disappears.
- The user retakes the photo.
- A new import starts.
- The user dismisses the flow.
- The current session identifier changes.

## Acceptance Criteria

- Dismissing the capture screen cancels pending work.
- Starting a second capture prevents the first result from being applied.
- Cancellation does not display an error.
- Real processing errors reach the existing failure UI.
- No capture remains indefinitely stuck in a processing state.

---

# Priority 4: Replace the Unsafe `allInstances` Fallback

## Problem

The current no-detection path uses:

```swift
instances = observation.allInstances
```

When cat detection fails, this can combine:

- A person.
- Furniture.
- Plants.
- Bags.
- Other animals.
- Multiple unrelated foreground objects.

The resulting sticker may not represent a cat.

## Required Fix

Do not automatically combine all foreground instances.

Use this selection order:

1. When a cat detection exists, select the foreground instance with the strongest overlap.
2. When the user has tapped a subject, select the instance containing or closest to that point.
3. Otherwise, score each instance using:
   - Centrality.
   - Mask area.
   - Distance to any low-confidence cat detection.
   - Plausible size.

4. Select one best instance.
5. If no instance is plausible, return `noForeground` or `noMatchingForeground`.
6. Route to the existing no-cat-found or retry flow.

Suggested interface:

```swift
private func selectedForegroundInstances(
    observation: VNInstanceMaskObservation,
    detection: CatDetection?,
    userSelectionPoint: CGPoint?
) throws -> IndexSet
```

Never use `allInstances` unless the user explicitly requests all visible subjects.

## Acceptance Criteria

- No-cat images do not silently create a composite foreground sticker.
- Multiple foreground objects do not automatically merge.
- A failed match produces a recoverable UI state.
- A detected cat remains the preferred foreground object.

---

# Priority 5: Add a Cat Detection Confidence Threshold

## Problem

The current detection accepts every result labeled `Cat`.

Low-confidence detections may cause the wrong foreground instance to be selected.

## Required Fix

Add a configurable confidence threshold:

```swift
private let minimumCatConfidence: VNConfidence = 0.55
```

Filter detections:

```swift
guard label.confidence >= minimumCatConfidence else {
    return nil
}
```

Do not bury the threshold as an unexplained literal.

Use a named configuration value so it can be tuned after testing.

Test values approximately between:

```text
0.50–0.65
```

Do not assume the initial value is final.

## Acceptance Criteria

- Very weak cat detections are rejected.
- Valid cats in ordinary lighting continue to be recognized.
- The threshold is centralized and documented.
- Low-confidence detections do not force incorrect foreground selection.

---

# Priority 6: Serialize All Camera Operations

## Problem

Session setup, starting, and stopping are performed on a private serial queue, but `capturePhoto` is called directly from the main actor:

```swift
photoOutput.capturePhoto(
    with: settings,
    delegate: self
)
```

This can race with:

- Session stopping.
- Configuration.
- Camera switching.
- Lifecycle changes.
- Zoom changes.

## Required Fix

Move capture requests into `CameraSessionCoordinator`.

Add:

```swift
func capturePhoto(
    with settings: AVCapturePhotoSettings,
    delegate: AVCapturePhotoCaptureDelegate
) {
    queue.async { [photoOutput] in
        photoOutput.capturePhoto(
            with: settings,
            delegate: delegate
        )
    }
}
```

Update `CameraController.capture` to call the coordinator.

Do not directly mutate or operate on AVFoundation session objects from multiple queues.

## Acceptance Criteria

All of the following use the same serial queue:

- Session configuration.
- Session start.
- Session stop.
- Photo capture.
- Device zoom configuration.
- Any future camera input switching.

---

# Priority 7: Make Camera Configuration Truly Idempotent

## Problem

The method is named:

```swift
configureIfNeeded()
```

but the shown implementation does not visibly track whether the session has already been configured.

Repeated calls may attempt to add duplicate inputs or outputs.

## Required Fix

Store configuration state inside the coordinator’s serial queue.

Example:

```swift
private var isConfigured = false
private var cachedCapabilities: CameraZoomCapabilities?
```

Then:

```swift
func configureIfNeeded() async throws -> CameraZoomCapabilities {
    try await withCheckedThrowingContinuation { continuation in
        queue.async { [self] in
            if isConfigured,
               let cachedCapabilities {
                continuation.resume(returning: cachedCapabilities)
                return
            }

            // Perform configuration once.
        }
    }
}
```

The configuration state must be owned by the coordinator queue, not the main actor.

## Acceptance Criteria

- Repeated calls do not add duplicate inputs.
- Repeated calls do not add duplicate outputs.
- Repeated calls return the existing zoom capabilities.
- Configuration failures do not leave `isConfigured` set to true.
- The session remains usable after a recoverable failure.

---

# Priority 8: Commit Session Configuration Before Resuming

## Problem

The current code uses:

```swift
session.beginConfiguration()
defer { session.commitConfiguration() }

// ...

continuation.resume(returning: capabilities)
```

The continuation may resume before the deferred commit finishes.

## Required Fix

Do not resume the continuation until after `commitConfiguration()` has completed.

Use explicit control flow:

```swift
session.beginConfiguration()

do {
    // Configure session.

    let capabilities = zoomCapabilities(for: device)

    session.commitConfiguration()

    isConfigured = true
    cachedCapabilities = capabilities

    continuation.resume(returning: capabilities)
} catch {
    session.commitConfiguration()
    continuation.resume(throwing: error)
}
```

Ensure `commitConfiguration()` is always called exactly once after `beginConfiguration()`.

## Acceptance Criteria

- Awaiting callers do not resume before configuration is committed.
- Failed configuration still commits or rolls back cleanly.
- No continuation is resumed more than once.

---

# Priority 9: Correct Per-Capture Quality Configuration

## Problem

The output sets:

```swift
photoOutput.maxPhotoQualityPrioritization = .quality
```

but the individual `AVCapturePhotoSettings` does not visibly request quality prioritization.

## Required Fix

Set the per-capture value:

```swift
let settings = AVCapturePhotoSettings()
settings.photoQualityPrioritization = .quality
```

Verify that the output supports the requested configuration.

For flash:

```swift
if photoOutput.supportedFlashModes.contains(.auto) {
    settings.flashMode = .auto
}
```

Adapt the exact support check to the APIs available for the project’s deployment target.

## Acceptance Criteria

- Each capture explicitly requests the intended quality.
- Unsupported flash modes are not assigned.
- Capture configuration does not crash on devices without flash.

---

# Priority 10: Guarantee Renderer Lifetime

## Problem

The Metal renderer is created as a local variable:

```swift
let renderer = DustParticleRenderer(...)
view.delegate = renderer
```

The implementation must not rely on delegate assignment alone for renderer lifetime.

## Required Fix

Store the renderer strongly in the representable coordinator or hosting controller.

Example:

```swift
final class Coordinator {
    var renderer: DustParticleRenderer?
    var attachmentTask: Task<Void, Never>?
}
```

When resources are ready:

```swift
context.coordinator.renderer = renderer
view.delegate = renderer
```

On teardown:

```swift
static func dismantleUIView(
    _ uiView: MTKView,
    coordinator: Coordinator
) {
    coordinator.attachmentTask?.cancel()
    coordinator.renderer?.stop()
    coordinator.renderer = nil

    uiView.delegate = nil
    uiView.isPaused = true
}
```

## Acceptance Criteria

- The renderer remains alive for the complete transition.
- The renderer is released after dismissal or completion.
- The render loop stops when no longer needed.
- No Metal callbacks occur after teardown.

---

# Priority 11: Make Completion and Failure Mutually Exclusive

## Problem

The renderer has multiple completion paths:

- Normal animation completion.
- Metal setup failure.
- Runtime rendering failure.
- View dismissal.

Without explicit protection, callbacks can run more than once.

## Required Fix

Add a completion state owned by the renderer:

```swift
private enum TerminalState {
    case active
    case completed
    case failed
    case cancelled
}

private var terminalState: TerminalState = .active
```

Provide guarded terminal methods:

```swift
private func completeOnce() {
    guard terminalState == .active else {
        return
    }

    terminalState = .completed
    stopRendering()

    Task { @MainActor in
        onCompleted()
    }
}

private func failOnce(_ error: Error) {
    guard terminalState == .active else {
        return
    }

    terminalState = .failed
    stopRendering()

    Task { @MainActor in
        onFailure(error)
    }
}
```

If the renderer is not isolated to one queue, protect terminal-state mutation appropriately.

## Acceptance Criteria

- `onCompleted` runs at most once.
- `onFailure` runs at most once.
- Completion and failure cannot both run.
- Dismissal does not cause later completion.
- The capture stage advances only once.

---

# Priority 12: Guarantee Animation Start-Time Initialization

## Problem

The draw code contains logic similar to:

```swift
let elapsed = CACurrentMediaTime() -
    (startTime ?? CACurrentMediaTime())
```

If `startTime` is never assigned, progress remains near zero.

## Required Fix

Initialize the render start time exactly once:

```swift
let now = CACurrentMediaTime()

if startTime == nil {
    startTime = now
}

guard let startTime else {
    return
}

let elapsed = now - startTime
```

Prefer setting the start time when the first drawable frame is actually available, not when resources begin loading.

Reset the start time when reusing or restarting the renderer.

## Acceptance Criteria

- Progress advances monotonically.
- The first frame starts at approximately zero.
- Resource-loading time is not counted as animation time.
- The effect reaches completion at the configured duration.

---

# Priority 13: Protect Fur Edges During Particle Emission

## Problem

Particles are emitted wherever:

```metal
cutoutAlpha < uniforms.backgroundAlphaThreshold
```

Soft fur pixels may have low alpha values and be classified as background.

This can cause particles to originate from:

- Whiskers.
- Ear fur.
- Tail fur.
- Semitransparent subject edges.

## Required Fix

Use a subject-protection mask with a soft exclusion range.

Conceptually:

```metal
float subjectProtection = smoothstep(
    uniforms.subjectProtectionLow,
    uniforms.subjectProtectionHigh,
    cutoutAlpha
);

bool canEmitParticle =
    subjectProtection < uniforms.maximumSubjectProtection;
```

Alternatively, create a slightly dilated exclusion mask during Core Image preparation and pass that mask to Metal.

The visual cutout and particle-exclusion mask do not need to be identical:

```text
Visual mask:
Preserve fine fur detail.

Particle protection mask:
Slightly expanded to prevent particles from spawning on fur edges.
```

## Acceptance Criteria

- Particles originate only from the background.
- Whiskers do not disintegrate.
- Fur edges remain stable during the effect.
- The exclusion does not create a visible empty halo around the cat.

---

# Priority 14: Complete the Subject-to-Card Transition

## Problem

The current implementation stops after:

```text
Photo → Dust reveal → Visible cutout
```

The intended effect is:

```text
Photo
→ Background dissolves
→ Cat becomes sticker
→ Cat moves and scales
→ Cat lands in the collectible card
→ Completed card interface appears
```

## Required Fix

Treat the current dust reveal as phase one of a larger transition.

Add an explicit transition phase model:

```swift
enum CaptureRevealPhase: Equatable {
    case idle
    case preparing
    case dusting
    case lifting
    case settling
    case completed
    case failed
}
```

The completed animation should perform:

1. Background dust dissolve.
2. Sticker outline fade-in.
3. Cutout movement from source frame to destination card image frame.
4. Cutout scaling to fit the final card image area.
5. Card surface and metadata fade-in.
6. Small final spring settle.
7. Swap from temporary moving cutout to the real card image.
8. Invoke completion exactly once.

## Destination Geometry

Do not hard-code the card destination coordinates.

Expose the destination card image frame using:

- Anchor preferences.
- A named coordinate space.
- An existing project geometry mechanism.

Example:

```swift
struct CardImageDestinationKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?

    static func reduce(
        value: inout Anchor<CGRect>?,
        nextValue: () -> Anchor<CGRect>?
    ) {
        value = nextValue() ?? value
    }
}
```

Use one named coordinate space for both source and destination geometry.

## Source Geometry

Use the full-canvas reveal cutout to calculate the subject’s visible alpha bounds.

Store normalized bounds:

```swift
struct SubjectRevealGeometry {
    let normalizedBounds: CGRect
    let sourceImageSize: CGSize
}
```

Map those bounds into the displayed source photograph rectangle while accounting for aspect fill.

## Movement

Interpolate one rectangle rather than combining conflicting offsets, frames, and scales:

```swift
func interpolatedRect(
    from source: CGRect,
    to destination: CGRect,
    progress: CGFloat
) -> CGRect
```

Render the cutout inside the interpolated rectangle.

Do not independently animate:

- `position`
- `offset`
- `frame`
- `scaleEffect`

unless each transformation has a clearly separated responsibility.

## Handoff

Prevent two cats from appearing at completion.

Use this sequence:

1. Destination card layout exists behind the moving overlay.
2. Final card cat image begins hidden.
3. Temporary cutout reaches the destination.
4. Final card image becomes visible.
5. Temporary cutout is removed.
6. Transition completes.

## Acceptance Criteria

- The cat does not jump when the lift phase begins.
- The destination coordinates adapt to different device sizes.
- The final card never displays two cats.
- The transition ends in the existing editor or card-inspection screen.
- No parallel navigation system is introduced.

---

# Priority 15: Generate a Sticker Outline

## Required Fix

Generate the outline from the foreground mask.

Use a restrained Core Image dilation such as:

```text
CIMorphologyMaximum
```

Process:

1. Take the subject alpha mask.
2. Expand it slightly.
3. Render CatLocal’s cream or card-surface color through the expanded mask.
4. Place the result behind the transparent cutout.
5. Keep the cutout and outline canvas dimensions identical.

Do not bake shadows into the outline bitmap.

Apply any shadow in SwiftUI.

Use a proportional outline size. Start approximately around:

```text
8–16 pixels at a 1600-pixel long edge
```

Tune visually.

## Acceptance Criteria

- The outline does not clip ears or tail.
- The outline is visible at final card scale.
- The outline does not resemble a thick cartoon border.
- The outline uses CatLocal design tokens.
- Light and dark appearances remain readable.

---

# Priority 16: Shorten and Tune the Animation

## Problem

The current Metal duration is approximately:

```text
2.35 seconds
```

This is likely too slow for a frequently used capture flow.

## Required Fix

Use a total transition target around:

```text
1.0–1.3 seconds
```

Suggested timeline:

| Phase              | Approximate duration |
| ------------------ | -------------------: |
| Dust dissolve      |        `0.60–0.80 s` |
| Outline appearance |  overlaps dust phase |
| Subject lift       |        `0.35–0.50 s` |
| Final settle       |        `0.15–0.22 s` |
| Total              |        `1.00–1.30 s` |

The dust effect and lift may partially overlap.

Use a restrained settle:

```text
1.000 → 1.035 → 1.000
```

Do not create a large bounce.

## Acceptance Criteria

- The transition feels responsive.
- The animation does not feel like a loading screen.
- The result remains readable.
- The final settle is noticeable but restrained.

---

# Priority 17: Preserve Image Color Space

## Problem

The implementation renders using:

```swift
CGColorSpaceCreateDeviceRGB()
```

This may cause visible differences from the original image.

## Required Fix

Use a consistent working color space.

Preference order:

1. Source `CGImage.colorSpace` when suitable.
2. Extended sRGB.
3. Standard sRGB as an explicit fallback.

Example:

```swift
let workingColorSpace =
    image.colorSpace ??
    CGColorSpace(name: CGColorSpace.extendedSRGB) ??
    CGColorSpaceCreateDeviceRGB()
```

Use the same intended color-space handling for:

- Core Image context rendering.
- Metal texture preparation.
- Stored image variants where applicable.

Do not casually convert between Display P3 and untagged device RGB.

## Acceptance Criteria

- The cutout color matches the source photograph.
- No saturation shift appears when the transition begins.
- Metal and SwiftUI layers have matching color appearance.
- Light and dark cats retain correct contrast.

---

# Priority 18: Release Large Temporary Assets

## Problem

The capture flow may simultaneously retain:

- Encoded camera data.
- Prepared image.
- Background-only image.
- Full-canvas cutout.
- Trimmed cutout.
- Metal textures.
- Thumbnail.
- Persistence variants.

## Required Fix

Clear temporary transition assets after completion or cancellation.

Examples:

```swift
revealCutoutImage = nil
backgroundRevealImage = nil
sourceImage = nil
```

The Metal renderer must release:

- Source texture.
- Cutout texture.
- Particle buffers.
- Command resources.
- Any retained `UIImage` or `CGImage`.

Do not clear the final trimmed cutout before persistence or card display completes.

## Acceptance Criteria

- Memory falls after the transition completes.
- Repeated captures do not continuously increase memory.
- Dismissal releases temporary Metal resources.
- Only assets needed by the card editor remain retained.

---

# Priority 19: Add Orphaned File Cleanup

## Problem

The current file-writing flow protects against ordinary thrown errors, but the app can still terminate after the final image directory is moved and before SwiftData persistence completes.

This may leave a directory with no matching `CatRecord`.

## Required Fix

Add a conservative cleanup routine.

At an appropriate maintenance point:

1. Read all stored image directory UUIDs.
2. Read all persisted `CatRecord` UUIDs.
3. Identify directories with no corresponding record.
4. Ignore temporary directories that may still be in use.
5. Remove confirmed orphan directories.

Do not run expensive full-store cleanup during every view render.

Suitable locations:

- App startup after the store is available.
- A background maintenance task.
- A debug or migration utility called once per launch.

## Acceptance Criteria

- Crashed or interrupted saves do not leave permanent orphan directories.
- Valid record directories are never removed.
- Temporary active writes are not removed.
- Cleanup failures do not block app launch.

---

# Priority 20: Review Original Photo Retention

## Problem

The current store writes:

```text
original.heic
cutout.png
thumbnail.png
```

The original photograph may contain:

- People.
- Home interiors.
- Screens.
- Vehicle plates.
- Environmental context.

This may conflict with the intended meaning of “sanitized” even though the data remains on-device.

## Required Action

Do not silently change the product behavior.

Instead:

1. Confirm whether retaining `original.heic` is required for editing or recovery.
2. Document its purpose.
3. Ensure it has appropriate file protection.
4. Keep it out of backups if the existing privacy architecture requires that.
5. Consider deleting it after card creation if it is no longer required.
6. If original retention remains, make sure user-facing privacy language accurately states that the original remains stored locally.

At minimum, add an implementation comment or architecture note explaining why the original is retained.

## Acceptance Criteria

- Original-photo retention is intentional and documented.
- The file uses appropriate on-device protection.
- The privacy description matches actual storage behavior.
- No original image is uploaded.

---

# Reduce Motion Requirements

The existing fallback should remain, but verify the complete transition.

When Reduce Motion is enabled:

- Do not run the particle effect.
- Do not move the subject across a large distance.
- Do not use spring overshoot.
- Crossfade from photograph to final card.
- Keep the duration around `0.20–0.30 seconds`.
- Preserve the same persistence and completion behavior.

The fallback must not skip required state changes.

## Acceptance Criteria

- Reduce Motion reaches the exact same final screen.
- Card creation still completes.
- Completion is triggered once.
- No Metal renderer is started unnecessarily.

---

# Error Handling Requirements

Do not use broad silent patterns such as:

```swift
try?
```

for important processing stages.

Distinguish:

```swift
enum CaptureProcessingError: Error {
    case unreadableImage
    case noCatDetected
    case noMatchingForeground
    case unusableMask
    case cutoutRenderingFailed
    case metalPreparationFailed
    case metalRenderingFailed
    case persistenceFailed
}
```

Cancellation should remain separate from failure.

Expected behavior:

| Condition              | Behavior                                            |
| ---------------------- | --------------------------------------------------- |
| User cancels           | Exit silently                                       |
| No cat detected        | Show no-cat recovery                                |
| No matching foreground | Offer retry or subject selection                    |
| Metal failure          | Use crossfade fallback                              |
| Persistence failure    | Remove newly written image directory and show error |
| Stale session result   | Ignore silently                                     |

---

# Testing Requirements

## Add or Update Unit Tests

### Foreground Selection

Test:

- One detected cat.
- Cat plus person.
- Cat plus furniture.
- Multiple cats.
- No cat detection.
- No overlapping foreground instance.
- User-selected instance.
- Low-confidence cat detection.

### Capture State and Cancellation

Test:

- Old capture result cannot replace a newer capture.
- Dismissal cancels preparation.
- Cancellation does not call failure UI.
- Processing failure clears the active gate.
- Completion runs once.
- Failure runs once.
- Completion and failure cannot both run.

### Camera Configuration

Test or verify:

- Repeated `configureIfNeeded` calls are idempotent.
- The session does not receive duplicate inputs.
- The session does not receive duplicate outputs.
- Configuration state is cached only after success.

### Transition Geometry

Test:

- Portrait source into portrait destination.
- Landscape source into portrait destination.
- Aspect-fill crop offsets.
- Cat near each edge.
- Square image.
- Nonzero coordinate-space origin.
- Destination card size changes.

### Persistence

Test:

- Successful file and SwiftData save.
- SwiftData failure deletes the new image directory.
- Orphan cleanup preserves valid records.
- Orphan cleanup removes unmatched directories.

---

# Manual Verification Matrix

Test the implementation using:

- Light cat on light background.
- Dark cat on dark background.
- Long-haired cat.
- Cat with visible whiskers.
- Cat near the edge.
- Small cat.
- Multiple cats.
- Cat with a person behind it.
- No cat.
- Imported portrait image.
- Imported landscape image.
- Camera capture in portrait.
- Rapid retake.
- Dismissal during Vision processing.
- Dismissal during Metal rendering.
- Reduce Motion enabled.
- Light appearance.
- Dark appearance.
- Repeated captures in one session.
- App relaunch after a successful save.

Inspect specifically for:

- Ghost cat silhouette.
- Double-rendered fur.
- Black or white alpha fringe.
- Particles emitted from the cat.
- Subject jump.
- Incorrect final card placement.
- Two cats during final handoff.
- Animation completion firing twice.
- Memory growth over repeated captures.

---

# Build and Verification Workflow

Before making changes:

```bash
xcodebuild -list
```

Identify the real:

- Workspace or project.
- Scheme.
- Simulator destination.

After each major fix:

1. Build the affected target.
2. Fix compiler warnings introduced by the change.
3. Run focused tests.
4. Run the full test suite.
5. Verify the transition in the simulator.
6. Verify on a physical device when available.

Do not claim completion without running a build.

---

# Completion Criteria

The remediation is complete only when:

- The Metal background does not contain the cat.
- Premultiplied alpha is correct.
- Fur and whisker edges do not glow or darken.
- Detached work cancels correctly.
- Real errors are not silently swallowed.
- Stale capture results cannot update the screen.
- `allInstances` is no longer the automatic fallback.
- Low-confidence cat detections are filtered.
- All AVFoundation operations use the same serial queue.
- Camera configuration is idempotent.
- Session configuration commits before continuations resume.
- Per-capture quality is configured.
- The Metal renderer has an explicit strong owner.
- Renderer completion and failure are one-shot.
- Animation timing initializes correctly.
- Particles are not emitted from the cat.
- The cat moves and scales into the final card.
- A sticker outline appears.
- The final card never shows duplicate cats.
- Reduce Motion uses a complete crossfade fallback.
- Temporary transition assets are released.
- File-orphan cleanup exists.
- Original-image retention is documented and protected.
- New tests pass.
- Existing tests continue to pass.
- No networking or external processing has been added.

---

# Required Completion Report

After implementing the fixes, report:

1. Files created.
2. Files modified.
3. How the background-only texture is generated.
4. How premultiplied alpha is handled.
5. How task cancellation is propagated.
6. How foreground instances are selected without `allInstances`.
7. How camera operations are serialized.
8. How renderer lifetime is retained and released.
9. How the final subject-to-card geometry is calculated.
10. How duplicate subject rendering is prevented at handoff.
11. Build command and result.
12. Test commands and results.
13. Remaining Vision-mask limitations.
14. Any animation constants that still need physical-device tuning.
15. Confirmation that no networking or external image processing was introduced.
