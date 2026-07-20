# CatLocal Localization Correction Report

Date: 2026-07-17

## Status

The engineering correction is complete for English and Turkish. CatLocal follows the iOS preferred language automatically when it resolves to Turkish; every other unsupported language falls back to English. The former all-language Settings picker is removed. Turkish configurations receive one English fallback button that becomes `Use System Language` while English is active. Yusufcan Var began the native-speaker physical-device review on July 20, 2026. Approval remains open until the corrections below are confirmed in the next TestFlight build.

## Release Review Update — July 20, 2026

Yusufcan Var tested TestFlight build `1.0 (2)` on a physical iOS 26 device. The
manual foreground fallback correctly rejected images without cats. During the
Turkish review, four live labels still appeared in English because their exact
case-sensitive dynamic lookup keys were absent from the String Catalog:

- Catlas `Unplaced` group and route title -> `Anı Yeri Olmayanlar`;
- `Card Design` and `Card design` -> `Kart Tasarımı`;
- `Name the Cat` -> `Kedinin Adı`;
- `Encounter Note` -> `Karşılaşma Notu`.

The missing keys were added with translator context and locked by unit and
catalog-validator expectations. Current verification:

- Catalog validator: 332 keys, 2 languages, 13 plural entries, 0 stale entries.
- Unit target: 155 tests passed on an iOS 26 simulator.
- Release simulator build: succeeded with zero warnings and errors.
- Compiled Turkish `Localizable.strings`: all five exact lookup variants resolve
  to the reviewed Turkish values above.

Build `1.0 (2)` predates these catalog corrections. The native review remains
open until the corrected next build is installed and the Catlas, new-cat
editor, and existing-cat editor surfaces are confirmed on the physical device.

## Catalog Correction

- The initial catalog contained 203 keys, including 144 entries marked stale.
- The stale audit classified 34 entries as live/compiler-extractable, 109 as live/manual-dynamic, and one as unused.
- The final catalog contains 288 keys: 241 intentional manual entries, 47 compiler-current entries, 13 plural entries, both supported locales, and zero stale entries.
- The larger final catalog is intentional: it adds previously unlocalized VoiceOver labels, values, hints, dynamic card-style titles, and other selected-language runtime strings.
- Every retained manual key has at least one exact app-source call site. The audit classifies 119 manual keys for accessibility use, 165 for dynamic runtime lookup, and 59 for visible UI; classifications can overlap.
- Superseded English copy, obsolete pre-plural count formats, and the unused standalone `First Local`, `Storage used`, and `Yours` keys were removed only after call-site verification. `Storage used` was the only unused manual entry found in the final 243-entry audit.
- Ten strings belonging only to the retired all-language picker were removed. Only the English and Turkish locale resources remain bundled.
- Case-only duplicates were consolidated into `Edit Before Saving`, `On this iPhone`, and `Preparing cat card`. The removed variants are absent from both the catalog and the final Xcode localization export.
- `docs/localization-catalog-audit.md` records every repaired, removed, intentionally manual, and accessibility-native-review entry.

## Copy, Formatting, And Privacy

- English now consistently describes cats, collectible cards, on-device background removal, the private field journal, and collection storage.
- Multi-argument strings use positional placeholders so translators may reorder values.
- All 13 count families pass integers through String Catalog plural rules. Unit coverage exercises every family across both locales at `0, 1, 2, 3, 4, 5, 11, 12, 21, 22, 25, 101` (312 plural assertions).
- Locale category coverage is English `one/other` and Turkish `other`.
- Privacy translations preserve on-device processing, no GPS request for Catlas, metadata removal, protected local storage, backup exclusion, deletion with the cat, and no account/upload/cloud AI/model-training use.
- Translator comments distinguish typed Memory Places from GPS coordinates, collectible cards from payment cards, and style families from groups of cats.
- Turkish now uses title capitalization for multi-word headings and controls, including `Kart Hareketi`, `Dokunsal Geri Bildirim`, `Yerel Depolama`, `Gizlilik Özeti`, and related titles. Explanatory sentences remain in sentence case.

## Language Behavior

- On first launch, CatLocal uses the iOS preferred app/device language.
- The Settings language control is hidden when iOS resolves CatLocal to English or to an unsupported language that falls back to English.
- Turkish configurations show the localized `Use English` action. Selecting it applies and persists an English-only CatLocal override.
- While that override is active, the same row becomes `Use System Language`. Selecting it clears the override and returns CatLocal to whichever supported language iOS resolves.
- Bulgarian, Romanian, Polish, Ukrainian, Greek, Croatian, and every other unsupported configuration resolve to English and do not show the fallback row.
- No custom picker lists the available languages; iOS remains the source of truth for the system-language selection.

## Duplicate Call Sites

- `CatLocal/Features/Capture/CaptureView.swift:1400` and `:1524` now use `Preparing cat card` for the save-state accessibility label.
- `CatLocal/Features/Capture/CaptureView.swift:1445` now uses `Edit Before Saving` for the editor accessibility label.
- `CatLocal/Features/Settings/SettingsView.swift:370` now uses `On this iPhone` for the local-storage heading.
- `CatLocalTests/CatLocalCoreTests.swift` verifies the canonical keys and guards against reintroducing all four removed keys, including unused `Storage used`.

## Layout And Accessibility Corrections

- Settings controls yield space to long localized labels; storage rows switch to a vertical layout when needed.
- Onboarding scrolls on compact-height and accessibility Dynamic Type configurations while keeping its actions reachable.
- The capture editor now keeps its save action in a bottom safe-area action region, so long localized content and accessibility text sizes cannot strand the user above an unreachable action.
- VoiceOver labels, values, and hints now resolve through the app-selected locale instead of bypassing the language switch.
- Card-style names and dynamic status/error strings follow the selected locale.
- Runtime UI tests use stable identifiers rather than English copy, allowing the same import, detection, recovery, editor, deletion-confirmation, Settings, privacy, storage, and destructive-confirmation checks to run in every locale.

## Verification Evidence

- Catalog validator: 288 keys, 2 languages, 13 plural entries, 0 stale entries.
- String Catalog compiler: `xcstringstool compile --dry-run` emits only `en.lproj` and `tr.lproj`.
- Unit suite: 146 tests passed on iOS 18.0, including 312 plural assertions, supported preferred-language detection, removed-language fallback behavior, and English/System selection coverage.
- Focused compact iPhone SE / iOS 18 UI suite: 6 tests passed for English and Turkish galleries, Turkish camera-denied recovery, the English/System fallback control, and unsupported Bulgarian and Ukrainian configurations falling back to English without a language control.
- Existing functional tests retain responsibility for persistence after destructive confirmation; localization runtime tests stop at the confirmation boundary.
- `git diff --check` passes.

Current result bundles are stored outside the repository:

- `/Users/prometheus/Library/Developer/XcodeBuildMCP/workspaces/CatLocal-852cddff5c10/result-bundles/test_sim_2026-07-17T20-45-46-951Z_pid88788_63c51119.xcresult`
- `/Users/prometheus/Library/Developer/XcodeBuildMCP/workspaces/CatLocal-852cddff5c10/result-bundles/test_sim_2026-07-17T20-46-31-561Z_pid88788_7068a61e.xcresult`

## Native Review Queue

Native-speaker review has not been completed and remains a release gate for Turkish. Reviewers should check the full catalog and prioritize:

1. Privacy/security wording, especially first-unlock timing, file protection, metadata removal, no GPS request, no upload/cloud/model-training claims, and destructive actions.
2. The 13 count families across the tested counts.
3. Collectible-card, typed Memory Place, Catlas, background-removal, and card-style-family terminology.
4. The 90 VoiceOver/accessibility candidates listed in `docs/localization-catalog-audit.md`.
5. Natural tone in onboarding, empty collection, capture/editor, Catlas, Settings, privacy receipt, and confirmations.

No commit or publish action was performed as part of this correction.
