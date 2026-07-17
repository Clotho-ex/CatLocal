# CatLocal Localization Correction Report

Date: 2026-07-17

## Status

The engineering correction is complete for English, Turkish, Romanian, Polish, Ukrainian, Greek, and Croatian. CatLocal follows the iOS preferred language automatically. The former all-language Settings picker is removed; every supported non-English configuration receives one English fallback button that becomes `Use System Language` while English is active. Native-speaker approval of the six translations remains a release gate before App Store submission.

## Catalog Correction

- The initial catalog contained 203 keys, including 144 entries marked stale.
- The stale audit classified 34 entries as live/compiler-extractable, 109 as live/manual-dynamic, and one as unused.
- The final catalog contains 288 keys: 241 intentional manual entries, 47 compiler-current entries, 13 plural entries, all seven locales, and zero stale entries.
- The larger final catalog is intentional: it adds previously unlocalized VoiceOver labels, values, hints, dynamic card-style titles, and other selected-language runtime strings.
- Every retained manual key has at least one exact app-source call site. The audit classifies 119 manual keys for accessibility use, 165 for dynamic runtime lookup, and 59 for visible UI; classifications can overlap.
- Superseded English copy, obsolete pre-plural count formats, and the unused standalone `First Local`, `Storage used`, and `Yours` keys were removed only after call-site verification. `Storage used` was the only unused manual entry found in the final 243-entry audit.
- Ten strings belonging only to the retired all-language picker were removed. The seven locale resources remain bundled so iOS can continue selecting them automatically.
- Case-only duplicates were consolidated into `Edit Before Saving`, `On this iPhone`, and `Preparing cat card`. The removed variants are absent from both the catalog and the final Xcode localization export.
- `docs/localization-catalog-audit.md` records every repaired, removed, intentionally manual, and accessibility-native-review entry.

## Copy, Formatting, And Privacy

- English now consistently describes cats, collectible cards, on-device background removal, the private field journal, and collection storage.
- Multi-argument strings use positional placeholders so translators may reorder values.
- All 13 count families pass integers through String Catalog plural rules. Unit coverage exercises every family across all seven locales at `0, 1, 2, 3, 4, 5, 11, 12, 21, 22, 25, 101` (1,092 plural assertions).
- Locale category coverage is English `one/other`, Turkish `other`, Romanian `one/few/other`, Polish and Ukrainian `one/few/many/other`, Greek `one/other`, and Croatian `one/few/other`.
- Privacy translations preserve on-device processing, no GPS request for Catlas, metadata removal, protected local storage, backup exclusion, deletion with the cat, and no account/upload/cloud AI/model-training use.
- Translator comments distinguish typed Memory Places from GPS coordinates, collectible cards from payment cards, and style families from groups of cats.
- Turkish now uses title capitalization for multi-word headings and controls, including `Kart Hareketi`, `Dokunsal Geri Bildirim`, `Yerel Depolama`, `Gizlilik Özeti`, and related titles. Explanatory sentences remain in sentence case.
- Croatian uses `Haptičke povratne informacije` for device-produced haptics.
- The Polish and Ukrainian `other` branches of `Photo with %lld cats marked by number` use the approved neutral fallbacks and preserve `%lld`.

## Language Behavior

- On first launch, CatLocal uses the iOS preferred app/device language.
- The Settings language control is hidden when iOS resolves CatLocal to English or to an unsupported language that falls back to English.
- Turkish, Romanian, Polish, Ukrainian, Greek, and Croatian configurations show their localized `Use English` action. Selecting it applies and persists an English-only CatLocal override.
- While that override is active, the same row becomes `Use System Language`. Selecting it clears the override and returns CatLocal to whichever supported language iOS resolves.
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

- Catalog validator: 288 keys, 7 languages, 13 plural entries, 0 stale entries.
- String Catalog compiler: `xcstringstool compile --dry-run` passes for all seven locales.
- Unit suite: 146 tests passed on iOS 18.0, including the 1,092 plural assertions, all supported preferred-language detection, unsupported-language ordering, and fallback-selection coverage.
- Large iOS 18 locale gallery: 7 tests passed with 42 retained screenshots.
- Final compact iPhone SE / iOS 18 gallery coverage: all 7 locales passed (6 in the combined bundle and the updated Turkish capitalization fixture in its focused rerun).
- iOS 26 locale gallery: 7 tests passed with 42 retained screenshots.
- Final compact iPhone SE / iOS 18 Settings check passed in Turkish and Croatian under dark mode and accessibility XXXL.
- Turkish fallback UI test passed: Turkish launch, immediate English switch, persisted English relaunch, and return through `Use System Language`.
- Ukrainian fallback UI test passed: Ukrainian launch, immediate English switch, and return through `Use System Language`.
- Updated Turkish capitalization gallery passed on compact iPhone SE / iOS 18.
- Final compact iPhone SE / iOS 18 camera-denied checks passed in all 7 locales.
- Xcode localization extraction/export passed and produced `/tmp/CatLocalLocalizationSystemFallback-20260717/en.xcloc`; its non-literal-key warnings correspond to the intentionally manual inventory. Exact catalog inspection confirms the retired picker and Turkish-specific return keys were not recreated, while the language-neutral English/System fallback keys remain present.
- The expanded runtime-flow matrix covers all seven languages and keeps destructive checks at their localized confirmation boundary. Individual English runs verified import/multi-cat, stop/recovery, the corrected long editor/save flow, and single-delete confirmation. A final all-activity pass remains flaky in the synthetic fixture/SwiftUI transition harness, so it is not reported as a clean seven-locale pass.
- Existing functional tests retain responsibility for persistence after destructive confirmation; localization runtime tests stop at the confirmation boundary.
- `git diff --check` passes.

Current result bundles and exported screenshot evidence are stored outside the repository:

- `/tmp/CatLocal-Localization-Large-iOS18.xcresult`
- `/tmp/CatLocal-Localization-Small-iOS18-2.xcresult`
- `/tmp/CatLocal-Localization-iOS26-2.xcresult`
- `/tmp/CatLocal-Localization-Final-Cleanup-Unit.xcresult`
- `/tmp/CatLocal-Localization-Final-Cleanup-Focused-6.xcresult`
- `/tmp/CatLocal-Localization-Final-Cleanup-Gallery-SE-iOS18.xcresult`
- `/tmp/CatLocal-Localization-Final-Cleanup-Gallery-Turkish-SE-iOS18.xcresult`
- `/tmp/CatLocal-Localization-Final-Cleanup-CameraDenied-SE-iOS18.xcresult`
- `/tmp/CatLocal-Language-Fallback-Unit-Final.xcresult`
- `/tmp/CatLocal-Language-Fallback-UI.xcresult`
- `/tmp/CatLocal-System-Fallback-Unit-Green.xcresult`
- `/tmp/CatLocal-System-Fallback-UI-Green.xcresult`
- `/tmp/CatLocal-System-Fallback-Final.xcresult`
- `/tmp/CatLocal-Capitalization-Focused-UI.xcresult`
- `/tmp/CatLocal-Capitalization-Turkish-Gallery.xcresult`
- `/tmp/CatLocalLocalizationSystemFallback-20260717/en.xcloc`
- `/tmp/CatLocal-Small-iOS18-Attachments-Final`
- `/tmp/CatLocal-iOS26-Attachments-Final`

## Native Review Queue

Native-speaker review has not been completed and remains a release gate for Turkish, Romanian, Polish, Ukrainian, Greek, and Croatian. Reviewers should check the full catalog and prioritize:

1. Privacy/security wording, especially first-unlock timing, file protection, metadata removal, no GPS request, no upload/cloud/model-training claims, and destructive actions.
2. The 13 count families and Polish, Ukrainian, Romanian, and Croatian inflection across the tested counts.
3. Collectible-card, typed Memory Place, Catlas, background-removal, and card-style-family terminology.
4. The 90 VoiceOver/accessibility candidates listed in `docs/localization-catalog-audit.md`.
5. Natural tone in onboarding, empty collection, capture/editor, Catlas, Settings, privacy receipt, and confirmations.

No commit or publish action was performed as part of this correction.
