# CatLocal

CatLocal is a private, local-first iPhone journal that turns real cat
encounters into tactile collectible cards.

## Core Loop

1. Photograph a cat or choose a private photo.
2. Detect and separate the cat with Apple Vision on-device.
3. Reveal a card, choose a design, and add an optional name or note.
4. Save the card and its images locally with SwiftData and Application Support.

## Privacy

- No account, backend, public map, location collection, advertising, or cloud AI.
- Originals are rewritten without EXIF or GPS metadata before local storage.
- Cat recognition and foreground separation happen on the device.

## Platform

- Swift 6 with complete concurrency checking.
- iOS 18 minimum deployment target.
- Native Liquid Glass controls on iOS 26 with material-based fallbacks.

Open `CatLocal.xcodeproj` and run the shared `CatLocal` scheme.
