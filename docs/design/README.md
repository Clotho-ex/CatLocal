# Sunlit Gallery Archive

The selected visual direction combines the restraint of a contemporary gallery
catalogue with the warmth and energy of an Istanbul street archive.

- Pale mineral and limestone surfaces
- Ink and deep forest typography
- Warm apricot and cobalt details used sparingly
- Personal notes alongside structured metadata
- Native Liquid Glass tab navigation with camera as the detached primary action
- Foil light and depth reserved for focused cards, with a calm baseline until touch
- Home grid card thumbnails intentionally muted by blur/material so focused cards remain the premium reveal

The reference image in this folder is a visual target, not a literal layout
specification. Native behavior, legibility, and accessibility take priority.

## Handoff Notes From Foil And Editing Polish

- Card text is display-only on the card surface. Names, notes, and Catlas labels are edited in the capture/editor fields, not inline on the card.
- Focused cards can react to touch through tilt, spotlight, foil, and haptics. Grid thumbnails must stay visually quiet and inexpensive to render.
- `Midnight Prism`, `Gold Leaf`, and the topographic family are premium foil styles. Their animated light should appear only while the focused card is being touched.
- Topographic styles should read as visible contour lines over color, not flat rainbow washes.
- The theme carousel should feel endless and should give a small selection haptic while scrolling between styles.
- Typography is semantic and native-system through `CatTypography`. Use those roles for screen titles, page moments, panel titles, body copy, metadata, controls, field labels, and card text instead of adding one-off font sizes.

## Palette Guardrails

- Use warm limestone and paper tones for the app background, cards, settings surfaces, and image staging.
- Use deep ink/forest for primary text and sage-gray for supporting metadata.
- Use cobalt for primary actions and selected states so controls read clearly against the warm surfaces.
- Use Aegean teal for privacy proof, local/on-device explanations, and storage/information cues.
- Use terracotta/apricot for warnings and warm card accents, not as the default action color.
- Use moss green for saved, success, and manual place states so success feedback stays distinct from actions and warnings.
- Use destructive red only for permanent deletion. Do not reuse terracotta warning colors for delete actions.
- Apply color through `CatAttentionRole` washes, text, symbols, and strong fills instead of adding one-off colors in feature views.
- Use strokes sparingly. A semantic role does not automatically need a bordered pill or outlined row.
- Keep dark mode in the same role map: charcoal-green foundations, cream text, cobalt actions, terracotta warnings, and bright moss success.
