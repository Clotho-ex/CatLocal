# CatLocal App Store Release Handoff

Last verified: July 20, 2026

Use this document as the starting context for a new Codex chat. Re-check external
state such as live URLs, App Store Connect, signing, and TestFlight before acting.

## Objective

Finish CatLocal's first App Store release without weakening its local-first,
privacy-first product behavior.

## Repositories and Current State

### iOS app

- Local repository: `/Users/prometheus/Desktop/CatLocal`
- GitHub: <https://github.com/Clotho-ex/CatLocal>
- Branch: `main`
- Release-preparation base commit: `e061b3f`
  (`Add localized legal and support links`)
- Bundle ID: `app.catlocal.ios`
- Prepared project version: `1.0 (2)`
- Minimum deployment target: iOS 18
- Primary development, testing, and visual-review target: iOS 26

### Website

- Local repository: `/Users/prometheus/Desktop/CatLocal-Website`
- GitHub: <https://github.com/Clotho-ex/CatLocal-Website>
- Visibility: private
- Branch: `main`
- Verified commit: `dcd131b` (`Build CatLocal website`)
- Production domain: <https://catlocal.app>
- Vercel project: `catlocal-website`
- Verified production deployment: `dpl_5NDhAxLSWzC28q94fBXNw1seQ6tE`

Release preparation began with both repositories clean and matching
`origin/main`. This handoff records the reviewed release-preparation state.

## Working Rules

- Treat the repositories and current runtime behavior as the source of truth.
- Keep recognition, foreground separation, image processing, and storage
  on-device.
- Do not add analytics, advertising, accounts, forms, cloud AI, photo uploads,
  GPS collection, tracking, or remote storage.
- Use genuine CatLocal screenshots and approved cat photographs only.
- Do not invent features, UI, metrics, testimonials, or privacy claims.
- Test ordinary changes on iOS 26.
- Test iOS 18 only when a changed feature depends on availability checks,
  compatibility fallbacks, or behavior that may differ at the minimum supported
  version. Do not run the full test suite on iOS 18 by default.
- Prefer focused tests for scoped changes; run broader coverage only when shared
  infrastructure or a primary workflow changes.
- Do not change signing, publish, deploy, or submit without explicit approval.

## Completed Prerequisites

### Website and privacy

- English and Turkish landing pages exist.
- English and Turkish privacy policies are live:
  - <https://catlocal.app/privacy/>
  - <https://catlocal.app/tr/privacy/>
- The privacy policies identify Yusufcan Var and provide
  `info@catlocal.app`.
- The website repository contains bilingual support pages:
  - `/support/`
  - `/tr/support/`
- English and Turkish support pages are live:
  - <https://catlocal.app/support/>
  - <https://catlocal.app/tr/support/>
- The support pages include:
  - Yusufcan Var
  - `info@catlocal.app`
  - basic troubleshooting
  - iOS 18 or later
  - localized privacy-policy links
- The website has no analytics, forms, accounts, tracking pixels, advertising
  scripts, or non-essential cookie implementation.

### Website production deployment

On July 20, 2026, `Clotho-ex/CatLocal-Website` was connected to the existing
Vercel project for `catlocal.app`; no second project was created. Production
deployment `dpl_5NDhAxLSWzC28q94fBXNw1seQ6tE` deployed `main` commit
`dcd131bfa59b35bcf78e8fdc62ca7adb01b8ae4f` and reached `READY`.

- Both Support URLs and both Privacy URLs returned HTTP 200.
- Both Support pages displayed Yusufcan Var, `info@catlocal.app`, iOS 18 or
  later, and the localized Privacy Policy link.
- The production responses set no cookies and loaded no Web Analytics, Speed
  Insights, session-replay, error-tracking, or advertising scripts.
- The Vercel project had no configured log drains.
- Vercel reported no runtime errors during the post-deployment check.
- The website checkout remained clean at the deployed commit.

### In-app legal and contact links

Commit `e061b3f` added and published:

- Localized Privacy Policy links in Settings:
  - <https://catlocal.app/privacy/>
  - <https://catlocal.app/tr/privacy/>
- Localized Support links in Settings:
  - <https://catlocal.app/support/>
  - <https://catlocal.app/tr/support/>
- English and Turkish camera permission descriptions.
- English and Turkish photo-library permission descriptions.
- Focused URL, localization, and project-resource tests.

Five focused tests passed on an iOS 26 simulator. The localization validator
passed with 327 keys, two languages, 13 plural entries, and zero stale entries.

### Privacy manifest

`CatLocal/Resources/PrivacyInfo.xcprivacy` currently declares:

- no tracking;
- no collected data types;
- the UserDefaults required-reason API with reason `CA92.1`.

This must be re-checked against the final release source and every embedded SDK
before answering App Store Connect privacy questions.

## Remaining Work, in Order

### Release preparation completed on July 20, 2026

The release-preparation work contains:

- `MARKETING_VERSION` is `1.0` in Debug and Release. The initial release
  archive used build `1`; the current project build is `2`.
- The generated Release Info.plist was verified with bundle ID
  `app.catlocal.ios`, version `1.0`, build `1`, iOS 18 minimum, and
  `ITSAppUsesNonExemptEncryption = NO`.
- Repository-owned English and Turkish metadata drafts, App Review notes, store
  configuration, and compliance answers exist under `AppStore/Metadata/`.
- Five English and five Turkish `1320 x 2868` RGB screenshots exist under
  `AppStore/Screenshots/upload-ready/en-US/` and
  `AppStore/Screenshots/upload-ready/tr-TR/`.
- Every final screenshot was verified to contain no alpha channel.
- Screenshot sources and genuine localized iOS 26 captures are retained under
  `AppStore/Screenshots/source/`.
- A Release simulator build succeeded with zero build warnings or errors.
- Three focused legal/contact/permission tests executed and passed.
- Localization validation passed with 327 keys, two languages, 13 plural
  entries, and zero stale entries.

The manual foreground fallback was strengthened in commit `ca292ce`
(`Validate manual cat selections`). When automatic cat detection misses and the
user taps a foreground subject, CatLocal now performs a second on-device cat
check and rejects people or objects with recoverable guidance. The focused
regression tests passed, the localization validator passed with 328 keys, two
languages, 13 plural entries, and zero stale entries, and the fix was pushed to
`main`.

Commit `fab120c` (`Prepare TestFlight build 2`) changed the project build number
to `2` and was pushed to `main`. A signed Release archive for `1.0 (2)` was
created, validated, and uploaded to App Store Connect on July 20, 2026. App
Store Connect processed build `2` without a blocking warning. Build `1.0 (2)`
is the only build in `CatLocal Internal` and is available there as `Testing`.
It is also the only build in `CatLocal Friends` and is `Waiting for Review`,
with automatic tester notification enabled and the existing external tester
preserved. Build `1.0 (1)` was withdrawn from Beta App Review and removed from
both groups. No App Store version submission was made, and the app has not been
released.

### App Store Connect state verified on July 20, 2026

- An explicit Apple Developer App ID named `CatLocal` is registered for
  `app.catlocal.ios` under Team ID `5SN9TWDXQ4`.
- The App Store Connect record exists with:
  - app name `CatLocal`;
  - Apple ID `6792723782`;
  - SKU `catlocal-ios`;
  - primary language English (U.S.);
  - iOS version `1.0` in `Prepare for Submission`.
- English and Turkish version metadata is saved, including descriptions,
  keywords, promotional text, support URLs, and marketing URLs.
- English and Turkish subtitles are saved.
- Categories are saved as Lifestyle (primary) and Photo & Video (secondary).
- App Review contact information and review notes are saved.
- The release method is set to manual.
- English and Turkish Privacy Policy URLs are saved.
- The App Privacy response is published, stating that the app does not collect
  data. App Store Connect records the publication by Yusufcan Var.
- An iPhone App Accessibility draft is saved with VoiceOver, Larger Text, Dark
  Interface, Differentiate Without Color Alone, Sufficient Contrast, and
  Reduced Motion marked as supported. Voice Control, Captions, and Audio
  Descriptions are not marked as supported. Apple keeps the accessibility
  `Publish` action disabled until an app version has been released.
- Content Rights remains unanswered. At the operator's direction, photograph
  rights verification is deferred and must not be represented as complete.
- The age-rating questionnaire is complete. All listed features and content
  types were answered `No` or `None`, Kids Category/override was left
  `Not Applicable`, and App Store Connect calculated and saved a global `4+`
  rating with its automatic regional equivalents.
- Pricing is configured as free. App Store Connect shows a current price of
  `0.00` in all 175 price regions. No in-app purchases or subscriptions were
  created.
- Apple Silicon Mac availability is disabled; CatLocal will not be offered on
  the Mac App Store.
- Territory availability is configured for 19 launch markets: Albania, Bosnia
  and Herzegovina, Bulgaria, Croatia, Greece, Ireland, Italy, Kosovo, Malta,
  Moldova, Montenegro, New Zealand, North Macedonia, Romania, Serbia, Slovenia,
  Türkiye, Ukraine, and the United Kingdom. The previous changes are complete;
  App Store Connect is processing Malta to available.
- Five English and five Turkish screenshots are uploaded to their localized
  iPhone 6.9-inch display slots. App Store Connect shows each set as `5 of 10`
  in the verified order `01` through `05`; the 6.5-inch display slot inherits
  the corresponding locale's 6.9-inch set. The uploaded files are the
  `1320 x 2868`, non-transparent PNGs under
  `AppStore/Screenshots/upload-ready/`.
- TestFlight build `1.0 (2)` is validated and processed. It is available to the
  internal group as `Testing` and is `Waiting for Review` for external testing.
  App Store Connect reports bundle ID `app.catlocal.ios`, iPhone device family,
  arm64 architecture, iOS 18.0 minimum, English and Turkish localizations,
  included symbols, and `App Uses Non-Exempt Encryption: No`.
- TestFlight instructions are saved. `CatLocal Internal` contains only build
  `1.0 (2)` and retains the account holder as its tester. `CatLocal Friends`
  contains only build `1.0 (2)` and retains its existing invited tester.
  Automatic distribution remains disabled so later builds must be added
  deliberately.
- Yusufcan Var completed a physical-device check of build `1.0 (2)`. The
  strengthened failure path correctly rejected images without cats. Turkish
  review found four untranslated live labels: `Unplaced`, `Card Design`,
  `Name the Cat`, and `Encounter Note`. Their missing case-sensitive catalog
  entries were corrected in source, so build `1.0 (2)` must not be selected for
  the public release; the corrected source requires a new build.

### 1. Complete and record native Turkish review

Yusufcan Var began the physical-device Turkish review on July 20, 2026. Four
English labels were found and corrected in the String Catalog:

- `Unplaced` -> `Anı Yeri Olmayanlar`;
- `Card Design` and `Card design` -> `Kart Tasarımı`;
- `Name the Cat` -> `Kedinin Adı`;
- `Encounter Note` -> `Karşılaşma Notu`.

The corrected catalog validates with 332 keys, two languages, 13 plural
entries, and zero stale entries. All 155 unit tests passed and a Release
simulator build completed without warnings or errors. Native-speaker approval
remains open until these corrections are confirmed on the next physical-device
build.

Yusufcan Var can perform and approve this review. Review:

- privacy, file-protection, metadata, GPS, upload, cloud, and destructive-action
  wording;
- onboarding and empty states;
- camera, photo-library, cutout, editor, save, edit, and delete flows;
- Catlas and typed Memory Place terminology;
- Settings, Privacy Receipt, Support, and permission prompts;
- plural families and VoiceOver/accessibility copy;
- truncation and natural tone in both compact and large layouts.

After approval:

1. Update `docs/localization-correction-report.md` to identify the reviewer,
   review date, scope, and result.
2. Update stale verification counts in that report if they no longer match the
   current catalog.
3. Run `ruby scripts/validate_localizations.rb`.
4. Run focused Turkish localization/UI checks on iOS 26.
5. Use iOS 18 only for localization behavior that exercises a minimum-version
   compatibility path.
6. Commit and push the review record and any approved corrections.

### 2. Prepare the App Store Connect record and metadata

Repository preparation and bilingual portal entry are complete. The
operator-only decisions and incomplete questionnaire items below remain.

Confirmed in the current record:

- permanent bundle ID: `app.catlocal.ios`;
- public version: `1.0`;
- current uploaded build number: `2`;
- app name: `CatLocal`;
- SKU: `catlocal-ios`;
- primary category: Lifestyle;
- secondary category: Photo & Video;
- release method: manual;
- copyright: `2026 Yusufcan Var`;
- App Review contact information.

The operator completed App Store Connect's Content Rights answer. The public
version remains `1.0`; build `2` contains the corrected cat-detection fallback
but not the Turkish catalog corrections, so the next archive must use a new
build number.

Entered:

- Privacy Policy URL: <https://catlocal.app/privacy/>
- Support URL: <https://catlocal.app/support/>
- localized English and Turkish:
  - subtitle;
  - description;
  - keywords;
  - promotional text.

The localized screenshot sets are uploaded and ordered.

Repository-owned drafts now exist under:

- `AppStore/Metadata/en-US/`
- `AppStore/Metadata/tr-TR/`
- `AppStore/Metadata/review-notes.md`
- `AppStore/Metadata/release-configuration.md`
- `AppStore/Metadata/compliance-answers.md`

Do not put private App Review phone numbers or credentials in Git.

Apple references:

- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)

### 3. App Store screenshot sets completed on July 20, 2026

Five-screen English and Turkish product-page sets are retained under
`AppStore/Screenshots/upload-ready/`. Each export is `1320 x 2868`, RGB, and
non-transparent. The lead direction uses the device-framed card:

- genuine card hero;
- photo-to-card transformation;
- private collection;
- saved memories;
- Catlas places.

Completed:

1. The operator chose to proceed before the deferred native Turkish review.
2. The operator completed the App Store Connect Content Rights answer.
   Photograph-rights evidence remains outside the repository and was not
   independently verified during this handoff.
3. All ten upload files passed dimension and alpha validation.
4. The sets preserve the focused story:
   - private field journal;
   - take or choose a photo;
   - on-device cat cutout;
   - make and save the card;
   - collection and Catlas by typed place;
   - privacy proof, if it remains concise and implementation-backed.
5. The compositions preserve genuine UI and imagery, using cropping, scaling,
   masking, typography, and restrained presentation treatment.
6. The final dimensions, lack of alpha, safe margins, order, and consistency
   were verified. Native Turkish language review remains a separate deferred
   release gate.
7. Only the numbered `01` through `05` files under `upload-ready/` were
   uploaded to each locale's iPhone 6.9-inch display slot. App Store Connect
   uses those sets for the smaller display slots.

Apple accepts one to ten screenshots per localization. The uploaded files were
validated against:

- [Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)

### 4. Complete privacy, export-compliance, rights, and rating answers

Evidence-backed draft answers now exist in
`AppStore/Metadata/compliance-answers.md`. Source inspection found no networking,
cryptography implementation, external package dependency, analytics, tracking,
or advertising SDK. The project now generates
`ITSAppUsesNonExemptEncryption = NO` in Debug and Release.

Before answering, inspect the final archived source and dependency graph.

Expected from the currently inspected implementation:

- no account;
- no analytics or advertising SDK;
- no remote AI;
- no photo upload;
- no GPS request or coordinate storage;
- cat detection and cutout generation on-device;
- cards and image variants stored locally;
- no collected data types in the privacy manifest.

The operator approved and published the App Store Connect answer
`No, we do not collect data from this app`.

Also:

- answer export-compliance/encryption questions from the final binary;
- determine whether an `ITSAppUsesNonExemptEncryption` declaration is
  appropriate rather than guessing;
- re-check the saved `4+` age rating against the final app before submission;
- confirm rights to all cat photographs, UI captures, iconography, fonts, and
  marketing assets;
- retain evidence for those rights outside the public product page.

Apple reference:

- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)

### 5. Archive, upload, and run TestFlight

1. Confirm version/build values and a clean `main`.
2. Create a Release archive using the configured Apple development team.
3. Resolve any certificate, provisioning, agreement, or App Store Connect
   authentication request with the account holder.
4. Validate the archive.
5. Upload it to App Store Connect.
6. Wait for build processing and resolve any warnings.
7. Add the processed build to internal TestFlight.

Run the primary physical-device TestFlight pass on iOS 26 in English and
Turkish:

- first launch and onboarding;
- automatic system-language resolution and English fallback behavior;
- camera and photo-library permission flows;
- photo-to-detection-to-cutout-to-card flow;
- save, edit, and delete;
- relaunch and local persistence;
- light and dark appearance;
- Dynamic Type and relevant accessibility behavior;
- interruptions, cancellation, and recoverable failures.

Run targeted iOS 18 checks only where a changed feature uses availability
gates, compatibility fallbacks, or behavior that may differ on the deployment
floor. Do not duplicate the entire iOS 26 pass by default.

### 6. Finalize App Review information and submit

Add concise App Review notes explaining:

- CatLocal requires no account or login.
- Apple Vision processing occurs on-device.
- Cat photographs and generated cutouts are not uploaded.
- CatLocal does not request GPS or store coordinates.
- Memory Places are labels typed by the user.
- Cards remain in local app storage.
- The camera and photo library are used only for the user-directed card flow.
- No demo account is required.

Then:

1. Select the processed build.
2. Confirm every required metadata field and localized screenshot set.
3. Confirm Privacy and Support URLs are live.
4. Add the version to the submission.
5. Submit for review.
6. Monitor App Review messages and answer with implementation-backed facts.

Apple reference:

- [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)

### 7. Finish the website after the listing is live

1. Capture the final public App Store URL.
2. Replace every `Coming soon to the App Store` status with Apple's official
   App Store badge or a clearly labeled App Store link.
3. Update both English and Turkish pages.
4. Keep the link as a normal anchor that works without JavaScript.
5. Run website lint, source tests, production build/export tests, and responsive
   checks.
6. Commit and push the website update.
7. Deploy the verified website commit.
8. Verify the production App Store link and localized pages.

## Inputs the New Chat May Need From Yusufcan Var

- Final confirmation of the prepared public version `1.0 (2)`.
- App Store Connect/App Store role access.
- App Review phone number; keep it out of Git.
- Category, territories, price, and release-method decisions.
- Native Turkish review approval and any corrections.
- Rights confirmation for every cat photograph and marketing asset.
- Apple signing or certificate approval when Xcode requests it.
- Final decision on replacing English physical-device UI in the two Turkish
  screenshot compositions.

## Definition of Release-Ready

CatLocal is ready to submit only when:

- both Support URLs and both Privacy URLs return HTTP 200;
- Support pages show real contact information;
- Turkish review is approved and recorded;
- App Store metadata is complete in English and Turkish;
- coherent English and Turkish screenshots are uploaded;
- privacy, export-compliance, rights, rating, and availability answers are
  complete and accurate;
- a Release build is processed in App Store Connect;
- focused TestFlight validation passes on iOS 26, with targeted iOS 18
  compatibility checks where required;
- App Review notes match the actual implementation;
- the correct build is selected and ready for submission.
