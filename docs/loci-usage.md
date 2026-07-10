# Loci Usage Rules

Loci is CatLocal's restrained guide-cat mascot. Loci should explain, reassure,
recover, and celebrate only when that helps the user. Loci must not compete with
the user's saved cat cards.

## Use Loci For

- Empty collection states before the first saved card.
- Successful card creation, only as a small companion to the saved card.
- Recoverable warning states where the user can still improve or continue.
- Failure recovery states where reassurance helps the user try again.
- First-time glint or card-light education while the user is not touching the
  card.
- One explicit first-run privacy education moment.

## Avoid Loci For

- General onboarding decoration, onboarding welcome screens, settings rows,
  repeated privacy receipts, and ordinary information panels.
- Normal browsing once the user's cards are present.
- Dense settings rows, destructive confirmations, or every modal.
- Short loading moments where progress UI is enough.
- Card surfaces where the user's cat photo should be the focus.
- Repeated decorative appearances that make CatLocal feel loud or childish.

## State Mapping

All mascot rendering should route through `LociMascotState.state(for:)` so
context, pose, motion, title, and subtitle stay in sync.

| App context | Loci pose | Motion | Use |
| --- | --- | --- | --- |
| Empty collection | `loci_presenting` | `idle` | First empty Home state only. |
| Card saved | `loci_cardReady` | `successPop` | Small saved-card companion. |
| Recoverable warning | `loci_inspecting` | `thinking` | Continue path is available. |
| Generic recovery | `loci_curious` | `errorTilt` | Processing failed but retry/fallback exists. |
| No cat detected recovery | `loci_noCatFound` | `errorTilt` | CatLocal cannot confirm a cat. |
| Image quality warning | `loci_inspecting` | `thinking` | Blurry, dark, or difficult cutout. |
| First-time glint hint | `loci_hint` | `idle` | Focused-card education only. |
| Privacy education | `loci_privacy` | `none` | Explicit first-run privacy cue only. |

## Asset Catalog Rules

Assets live in `CatLocal/Resources/Assets.xcassets/Loci` and are referenced by
their exact image names. The Loci asset folder must not provide a namespace.

Required assets:

- `loci_neutral`
- `loci_presenting`
- `loci_curious`
- `loci_greeting`
- `loci_icon`
- `loci_noCatFound`
- `loci_inspecting`
- `loci_cardReady`
- `loci_hint`
- `loci_privacy`

Asset standards:

- Use final transparent PNGs with real alpha.
- Do not bake in checkerboards, solid backgrounds, text, logos, or heavy drop
  shadows.
- Keep visual scale and foot baseline consistent across full-body poses.
- Use single-scale image sets, Render As Default, Compression Automatic, and
  Appearances None.
- Keep asset names stable because `LociPose.rawValue` maps directly to the image
  set names.

## Animation Rules

- Respect Reduce Motion.
- Use transform-only animations: scale, rotation, opacity, and offset.
- Use smooth pose transitions, but avoid layout-moving mascot animation.
- Use idle motion only for calm empty states and first-time glint education.
- Use thinking motion only for recoverable warnings.
- Use success pop only after a card is saved.
- Use error tilt only for no-cat-detected recovery or generic recoverable
  failure.
- Do not animate Loci while the user is directly interacting with a card.
- Keep privacy education static unless the surrounding surface explicitly needs
  transition motion.

## Placement Rules

- Place empty-state Loci beside the placeholder card when there is room, not as
  a dominating hero above the whole page.
- Place saved-card Loci small and secondary to the minted card.
- Place warning and failure Loci near recovery copy and controls.
- Do not place Loci in Settings, routine privacy receipts, normal browsing,
  destructive confirmations, or every modal.

## Loading Rule

Do not use Loci for very short loading states. Use Loci only when processing
takes long enough to require reassurance or explanation.

## Expansion Rule

Adding a new mascot asset does not mean adding a new mascot appearance. Loci
should appear only when the user benefits from guidance, reassurance, recovery,
or feedback.

## Copy Rules

- Keep copy short and grounded in existing CatLocal language.
- Important messages must be real text, not only mascot pose.
- Privacy copy should stay calm and explicit.
- Recovery copy should help the user try again without blame.
