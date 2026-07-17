# CatLocal Localization Catalog Audit

Date: 2026-07-17

This is the repository record for the stale-entry correction required by the localization plan. Regenerate it with `ruby scripts/generate_localization_audit.rb` after intentional catalog changes.

## Audit Result

- Initial catalog: 203 keys, including 144 entries marked stale.
- Initial stale classification: 34 live compiler-extractable entries, 109 live manual/dynamic entries, and one unused entry.
- Corrected catalog: 288 keys, 241 intentional manual entries, 47 compiler-current entries, 13 plural entries, and zero stale entries.
- Both supported locales are present: English and Turkish.
- Every retained manual key has at least one exact app-source call site.
- Purpose classifications: Accessibility 119, Dynamic runtime lookup 165, Visible UI 59. A key can serve more than one purpose.

## Repaired Compiler-Extractable Entries (33)

These live source keys were refreshed or migrated to current source copy instead of being deleted as if unused.

- `A note about this encounter`
- `About CatLocal`
- `App Information`
- `Built Without`
- `Camera`
- `Choose private photo`
- `Close camera`
- `Could not delete card`
- `Could not update storage`
- `Delete All Cats`
- `Drag to catch the light`
- `Edit`
- `Edit Card`
- `Home`
- `Make It Yours`
- `Memory Place`
- `Nickname`
- `OK`
- `Open Settings`
- `Privacy & About`
- `Privacy Receipt`
- `Private scan on this iPhone`
- `Removing the background`
- `Retake`
- `Save Cat`
- `Settings`
- `Sort places`
- `Sort saved cards`
- `Stop and return`
- `Take photo`
- `Try another photo`
- `Try the center`
- `Version`

## Removed Superseded Count And Format Keys (22)

These were replaced by integer-based String Catalog plural entries or positional placeholders. Keeping them would allow non-plural, preformatted, or non-reorderable formatting to return.

- `%1$@ in %2$@ families`
- `%1$lld in %2$lld families`
- `%@ cats`
- `%@ cats saved locally`
- `%@ in %@ families`
- `%@ more %@`
- `%@ places`
- `%@ places typed by you.`
- `%@ saved`
- `%@ selected`
- `%@ styles`
- `1 cat`
- `1 cat saved locally`
- `1 place`
- `1 place typed by you.`
- `1 saved`
- `1 selected`
- `Cat %@`
- `Delete %@ Cards`
- `Delete 1 Card`
- `Marked %@ in the photo`
- `Step %@ of %@`

## Removed Superseded Source Copy (19)

These keys were removed only after their English call sites and assertions moved to the approved cat, collectible-card, on-device background-removal, collection, and field-journal language.

- `A private field journal for local encounters.`
- `Adding a little finish`
- `Camera or private photo`
- `Capture an encounter and turn it into a local card.`
- `Lift On Device`
- `Lifted cutout`
- `Lifting the subject`
- `Lifting...`
- `Local Card`
- `Looking for cats, then lifting the subject`
- `Meet Your First Local`
- `No Account No Cloud`
- `No Note Yet.`
- `On-device lift`
- `Ready for Your First Local`
- `Saved to Home`
- `Try exact center`
- `Your first card keeps the lifted cutout, design, notes, and typed place together.`
- `Your furry encounters are safe`

## Final Duplicate Consolidation

These case-only duplicates were consolidated after every visible and accessibility call site moved to the canonical key.

- `Edit before saving` -> `Edit Before Saving`
- `On This iPhone` -> `On this iPhone`
- `Preparing Cat Card` -> `Preparing cat card`

Updated Swift call sites:

- `CatLocal/Features/Capture/CaptureView.swift:1400` and `:1524`: `Preparing Cat Card` -> `Preparing cat card`.
- `CatLocal/Features/Capture/CaptureView.swift:1445`: `Edit before saving` -> `Edit Before Saving`.
- `CatLocal/Features/Settings/SettingsView.swift:370`: `On This iPhone` -> `On this iPhone`.
- `CatLocalTests/CatLocalCoreTests.swift`: canonical-key coverage and removed-key regression checks.

## Removed Unused Standalone Keys (3)

These had no exact runtime call site. `Yours` appeared only as part of `Make It Yours`; neither key was retained or replaced with invented product copy.

- `First Local`
- `Storage used`
- `Yours`

## Removed Multi-Language Picker Keys (10)

These labels belonged only to the retired all-language Settings picker. CatLocal still bundles every supported localization for automatic iOS language selection, while supported non-English configurations see only the English fallback action.

- `Changes the app language immediately.`
- `English`
- `Hrvatski`
- `Language`
- `Polski`
- `Română`
- `System Language`
- `Türkçe`
- `Ελληνικά`
- `Українська`

## Removed Turkish-Specific Fallback Keys (2)

These were replaced by the language-neutral `Use System Language` action so every supported non-English locale can return from the English fallback without naming a particular language.

- `Switch CatLocal back to Turkish.`
- `Use Turkish`

## Intentionally Manual Active Entries (241)

These are active, not stale. They are intentionally maintained because CatLocal supports an English fallback for every supported non-English iOS language, integer plural formatting, dynamic enum/model labels, and explicitly localized accessibility strings. Some visible literals are also held manually so the selected-language catalog remains complete and reviewable. The validator requires every manual key to retain an exact app-source call site, both locales, and a non-empty translation.

| Key | Confirmed purpose | App source call sites |
| --- | --- | --- |
| `%1$@ styles` | Accessibility | `CatLocal/Shared/UI/Card/CatCardView.swift:2414` |
| `%1$@, cat number %2$lld, captured %3$@.` | Accessibility | `CatLocal/Features/Collection/CollectionView.swift:1490` |
| `%1$lld in %2$@` | Dynamic runtime lookup | `CatLocal/Shared/Localization/CatLocalLocalization.swift:91` |
| `%lld cards selected` | Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:983` |
| `%lld cats` | Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:1313` |
| `%lld cats found` | Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:1083` |
| `%lld cats saved locally` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:187` |
| `%lld families` | Dynamic runtime lookup | `CatLocal/Shared/Localization/CatLocalLocalization.swift:86` |
| `%lld more cats` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Features/Collection/CollectionView.swift:1444` |
| `%lld places` | Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:630` |
| `%lld places typed by you.` | Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:621` |
| `%lld saved cards` | Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:1317` |
| `%lld styles` | Dynamic runtime lookup; Visible UI | `CatLocal/Shared/UI/Card/CatCardView.swift:2294` |
| `A note about this encounter` | Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1585`, `CatLocal/Shared/UI/Card/FocusedCardView.swift:416` |
| `A private field journal for the cats you meet.` | Visible UI | `CatLocal/Features/Collection/CollectionView.swift:281` |
| `A private place for the cats you meet.` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:355` |
| `A-Z` | Accessibility; Dynamic runtime lookup | `CatLocal/App/CatLocalApp.swift:73` |
| `About CatLocal` | Dynamic runtime lookup; Visible UI | `CatLocal/Features/Settings/SettingsView.swift:173`, `CatLocal/Features/Settings/SettingsView.swift:444` |
| `Add a Memory Place to build Catlas.` | Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:619` |
| `Add to Selection` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:1186` |
| `Add when ready.` | Dynamic runtime lookup | `CatLocal/Shared/UI/Card/FocusedCardView.swift:266` |
| `Adding finishing touches` | Dynamic runtime lookup; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1380`, `CatLocal/Features/Capture/CaptureView.swift:1506` |
| `Adds a manual place label to the private Catlas` | Accessibility | `CatLocal/Features/Capture/CaptureView.swift:1573` |
| `App Information` | Visible UI | `CatLocal/Features/Settings/SettingsView.swift:429` |
| `App purpose and version information.` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:174` |
| `Appearance` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:84` |
| `Apple Vision finds and separates cats entirely on-device.` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:353` |
| `Apricot` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:205`, `CatLocal/Core/Models/CatRecord.swift:366` |
| `Apricot Beam` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:231` |
| `Archive` | Dynamic runtime lookup | `CatLocal/Core/Models/CatRecord.swift:195`, `CatLocal/Core/Models/CatRecord.swift:329`, `CatLocal/Features/Collection/CollectionView.swift:382` |
| `Aurora Pool` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:233` |
| `Back` | Dynamic runtime lookup; Visible UI | `CatLocal/Features/Onboarding/OnboardingView.swift:177` |
| `Botanical` | Dynamic runtime lookup | `CatLocal/Core/Models/CatRecord.swift:333` |
| `Bottom center` | Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:430` |
| `Bottom left` | Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:429` |
| `Bottom right` | Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:431` |
| `Built Without` | Visible UI | `CatLocal/Features/Settings/SettingsView.swift:433` |
| `Calculating...` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:14` |
| `Camera` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/App/RootView.swift:94`, `CatLocal/App/RootView.swift:120`, `CatLocal/Core/Models/CatRecord.swift:135` |
| `Camera zoom` | Accessibility; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:849` |
| `Cancel selection` | Accessibility; Visible UI | `CatLocal/Features/Collection/CollectionView.swift:916` |
| `Cancels on-device processing and returns to the camera` | Accessibility | `CatLocal/Features/Capture/CaptureView.swift:1069` |
| `Capture an encounter and turn it into a collectible card.` | Dynamic runtime lookup | `CatLocal/Shared/UI/Loci/LociContext.swift:77` |
| `Capture or Import` | Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:1326`, `CatLocal/Features/Onboarding/OnboardingView.swift:1053` |
| `Capture or Import. On-device cutout. Make It Yours.` | Accessibility; Visible UI | `CatLocal/Features/Onboarding/OnboardingView.swift:1080` |
| `Captured` | Dynamic runtime lookup | `CatLocal/Shared/UI/Card/FocusedCardView.swift:244` |
| `Card Motion` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:94` |
| `Card details` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:1181` |
| `Card lighting` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Shared/UI/Effects/LiveInteractiveCardView.swift:79` |
| `Card motion is reduced.` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Effects/LiveInteractiveCardView.swift:83` |
| `Card style families` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Shared/UI/Card/CatCardView.swift:2341` |
| `Cards` | Dynamic runtime lookup | `CatLocal/App/CatLocalApp.swift:52` |
| `Cards save to this iPhone.` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:431` |
| `Cat %1$lld, marked %2$lld in the photo` | Accessibility | `CatLocal/Features/Capture/CaptureView.swift:1154` |
| `Cat %lld` | Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:1121` |
| `Cat card ready.` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:2368` |
| `Cat cutout` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:1175` |
| `Cat, %1$@. Cat number %2$lld. Captured %3$@.` | Accessibility | `CatLocal/Shared/UI/Card/CatCardView.swift:66` |
| `CatLocal could not measure local storage.` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:213` |
| `CatLocal does not request GPS or save coordinates. Catlas labels are typed by you.` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:358` |
| `CatLocal looks for cats here.` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:419` |
| `Catlas` | Accessibility; Dynamic runtime lookup | `CatLocal/App/CatLocalApp.swift:53`, `CatLocal/Features/Capture/CaptureView.swift:1567`, `CatLocal/Shared/UI/Card/FocusedCardView.swift:412` |
| `Cedar Shade` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:223` |
| `Center` | Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:427` |
| `Changes the card order` | Accessibility | `CatLocal/Features/Collection/CollectionView.swift:784` |
| `Choose a design, notes, and typed place` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:1066` |
| `Choose cards to delete` | Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:981` |
| `Choose private photo` | Accessibility; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:753`, `CatLocal/Features/Capture/CaptureView.swift:934` |
| `Clear` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:199` |
| `Close` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1919`, `CatLocal/Shared/DesignSystem/CatLocalTheme.swift:702` |
| `Close camera` | Accessibility; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:674` |
| `Cobalt Halo` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:229` |
| `Collectible Card` | Visible UI | `CatLocal/Features/Onboarding/OnboardingView.swift:773`, `CatLocal/Features/Onboarding/OnboardingView.swift:986` |
| `Completed` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:2940` |
| `Continue` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:375` |
| `Contour` | Dynamic runtime lookup | `CatLocal/Core/Models/CatRecord.swift:331` |
| `Contour Light` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:211` |
| `Could not delete card` | Visible UI | `CatLocal/Features/Collection/CollectionView.swift:146` |
| `Could not update storage` | Visible UI | `CatLocal/Features/Settings/SettingsView.swift:53` |
| `Creating cat cutout` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:995` |
| `Dark` | Dynamic runtime lookup | `CatLocal/App/CatLocalApp.swift:27` |
| `Delete` | Dynamic runtime lookup; Visible UI | `CatLocal/Features/Collection/CollectionView.swift:122`, `CatLocal/Features/Collection/CollectionView.swift:935`, `CatLocal/Shared/DesignSystem/CatLocalTheme.swift:510`, `CatLocal/Shared/UI/Card/FocusedCardView.swift:468` |
| `Delete %lld Cards` | Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:987` |
| `Delete All` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:45` |
| `Delete All Cats` | Visible UI | `CatLocal/Features/Settings/SettingsView.swift:129` |
| `Delete every cat?` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:42` |
| `Delete selected cards?` | Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:135` |
| `Delete this cat?` | Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:120`, `CatLocal/Shared/UI/Card/FocusedCardView.swift:466` |
| `Deletes this cat and its local images from this iPhone` | Accessibility | `CatLocal/Shared/UI/Card/FocusedCardView.swift:439` |
| `Deleting` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Features/Collection/CollectionView.swift:935`, `CatLocal/Shared/DesignSystem/CatLocalTheme.swift:654`, `CatLocal/Shared/DesignSystem/CatLocalTheme.swift:667` |
| `Design %1$lld, %2$@ card design` | Accessibility | `CatLocal/Shared/UI/Card/CatCardView.swift:2613` |
| `Design, notes, place` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:1182` |
| `Done selecting cards` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:801` |
| `Double tap to choose a zoom level. Swipe up or down to adjust.` | Accessibility | `CatLocal/Features/Capture/CaptureView.swift:851` |
| `Double tap to open focused cat view.` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Card/CatCardView.swift:55` |
| `Double tap to open this card` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:494` |
| `Double tap to select or deselect this card` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:493` |
| `Double-tap to try the center of the photo. Use Retake or Choose private photo if the cat is elsewhere.` | Accessibility | `CatLocal/Features/Capture/CaptureView.swift:3286` |
| `Draft cat card` | Accessibility; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1326` |
| `Drag the cat to shift its light` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Card/CatCardView.swift:54` |
| `Drag to catch the light` | Visible UI | `CatLocal/Shared/UI/Card/FocusedCardView.swift:200` |
| `Dusk Lines` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:219` |
| `Edit` | Accessibility; Visible UI | `CatLocal/Shared/UI/Card/FocusedCardView.swift:51`, `CatLocal/Shared/UI/Effects/CardMintingSuccessView.swift:191` |
| `Edit Card` | Visible UI | `CatLocal/Features/Collection/CollectionView.swift:469` |
| `Edit details later` | Dynamic runtime lookup; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1380` |
| `Ember Lines` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:213` |
| `Ends onboarding. Privacy details remain available in Settings.` | Accessibility | `CatLocal/Features/Onboarding/OnboardingView.swift:219` |
| `Failed` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:2941` |
| `Fern Trace` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:225` |
| `Finds the cat and removes the background` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:1060` |
| `For each cat, CatLocal retains a sanitized, re-encoded original plus its cutout and thumbnail.` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:348` |
| `Garden` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:201` |
| `Gold Leaf` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:209` |
| `Haptic Feedback` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:103` |
| `Home` | Dynamic runtime lookup; Visible UI | `CatLocal/App/RootView.swift:69`, `CatLocal/App/RootView.swift:101`, `CatLocal/Shared/UI/Effects/CardMintingSuccessView.swift:179` |
| `Home opens next. Tap Camera when you meet a cat, or choose a private photo.` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:359`, `CatLocal/Features/Onboarding/OnboardingView.swift:366` |
| `I couldn't find the cat clearly` | Dynamic runtime lookup | `CatLocal/Shared/UI/Loci/LociContext.swift:64` |
| `Image Storage` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:367` |
| `Includes card details, notes, typed Catlas labels, originals, cutouts, and thumbnails.` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:183` |
| `Lagoon Lines` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:215` |
| `Leaves selection mode` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:807` |
| `Light` | Dynamic runtime lookup | `CatLocal/App/CatLocalApp.swift:26`, `CatLocal/Core/Models/CatRecord.swift:335` |
| `Light centered` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Effects/LiveInteractiveCardView.swift:239` |
| `Light left` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Effects/LiveInteractiveCardView.swift:237` |
| `Light right` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Effects/LiveInteractiveCardView.swift:241` |
| `Live card preview` | Accessibility; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1654` |
| `Location` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:357` |
| `Location Data Stripped` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:424` |
| `Looking for cats` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:982`, `CatLocal/Features/Capture/CaptureView.swift:994` |
| `Marked %lld in the photo` | Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:1129` |
| `Meet Your First Cat` | Dynamic runtime lookup | `CatLocal/Shared/UI/Loci/LociContext.swift:56` |
| `Memory Place` | Dynamic runtime lookup; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1569`, `CatLocal/Shared/UI/Card/CatCardView.swift:512`, `CatLocal/Shared/UI/Card/FocusedCardView.swift:258`, `CatLocal/Shared/UI/Card/FocusedCardView.swift:264`, `CatLocal/Shared/UI/Card/FocusedCardView.swift:403` |
| `Memory Place, %1$@` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Card/CatCardView.swift:76`, `CatLocal/Shared/UI/Card/CatCardView.swift:80`, `CatLocal/Shared/UI/Card/CatCardView.swift:604` |
| `Memory Place, %1$@, %2$@` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Card/CatCardView.swift:601` |
| `Middle left` | Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:426` |
| `Middle right` | Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:428` |
| `Midnight` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:203` |
| `Midnight Prism` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:207` |
| `Moss Lines` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:217` |
| `Moss Veil` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:227` |
| `Motion reduced` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Effects/LiveInteractiveCardView.swift:80` |
| `Network` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:362` |
| `New Cat` | Dynamic runtime lookup | `CatLocal/Shared/UI/Card/CatCardView.swift:120` |
| `Nickname` | Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1561`, `CatLocal/Shared/UI/Card/FocusedCardView.swift:395` |
| `No Account. No Cloud.` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:430` |
| `No Memory Place yet.` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Card/CatCardView.swift:77`, `CatLocal/Shared/UI/Card/CatCardView.swift:607` |
| `No note yet.` | Dynamic runtime lookup; Visible UI | `CatLocal/Shared/UI/Card/CatCardView.swift:467`, `CatLocal/Shared/UI/Card/FocusedCardView.swift:252` |
| `Not selected` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:1193` |
| `Note saved.` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Card/CatCardView.swift:84`, `CatLocal/Shared/UI/Card/CatCardView.swift:611` |
| `Notes` | Dynamic runtime lookup | `CatLocal/Shared/UI/Card/CatCardView.swift:465`, `CatLocal/Shared/UI/Card/FocusedCardView.swift:250` |
| `Nothing leaves your phone` | Dynamic runtime lookup | `CatLocal/Shared/UI/Loci/LociContext.swift:70` |
| `Number` | Accessibility; Dynamic runtime lookup | `CatLocal/App/CatLocalApp.swift:71` |
| `OK` | Visible UI | `CatLocal/Features/Collection/CollectionView.swift:147`, `CatLocal/Features/Settings/SettingsView.swift:54`, `CatLocal/Shared/UI/Card/FocusedCardView.swift:460` |
| `On-device Vision` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:417` |
| `On-device cutout` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:1059`, `CatLocal/Features/Onboarding/OnboardingView.swift:1176` |
| `Onboarding step %1$@ of %2$@` | Accessibility | `CatLocal/Features/Onboarding/OnboardingView.swift:123`, `CatLocal/Features/Onboarding/OnboardingView.swift:1270` |
| `Open Home` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:377` |
| `Open Settings` | Visible UI | `CatLocal/Features/Capture/CaptureView.swift:951` |
| `Opens a filtered Catlas grid` | Accessibility | `CatLocal/Features/Collection/CollectionView.swift:674` |
| `Opens design, name, note, and Catlas fields before saving.` | Accessibility | `CatLocal/Features/Capture/CaptureView.swift:1446` |
| `Opens nine named regions for selecting the cat without an exact tap` | Accessibility | `CatLocal/Features/Capture/CaptureView.swift:1255` |
| `Opens the camera and private photo import.` | Accessibility | `CatLocal/App/RootView.swift:121` |
| `Permanently removes every stored cat and local image` | Accessibility | `CatLocal/Features/Settings/SettingsView.swift:145` |
| `Photo for foreground selection` | Accessibility; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:3284` |
| `Photo with %lld cats marked by number` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:3335` |
| `Photos` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:347` |
| `Photos stay on this iPhone.` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:357` |
| `Pine Shadow` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:221` |
| `Place` | Accessibility; Dynamic runtime lookup | `CatLocal/App/CatLocalApp.swift:72` |
| `Place Detail` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1576`, `CatLocal/Shared/UI/Card/CatCardView.swift:519`, `CatLocal/Shared/UI/Card/FocusedCardView.swift:273`, `CatLocal/Shared/UI/Card/FocusedCardView.swift:407` |
| `Positioning cat cutout` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:2938` |
| `Preparing` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:2936` |
| `Preparing card` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1377`, `CatLocal/Features/Capture/CaptureView.swift:1503` |
| `Preparing cat card` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1400`, `CatLocal/Features/Capture/CaptureView.swift:1524`, `CatLocal/Features/Capture/CaptureView.swift:2911` |
| `Press and drag to catch the glint` | Dynamic runtime lookup | `CatLocal/Shared/UI/Loci/LociContext.swift:68` |
| `Privacy & About` | Visible UI | `CatLocal/Features/Settings/SettingsView.swift:157` |
| `Privacy Receipt` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Features/Settings/SettingsView.swift:162`, `CatLocal/Features/Settings/SettingsView.swift:379` |
| `Private scan on this iPhone` | Accessibility; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:722` |
| `Ready for Your First Cat` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:348` |
| `Recognition` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:352` |
| `Recommended, %1$@` | Accessibility | `CatLocal/Shared/UI/Card/CatCardView.swift:2381` |
| `Remove from Selection` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:1185` |
| `Removing background` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:2937` |
| `Removing background...` | Visible UI | `CatLocal/Shared/UI/Effects/DustingRevealView.swift:810` |
| `Removing the background` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:982`, `CatLocal/Shared/UI/Effects/DustingRevealView.swift:819` |
| `Retake` | Accessibility; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1080`, `CatLocal/Features/Capture/CaptureView.swift:1178`, `CatLocal/Features/Capture/CaptureView.swift:1761`, `CatLocal/Features/Capture/CaptureView.swift:1780` |
| `Return to your iOS language.` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:70` |
| `Save Cat` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1377`, `CatLocal/Features/Capture/CaptureView.swift:1400`, `CatLocal/Features/Capture/CaptureView.swift:1503`, `CatLocal/Features/Capture/CaptureView.swift:1524` |
| `Save to Collection` | Dynamic runtime lookup; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1506` |
| `Saved images are GPS-free.` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:425` |
| `Saved to Collection` | Visible UI | `CatLocal/Features/Onboarding/OnboardingView.swift:990` |
| `Saves this card now. You can edit the name, design, and Catlas details later.` | Accessibility | `CatLocal/Features/Capture/CaptureView.swift:1402` |
| `See exactly what stays on-device.` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:163` |
| `Select` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Features/Collection/CollectionView.swift:814`, `CatLocal/Features/Collection/CollectionView.swift:823` |
| `Select Card` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:1188` |
| `Select cards for deletion` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:802` |
| `Selected for deletion` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:1193` |
| `Selects this card design` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Card/CatCardView.swift:2385`, `CatLocal/Shared/UI/Card/CatCardView.swift:2618` |
| `Selects this cat for the card` | Accessibility | `CatLocal/Features/Capture/CaptureView.swift:1159` |
| `Settings` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/App/RootView.swift:79`, `CatLocal/App/RootView.swift:125`, `CatLocal/Features/Settings/SettingsView.swift:31` |
| `Settling card` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:2939` |
| `Shows %lld styles` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Card/CatCardView.swift:2419` |
| `Shows selection controls before deleting cards` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:808` |
| `Something went wrong` | Dynamic runtime lookup | `CatLocal/Shared/UI/Loci/LociContext.swift:62` |
| `Sort` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Features/Collection/CollectionView.swift:746`, `CatLocal/Features/Collection/CollectionView.swift:775` |
| `Sort places` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Features/Collection/CollectionView.swift:744`, `CatLocal/Features/Collection/CollectionView.swift:748` |
| `Sort saved cards` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Features/Collection/CollectionView.swift:773`, `CatLocal/Features/Collection/CollectionView.swift:777` |
| `Sorted by %1$@` | Accessibility | `CatLocal/Features/Collection/CollectionView.swift:751`, `CatLocal/Features/Collection/CollectionView.swift:780` |
| `Sorts Catlas places` | Accessibility | `CatLocal/Features/Collection/CollectionView.swift:755` |
| `Starts the private capture and photo import flow` | Accessibility | `CatLocal/Shared/UI/Loci/LociStateView.swift:92` |
| `Step %1$@ of %2$@` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:112` |
| `Stop and return` | Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1057` |
| `Storage used, %1$@` | Accessibility; Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:304` |
| `Stored image loading` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Images/StoredImageView.swift:23` |
| `Stored image unavailable` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Images/StoredImageView.swift:22` |
| `Sunstamp` | Accessibility | `CatLocal/Core/Models/CatRecord.swift:197` |
| `Swipe up or down to move the light.` | Accessibility; Dynamic runtime lookup | `CatLocal/Shared/UI/Effects/LiveInteractiveCardView.swift:84` |
| `Switch CatLocal to English.` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:71` |
| `System` | Dynamic runtime lookup | `CatLocal/App/CatLocalApp.swift:25` |
| `Tactile cues for capture, cards, and actions.` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:104` |
| `Take a photo or choose one` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:1054` |
| `Take photo` | Accessibility; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:773` |
| `The card was not deleted. Please try again.` | Dynamic runtime lookup | `CatLocal/Features/Collection/CollectionView.swift:992` |
| `The collection requires no account, upload, cloud AI, or model-training use.` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:363` |
| `The selected photo stays on this iPhone` | Accessibility | `CatLocal/Features/Capture/CaptureView.swift:754`, `CatLocal/Features/Capture/CaptureView.swift:943` |
| `This permanently removes every saved cat from this iPhone.` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:43` |
| `This photo looks a little unclear` | Dynamic runtime lookup | `CatLocal/Shared/UI/Loci/LociContext.swift:66` |
| `This photo may need another try` | Dynamic runtime lookup | `CatLocal/Shared/UI/Loci/LociContext.swift:60` |
| `Tilt, foil lighting, and reveal motion.` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:95` |
| `Top center` | Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:424` |
| `Top left` | Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:423` |
| `Top right` | Dynamic runtime lookup | `CatLocal/Features/Capture/CaptureView.swift:425` |
| `Try another photo` | Accessibility; Visible UI | `CatLocal/Features/Capture/CaptureView.swift:1906` |
| `Try the center` | Accessibility | `CatLocal/Features/Capture/CaptureView.swift:3291` |
| `Unavailable` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:212`, `CatLocal/Features/Settings/SettingsView.swift:416` |
| `Use English` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:68` |
| `Use System Language` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:68` |
| `Use the numbered choices below to select a cat` | Accessibility | `CatLocal/Features/Capture/CaptureView.swift:3339` |
| `Version` | Dynamic runtime lookup | `CatLocal/Features/Settings/SettingsView.swift:430` |
| `Welcome to CatLocal` | Dynamic runtime lookup | `CatLocal/Features/Onboarding/OnboardingView.swift:344` |
| `Your cat encounters stay private` | Accessibility; Dynamic runtime lookup; Visible UI | `CatLocal/Features/Onboarding/OnboardingView.swift:346`, `CatLocal/Features/Onboarding/OnboardingView.swift:658`, `CatLocal/Features/Onboarding/OnboardingView.swift:664` |

## Accessibility Native-Review Queue (90)

These active labels, values, and hints need native-speaker review in Turkish. Their comments identify accessibility context, but engineering validation cannot establish natural spoken phrasing.

- `%1$@ styles`
- `%1$@, cat number %2$lld, captured %3$@.`
- `A-Z`
- `Add to Selection`
- `Adds a manual place label to the private Catlas`
- `Apricot`
- `Apricot Beam`
- `Aurora Pool`
- `Camera zoom`
- `Cancel selection`
- `Cancels on-device processing and returns to the camera`
- `Capture or Import. On-device cutout. Make It Yours.`
- `Card lighting`
- `Card motion is reduced.`
- `Card style families`
- `Cat card ready.`
- `Cat, %1$@. Cat number %2$lld. Captured %3$@.`
- `Cedar Shade`
- `Changes the card order`
- `Clear`
- `Close`
- `Cobalt Halo`
- `Completed`
- `Contour Light`
- `Creating cat cutout`
- `Deletes this cat and its local images from this iPhone`
- `Done selecting cards`
- `Double tap to choose a zoom level. Swipe up or down to adjust.`
- `Double tap to open focused cat view.`
- `Double tap to open this card`
- `Double tap to select or deselect this card`
- `Double-tap to try the center of the photo. Use Retake or Choose private photo if the cat is elsewhere.`
- `Draft cat card`
- `Drag the cat to shift its light`
- `Dusk Lines`
- `Ember Lines`
- `Ends onboarding. Privacy details remain available in Settings.`
- `Failed`
- `Fern Trace`
- `Garden`
- `Gold Leaf`
- `Lagoon Lines`
- `Leaves selection mode`
- `Light centered`
- `Light left`
- `Light right`
- `Live card preview`
- `Memory Place, %1$@`
- `Memory Place, %1$@, %2$@`
- `Midnight`
- `Midnight Prism`
- `Moss Lines`
- `Moss Veil`
- `Motion reduced`
- `No Memory Place yet.`
- `Not selected`
- `Note saved.`
- `Number`
- `Opens a filtered Catlas grid`
- `Opens design, name, note, and Catlas fields before saving.`
- `Opens nine named regions for selecting the cat without an exact tap`
- `Opens the camera and private photo import.`
- `Permanently removes every stored cat and local image`
- `Photo for foreground selection`
- `Pine Shadow`
- `Place`
- `Positioning cat cutout`
- `Preparing`
- `Preparing cat card`
- `Recommended, %1$@`
- `Remove from Selection`
- `Removing background`
- `Saves this card now. You can edit the name, design, and Catlas details later.`
- `Select Card`
- `Select cards for deletion`
- `Selected for deletion`
- `Selects this card design`
- `Selects this cat for the card`
- `Settling card`
- `Shows selection controls before deleting cards`
- `Sorted by %1$@`
- `Sorts Catlas places`
- `Starts the private capture and photo import flow`
- `Storage used, %1$@`
- `Stored image loading`
- `Stored image unavailable`
- `Sunstamp`
- `Swipe up or down to move the light.`
- `The selected photo stays on this iPhone`
- `Use the numbered choices below to select a cat`

## Maintenance Contract

- Run `ruby scripts/validate_localizations.rb` before merging localization work.
- Run `xcrun xcstringstool compile --dry-run` to validate String Catalog compilation.
- Run this generator when the catalog changes so the manual-entry inventory stays reviewable.
- Do not remove a manual entry solely because Xcode marks it unextracted; first prove that no selected-language, plural, model, enum, or accessibility lookup reaches it.
- Native-speaker review of the Turkish translation remains a release gate and is not replaced by this engineering audit.
