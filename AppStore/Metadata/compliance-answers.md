# App Store Compliance Answers

Last source verification: July 20, 2026

These are evidence-backed draft answers for the `1.0 (1)` source. The account
holder must confirm them against the final archive and App Store Connect's
current wording.

## App Privacy

Recommended answer: **No, we do not collect data from this app.**

Evidence:

- no account or sign-in;
- no analytics, advertising, tracking, or third-party SDK dependency;
- no networking implementation;
- no photo, cutout, note, card, or Catlas upload;
- no GPS permission request or coordinate storage;
- cat recognition and foreground separation use Apple Vision on-device;
- cards and sanitized image variants remain in local app storage;
- `PrivacyInfo.xcprivacy` declares no tracking and no collected data types.

The privacy manifest declares the UserDefaults required-reason API under
`CA92.1`.

## Export compliance

Recommended answer: the app does not use non-exempt encryption.

The source and project dependency graph contain no cryptography or networking
implementation and no external packages. The generated Info.plist now declares
`ITSAppUsesNonExemptEncryption = NO` for Debug and Release configurations.

## Content rights

Recommended portal answer: CatLocal does not contain, show, or access
third-party content as a service. Users select or create their own private
photos locally.

Before submission, Yusufcan must confirm documented rights to:

- every cat photograph used in App Store screenshots or the website;
- genuine CatLocal UI captures;
- the Loci mascot and app icon artwork;
- any marketing fonts or device frames used in final exports.

Keep the underlying evidence privately; do not add personal releases or private
contact details to the repository.

## Age rating draft

Expected result: **4+**, subject to App Store Connect's computed result.

Draft questionnaire answers:

- parental controls: none;
- age assurance: none;
- unrestricted web access: none;
- user-generated content sharing: none;
- messaging or chat: none;
- advertising: none;
- violence: none;
- sexual content or nudity: none;
- profanity or crude humor: none;
- drugs, alcohol, tobacco, gambling, contests, or loot boxes: none;
- horror or fear themes: none;
- medical or wellness content: none.

Users can capture or privately import their own photos, but CatLocal neither
publishes those photos nor provides access to other users' content.

## Availability

Recommended starting configuration:

- free;
- all territories where Yusufcan has distribution rights;
- manual release;
- no pre-order;
- no phased release for the first version.

The operator must make the final territory and release-method choices in App
Store Connect.
