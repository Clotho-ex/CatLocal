# Product

## Register

product

## Users

CatLocal is for iPhone users who notice real cats in everyday life and want a private, tactile record of those encounters without joining a network, publishing a map, or uploading photos for cloud processing. They are usually in a quick capture or quiet review context: photograph or privately import a cat, let the app separate the subject on device, personalize the resulting card, and return later to browse a small personal collection.

## Product Purpose

CatLocal turns real cat encounters into local collectible cards. Its purpose is to make capture, on-device Vision processing, card reveal, editing, storage, and later browsing feel trustworthy, calm, and personal. Success means the user understands that their photos stay on the device, can save a polished card without friction, and can revisit the collection through Home, focused card detail, Settings, and Catlas without the product drifting into social discovery, public maps, accounts, or cloud services.

## Brand Personality

Quiet, tactile, editorial.

CatLocal should feel like a private field journal and a small sea-glass archive: warm but restrained, premium but not precious, playful in the card moments without turning the surrounding app into decoration. The app earns delight through native iOS behavior, tactile motion, local privacy proof, and collectible card craft.

## Anti-references

- Public cat maps, social feeds, follower graphs, leaderboards, discovery networks, or anything that implies shared location data.
- Generic camera utilities that treat the card reveal as a file-processing step instead of the emotional reward.
- Over-glassy interfaces where every card or panel becomes Liquid Glass and competes with the cat cards.
- Fake sample cats, invented social proof, placeholder metrics, or marketing claims not backed by the app.
- Inline card editing, repeated contextual labels, or redundant headers that add visual noise to already-scoped screens such as Catlas.
- Heavy premium effects in scrolling grids; foil, spotlight, and tilt should be reserved for focused cards and previews.

## Design Principles

1. Lead with the capture-to-card loop.
   Every major decision should serve `capture/import -> on-device Vision -> card reveal/editor -> local collection`.

2. Make privacy visible through behavior.
   Use local-only architecture, EXIF/GPS stripping, manual Catlas labels, and clear proof points instead of vague privacy promises.

3. Keep the interface quiet so the cards can feel special.
   Home, Catlas, Settings, and edit fields should be legible and restrained; focused cards carry the richer foil, depth, and tactile interaction.

4. Prefer native iOS patterns where they improve trust.
   Use system navigation, tabs, sheets, controls, haptics, Dynamic Type, VoiceOver behavior, and Liquid Glass selectively instead of custom chrome for its own sake.

5. Preserve real data shape.
   Saved cards come from actual captures/imports, SwiftData metadata, local image files, sequence numbers, notes, and manual place labels. Do not invent accounts, maps, remote media, or sample content to make a screen look fuller.

## Accessibility & Inclusion

CatLocal should meet standard iOS accessibility expectations and maintain WCAG-conscious contrast across card and app surfaces. Dynamic Type must be respected without clipping card details, sheet fields, settings copy, or empty states. VoiceOver should read cards as cohesive cat records rather than disconnected text fragments. Motion should respect Reduce Motion; focused-card tilt and foil effects need non-visual and reduced-motion alternatives. Haptics should be tactile and meaningful, never continuous buzzing.
