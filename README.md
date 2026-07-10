# CatLocal

CatLocal is a private, local-first iPhone journal that turns real cat
encounters into tactile collectible cards.

## Core Loop

1. Photograph a cat or choose a private photo.
2. Detect and separate the cat with Apple Vision on-device.
3. Reveal a card, choose a design, and add an optional name or note.
4. Save the card and its images locally with SwiftData and Application Support.

## Privacy

- No account, backend, public map, GPS coordinates, advertising, or cloud AI.
- Catlas place labels are typed intentionally by you and stay local.
- Originals are rewritten without EXIF or GPS metadata before local storage.
- Cat recognition and foreground separation happen on the device.

## Platform

- Swift 6 with complete concurrency checking.
- iOS 18 minimum deployment target.
- Native SwiftUI tabs and Liquid Glass controls on iOS 26 with material-based fallbacks where custom surfaces are needed.

Open `CatLocal.xcodeproj` and run the shared `CatLocal` scheme.

## Project Map

- `CatLocal/App`: app entry point and root navigation.
- `CatLocal/Core`: SwiftData model and camera/image/Vision services.
- `CatLocal/Features`: capture, Home/Catlas, and settings screens.
- `CatLocal/Shared`: design system and reusable UI components.
- `CatLocal/Resources`: asset catalog.
- `docs/architecture.md`: implementation architecture and handoff notes.
- `docs/design/README.md`: product, brand, visual system, and interaction guardrails.
- `docs/loci-usage.md`: Loci mascot state, placement, animation, and asset rules.
- `AGENTS.md`: working rules for future coding agents.
