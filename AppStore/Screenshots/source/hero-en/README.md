# CatLocal English Hero Sources

These files are editable Phase 1 comparison sources and are not production-final until visual approval.

- `frameless.html` renders the recommended frameless composition.
- `device.html` renders the neutral device-framed comparison.
- `hero.css` contains the shared canvas, headline, crop mask, shadow, and device-frame treatment.
- `assets/focused-card-physical-original.png` is the genuine focused-card capture from CatLocal on the authorized physical iPhone.
- `assets/genuine-card-crop.png` is a crop of that genuine capture at source coordinates `x: 100`, `y: 512`, `978 x 1528`. Its aspect ratio remains the app's genuine `0.64` card ratio.
- `assets/genuine-cutout-physical.png` is the transparent cutout saved by CatLocal's real Vision pipeline.
- `previews/` contains reduced-size visual-review exports.

The CSS rounded clip removes only the focused screen outside the genuine card boundary. It does not redraw, retouch, regenerate, or replace any content inside the card.

Do not create `01-catlocal-hero-en.png` until the frameless comparison has explicit approval. Do not stage or commit these sources or exports without separate approval.
