# CatLocal Repository Guide

## Product

CatLocal is a private, local-first iPhone field journal for real cat encounters.

Its primary product loop is:

`capture or import -> on-device cat detection -> foreground cutout -> card editor -> local collection`

Preserve this loop as the center of the product. Secondary features must not weaken its privacy, simplicity, or tactile card-collecting focus.

Before making product, architecture, or design decisions, inspect:

- `README.md`
- `docs/architecture.md`
- `docs/design/README.md`
- the relevant implementation and tests

The repository and current application behavior are the source of truth. Do not rely on stale documentation when it conflicts with working code.

## Non-Negotiable Product Guardrails

- Keep CatLocal local-first and private by default.
- Keep cat recognition, foreground separation, and cutout generation on-device using Apple frameworks.
- Do not introduce accounts, remote AI processing, analytics, advertising, public profiles, social feeds, tracking, GPS collection, or cloud storage unless explicitly requested.
- Do not upload cat photos, cutouts, metadata, notes, or collection records to a remote service.
- Keep app-generated saved and exported image variants free of EXIF, GPS, and unnecessary source metadata.
- Store image files locally in Application Support and persist only their metadata and filenames through SwiftData.
- Preserve existing bundle identifiers, development team, entitlements, signing configuration, deployment targets, and App Store capabilities unless explicitly asked to change them.
- Do not claim that a feature is private, local, anonymous, or on-device unless the implementation actually guarantees it.

## Supported Platform

- The minimum deployment target is iOS 18 unless the project configuration says otherwise.
- Gate APIs introduced after the deployment target with `#available`.
- Provide a behaviorally equivalent fallback where practical.
- Prefer native SwiftUI and Apple platform APIs over custom imitations.
- Preserve native navigation, accessibility, system appearance, Dynamic Type, Reduce Motion, and platform interaction conventions.
- Do not reimplement a system component solely to imitate a newer visual treatment on an older system.

## Architecture Ownership

Use the existing architecture and ownership boundaries.

Important areas include:

- `CatLocal/App`: application entry point, root navigation, dependency setup, and shared environment configuration.
- `CatLocal/Core/Models`: SwiftData models and persistent product data.
- `CatLocal/Core/Services`: camera, Vision, image storage, processing, and infrastructure.
- `CatLocal/Features`: feature-owned screens, state, and workflows.
- `CatLocal/Shared/DesignSystem`: semantic colors, typography, spacing, materials, and reusable styling.
- `CatLocal/Shared/UI`: reusable visual components and card rendering.
- `CatLocal/Resources`: assets, String Catalogs, and bundled resources.
- `CatLocalTests`: unit and integration tests.
- `CatLocalUITests`: UI smoke and workflow tests.
- `docs`: durable architecture and design decisions.

Before creating a new service, model, component, helper, or state container, search for an existing owner.

Prefer:

- small, explicit SwiftUI views;
- focused services with clear responsibilities;
- local state for local presentation behavior;
- shared models only when state must genuinely be shared;
- value types and typed state over loosely structured dictionaries or flags.

Do not add a view model, coordinator, repository layer, protocol, or abstraction only because the pattern is common elsewhere.

## Persistence and Data Safety

Treat local collection data as user-owned and irreplaceable.

- `CatRecord` and the current SwiftData schema are the source of truth for card metadata.
- Store file references as controlled local filenames or relative identifiers, not arbitrary absolute paths or remote URLs.
- Validate local paths with directory-aware URL containment. Never use a naive string-prefix check.
- Treat writing image files and saving the SwiftData record as one logical transaction.
- If metadata persistence fails after files are written, remove newly created files and restore a consistent state.
- If file persistence fails, do not insert a success-shaped SwiftData record.
- When deleting a record, clean up all owned original, cutout, thumbnail, and derivative files.
- Do not delete files outside the record's validated storage directory.
- Preserve existing records when changing the SwiftData schema.
- Add an appropriate migration path for persistent-model changes.
- Do not rename persisted fields, enum raw values, filenames, directories, or `AppStorage` keys without considering migration and backward compatibility.
- Surface storage failures through the app's established user-facing and diagnostic paths.
- Do not silently swallow migration, optimization, deletion, or cleanup failures.

Add or update tests for:

- path traversal and path containment;
- partial-save rollback;
- deletion cleanup;
- schema migration;
- invalid or missing files;
- image metadata stripping;
- filename normalization.

## Image and Vision Processing

- `CatVisionProcessor` owns cat detection, foreground masking, and cutout generation.
- `CatImageStore` owns image persistence, metadata stripping, resizing, encoding, thumbnails, storage paths, and cleanup.
- Keep file I/O, full-image decoding, resizing, alpha-bound scanning, and Vision requests off the main actor.
- Return to the main actor only for UI state changes and model-context work that requires it.
- Avoid decoding full-resolution images when a thumbnail or downsampled representation is sufficient.
- Preserve alpha when processing cutouts.
- Handle image orientation correctly.
- Bound memory use for large camera and photo-library images.
- Do not add remote-processing fallbacks when local Vision processing fails.
- Present a clear recoverable failure state instead.

## Capture State Machine

The capture and import workflow must remain deterministic.

- Allow only one capture, import, validation, or image-processing operation in flight.
- Repeated taps must not start overlapping operations or replace an active completion handler.
- Reset the in-flight state on success, failure, cancellation, dismissal, close, and explicit reset.
- Represent meaningful workflow stages explicitly rather than inferring them from unrelated booleans.
- Preserve clear transitions between acquisition, analysis, cutout generation, cat selection, reveal, editing, saving, success, and failure.
- Do not let optional decorative work block saving or the first-card reveal.
- Begin reveals with safe fallback geometry and refine optional bounds asynchronously.
- Cancellation must leave the app in a valid reusable state.
- Saving must be idempotent from the user's perspective: one confirmed save action must create no more than one record.

Add or update tests when changing:

- capture/import mutual exclusion;
- cancellation and reset behavior;
- repeated taps;
- multi-cat selection;
- save idempotency;
- first-save reveal completion;
- processing failures;
- photo-library and camera permission handling.

## Localization

All user-facing content must remain localizable.

- Use the project's String Catalog and existing localization helpers.
- Use localizable SwiftUI string literals for compiler-extracted copy and the existing localization helpers for dynamic or runtime-resolved strings. Do not render user-visible runtime `String` values verbatim when that would bypass the String Catalog.
- Localize screen text, buttons, menus, alerts, errors, empty states, accessibility labels, accessibility values, accessibility hints, card-style names, dynamic lookup strings, and notification copy.
- Maintain every locale currently present in the String Catalog. The current supported set is English and Turkish.
- Preserve automatic iOS language resolution. For supported non-English system languages, Settings offers only the English fallback; while that override is active, the same control returns the app to the system language. Do not reintroduce the full language picker unless explicitly requested.
- Do not bypass the selected app language with direct `Bundle.main` assumptions or unscoped localization lookups.
- Use plural rules for counted content.
- Do not construct sentences by concatenating independently translated fragments.
- Preserve interpolation placeholders and argument ordering across locales.
- When adding or changing a localization key, update every supported locale.
- Do not replace reviewed translations with machine-generated copy without explicitly identifying that the translations require native-speaker review.
- Treat missing translations, untranslated accessibility copy, broken placeholders, and stale live keys as defects.

## Accessibility

- Every interactive element must have an appropriate accessible name.
- Add accessibility hints only when the action is not apparent from the label.
- Ensure custom controls expose correct roles, values, selected states, and enabled states.
- Keep decorative imagery hidden from accessibility.
- Support Dynamic Type without truncating critical information or breaking layouts.
- Preserve logical VoiceOver order.
- Do not rely solely on color, blur, animation, gesture, or haptic feedback to communicate state.
- Ensure controls have practical touch targets.
- Respect Reduce Motion and Reduce Transparency where applicable.
- Keep camera, card editing, segmented controls, menus, deletion, and success/error flows operable with VoiceOver.

## Design System

Preserve CatLocal's quiet, premium, editorial visual language.

- Use semantic tokens from `CatLocalTheme`.
- Do not hardcode light-mode or dark-mode colors in feature views.
- Preserve the current sea-glass, limestone, forest, apricot, cobalt, and card-surface relationships unless a redesign is explicitly requested.
- Use Liquid Glass and native materials selectively for navigation and compact controls.
- Cards should remain tactile editorial objects, not generic glass panels.
- Reserve rich foil, glint, depth, and spotlight effects for focused or interactive card presentation.
- Keep collection-grid thumbnails static and inexpensive.
- Use thumbnail image variants in grids rather than full-resolution originals.
- Avoid live motion sensors, continuous animation, expensive per-frame canvases, and full premium effect stacks in scrolling collections.
- Keep effects calm at rest and progressively visible during direct interaction.
- Preserve established card proportions, corner treatment, metadata hierarchy, and interaction behavior unless intentionally redesigning the card system.
- Use existing Loci mascot assets and state mappings consistently. Do not invent unrelated mascot designs, props, poses, or personality changes during ordinary feature work.

Do not invent unsupported:

- product features;
- social claims;
- maps or location behavior;
- cloud behavior;
- fake metrics;
- testimonials;
- placeholder user collections;
- sample cats presented as user data;
- privacy claims not backed by implementation.

## Performance

- Keep collection scrolling responsive with realistic collection sizes.
- Avoid repeated sorting, filtering, grouping, or identity generation within the same render path.
- Compute derived collection data once at the appropriate level.
- Cache or reuse decoded thumbnails where the existing architecture permits it.
- Do not perform synchronous disk reads or image decoding during ordinary SwiftUI body evaluation.
- Avoid broad observable dependencies that cause unrelated views to redraw.
- Keep animation identity stable.
- Preserve existing haptic thresholds, interaction gates, and spring behavior unless changing them is part of the task.
- Profile before introducing complex performance-specific architecture.

## Error Handling

- Use typed errors or established domain errors where practical.
- Preserve the underlying cause for diagnostics.
- Map technical failures to clear, human user-facing messages at the feature boundary.
- Do not add empty `catch` blocks.
- Do not convert failures into false success states.
- Do not use broad fallback behavior that can save incomplete, invalid, or privacy-compromised data.
- Recover gracefully where a retry, cancellation, reset, or alternate local input is available.

## Project Hygiene

- Keep filesystem organization and `CatLocal.xcodeproj/project.pbxproj` aligned.
- When adding, moving, renaming, or deleting source files, confirm the Xcode project references remain correct.
- Remove obsolete source files, project references, tests, assets, previews, and helpers when replacing an implementation.
- Do not leave dormant sensor, timer, animation, or image-processing implementations compiled into the target as speculative future code.
- Do not edit generated files manually.
- Avoid unrelated formatting or project-file churn.
- Preserve user-owned worktree changes.

## Documentation

Update documentation when introducing or changing:

- persistent data contracts;
- storage layout;
- architectural ownership;
- capture-state-machine behavior;
- privacy guarantees;
- localization architecture;
- a reusable design-system convention;
- a non-obvious performance constraint.

Do not copy volatile implementation inventories into `AGENTS.md`.

Keep this file focused on durable rules. Put detailed feature behavior in code, tests, or the relevant document under `docs`.

## Verification

After code changes, run the relevant available checks.

At minimum:

1. Inspect the affected code and tests.
2. Run `git diff --check`.
3. Build the `CatLocal` scheme for an available iOS Simulator.
4. Run focused unit tests for changed behavior.
5. Run broader tests when the change affects shared infrastructure or primary workflows.
6. Inspect the final diff for accidental or unrelated changes.

Use:

```bash
xcodebuild -project CatLocal.xcodeproj -scheme CatLocal -showdestinations
```

Select an available simulator destination rather than assuming a particular installed device.

For UI changes, also inspect:

- light appearance;
- dark appearance;
- relevant Dynamic Type sizes;
- VoiceOver behavior where interaction changed;
- Reduce Motion behavior where animation changed;
- empty, loading, success, failure, and populated states;
- narrow and wide supported device sizes.

For privacy, storage, Vision, capture, or persistence changes, test the relevant failure and cancellation paths rather than only the successful path.

If a required test cannot run because of unavailable SDKs, simulator runtimes, permissions, hardware, credentials, or services, state the limitation explicitly.

After Simulator build, run, test, or screenshot work:

1. Stop CatLocal.
2. Shut down every simulator booted for the task.
3. Confirm no simulator remains booted.
4. Confirm no task-owned `xcodebuild` process remains active.

When using XcodeBuildMCP in a fresh session, inspect or establish the session defaults before build, run, test, or screenshot commands.

## Review Guidelines

During code review, prioritize:

- privacy or local-only regressions;
- image metadata leakage;
- unvalidated local paths or path traversal;
- data loss and incomplete-save states;
- orphaned image files;
- SwiftData migration problems;
- overlapping capture or import operations;
- main-thread Vision, decoding, or file I/O;
- unsafe concurrency or actor isolation;
- broken cancellation;
- duplicate record creation;
- unlocalized user-facing or accessibility copy;
- accessibility regressions;
- expensive thumbnail rendering;
- repeated image decoding;
- incorrect project-file references;
- signing, entitlement, or deployment-target changes;
- missing regression tests for changed invariants.

Treat cosmetic preferences as findings only when they violate the established design system, platform behavior, accessibility requirements, or an explicit task requirement.

## Definition of Done

A change is complete only when:

- the requested behavior is implemented across every affected surface;
- privacy and local-only guarantees remain intact;
- persistence and cleanup remain consistent;
- localization is complete for every supported locale;
- accessibility behavior is preserved or improved;
- relevant tests pass;
- the app builds for an available simulator;
- UI changes have been visually inspected where feasible;
- the final diff contains no accidental changes;
- any validation limitation is reported clearly.

Do not commit, push, open a pull request, deploy, publish, or alter signing unless the user explicitly requests it.
