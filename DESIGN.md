---
name: CatLocal
description: A private, local-first iPhone journal that turns real cat encounters into tactile collectible cards.
colors:
  sea-glass-bg: "#DCEAE5"
  deep-forest-bg: "#061210"
  porcelain-glow: "#F8FFFC"
  dark-sea-glow: "#103B35"
  chalk-surface: "#CBDDD6"
  deep-chalk-surface: "#142C27"
  card-surface: "#FEFFFB"
  dark-card-surface: "#1C352F"
  forest-ink: "#12211E"
  porcelain-ink: "#F4FFF7"
  eucalyptus-text: "#3F5750"
  mist-text: "#BCD1CA"
  cobalt-action: "#005F68"
  cobalt-action-dark: "#84E0DC"
  cobalt-wash: "#D3EAEC"
  cobalt-wash-dark: "#0D3D3C"
  apricot-warning: "#93440F"
  apricot-warning-dark: "#F2AF6D"
  apricot-wash: "#F1DDCD"
  apricot-wash-dark: "#3B230F"
  sage-archive: "#BBD4CC"
  sage-archive-dark: "#233C35"
  azurite-info: "#3458A6"
  azurite-info-dark: "#B7C8FF"
  moss-success: "#236F45"
  moss-success-dark: "#A5E4B0"
  rose-destructive: "#A51C34"
  rose-destructive-dark: "#FFB2C0"
typography:
  display:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, system-ui, sans-serif"
    fontSize: "34px"
    fontWeight: 600
    lineHeight: 1.12
    letterSpacing: "0"
  headline:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, system-ui, sans-serif"
    fontSize: "22px"
    fontWeight: 600
    lineHeight: 1.18
    letterSpacing: "0"
  title:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.24
    letterSpacing: "0"
  body:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.35
    letterSpacing: "0"
  label:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "0"
rounded:
  input: "16px"
  chip: "18px"
  thumbnail-card: "22px"
  action: "24px"
  panel: "26px"
  glass-action: "28px"
  focused-card: "34px"
spacing:
  xs: "6px"
  sm: "10px"
  md: "14px"
  lg: "18px"
  screen-x: "22px"
  xl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.cobalt-action}"
    textColor: "#FFFFFF"
    typography: "{typography.title}"
    rounded: "{rounded.action}"
    height: "56px"
    padding: "0 18px"
  button-secondary:
    backgroundColor: "{colors.card-surface}"
    textColor: "{colors.forest-ink}"
    typography: "{typography.title}"
    rounded: "{rounded.action}"
    height: "52px"
    padding: "0 18px"
  button-commit:
    backgroundColor: "{colors.cobalt-wash}"
    textColor: "{colors.forest-ink}"
    typography: "{typography.title}"
    rounded: "{rounded.action}"
    height: "64px"
    padding: "0 16px"
  input-field:
    backgroundColor: "{colors.card-surface}"
    textColor: "{colors.forest-ink}"
    typography: "{typography.body}"
    rounded: "{rounded.input}"
    padding: "14px 16px"
  card-thumbnail:
    backgroundColor: "{colors.card-surface}"
    textColor: "{colors.forest-ink}"
    rounded: "{rounded.thumbnail-card}"
    padding: "11px"
  card-focused:
    backgroundColor: "{colors.card-surface}"
    textColor: "{colors.forest-ink}"
    rounded: "{rounded.focused-card}"
    padding: "16px"
---

# Design System: CatLocal

## 1. Overview

**Creative North Star: "Sea-Glass Field Archive"**

CatLocal is a native iPhone product, not a marketing surface. The visual system should feel like a private field journal and a small sea-glass archive: cool, local, tactile, and careful with the user's photos. The product loop is the organizing spine: `capture/import -> on-device Vision -> transparent cutout -> card reveal/editor -> local collection`.

The app earns delight through restraint. Everyday screens use native iOS structure, semantic color, quiet surfaces, and readable controls. The richer material effects - foil, spotlight, tilt, mascot motion, and stronger haptics - are reserved for focused card moments, recovery, and saved-card success.

The system rejects public-map energy, social-feed patterns, generic camera utility chrome, fake sample data, over-glassy panels, and premium effects in scrolling grids. The user's real cat cards are the hero; CatLocal's interface should hold them carefully, not compete with them.

**Key Characteristics:**

- Local-first and private by default.
- Editorial, tactile, and restrained.
- Native SwiftUI controls before custom chrome.
- Semantic state color: cobalt action, apricot warning, moss success, azurite privacy/info.
- Motion and haptics mark state, intent, and completion only.

## 2. Colors

CatLocal uses a restrained sea-glass palette with one primary action color and distinct semantic roles for privacy, success, warning, and destructive states.

### Primary

- **Cobalt Action**: The primary action and selected-state color. Use it for camera/import affordances, primary buttons, current choices, and focused interaction hints. It must stay rare enough to mean "act now".
- **Cobalt Wash**: The quiet action wash for commit surfaces, selected chips, and low-pressure action panels.

### Secondary

- **Apricot Warning**: Warm attention for recoverable problems, camera emphasis, cutout uncertainty, and warning states. Never use apricot for permanent deletion.
- **Azurite Info**: Privacy proof and on-device education. Use it for "on this iPhone" explanations, storage clarity, and no-GPS/no-cloud cues.
- **Moss Success**: Saved, safe, complete, or manually placed states. Use moss for completion and privacy reassurance, not as the default action color.

### Tertiary

- **Sage Archive**: Archive wash and calm fill. It supports the sea-glass mood without becoming a primary action.
- **Rose Destructive**: Deletion only. It should be unmistakable and never softened into a generic warning.

### Neutral

- **Sea-Glass Background**: The light app base. It is cool and mineral, not beige paper.
- **Deep Forest Background**: The dark app base. It should feel quiet and legible, not sci-fi black.
- **Porcelain Glow**: Soft environmental light behind first-run and empty states.
- **Chalk Surface**: Elevated panels, empty states, and grouped content.
- **Card Surface**: Card faces, settings surfaces, input backgrounds, and tactile editorial panels.
- **Forest Ink**: Primary text and card labels in light mode.
- **Porcelain Ink**: Primary text in dark mode.
- **Eucalyptus Text / Mist Text**: Supporting copy, metadata, timestamps, and secondary explanations.

### Named Rules

**The Semantic Color Rule.** Cobalt means action, apricot means recoverable warning, moss means success or safety, azurite means privacy/info, and rose means destructive. Do not borrow one role to decorate another.

**The Cards First Rule.** Background and panels stay quiet enough that real saved cards carry the emotional color.

**The No Beige Archive Rule.** The archive mood comes from sea-glass, porcelain, sage, and ink. Do not drift into cream, parchment, sand, or generic scrapbook beige.

## 3. Typography

**Display Font:** SF Pro system typography with native iOS Dynamic Type.
**Body Font:** SF Pro system typography with native iOS Dynamic Type.
**Label/Mono Font:** SF Pro for labels; rounded monospaced digits only for card sequence marks.

**Character:** The type system is compact, native, and editorial. It should feel like a polished iOS journal, not a display-font brand campaign.

### Hierarchy

- **Display** (semibold, iOS large title, 34px default): App-level titles and the strongest first-run/empty-state moments only.
- **Headline** (semibold, iOS title2/title3 range, 20-22px default): Capture moments, onboarding page titles, card reveal states, and failure recovery.
- **Title** (semibold, iOS headline, 17px default): Section headers, buttons, sheet actions, and primary controls.
- **Body** (regular, iOS body, 17px default): Explanatory copy, notes, settings text, and card details. Keep prose compact and allow Dynamic Type wrapping.
- **Label** (semibold, iOS footnote/caption, 11-13px default): Field labels, badges, metadata, compact chips, and card place labels.

### Named Rules

**The Native Type Rule.** Use `CatTypography` and Dynamic Type. Do not introduce a new font family or fluid marketing scale for app UI.

**The No Eyebrow Reflex Rule.** Avoid tiny uppercase tracked labels as generic section decoration. Labels must identify a real field, chip, or metadata role.

**The Card Text Rule.** Card text is display-only on the card surface. Names, notes, and Catlas labels are edited through fields or sheets.

## 4. Elevation

CatLocal uses a hybrid of tonal layering, one-pixel strokes, and restrained shadows. Elevation should feel tactile and editorial rather than glassy. Shadows are real but quiet; they clarify layered cards, inputs, panels, and focused surfaces without making every object float.

### Shadow Vocabulary

- **Glass Action Shadow** (`shadow.opacity(0.16), radius 7, y 3`): Compact glass action controls and icon buttons.
- **Input Shadow** (`shadow.opacity(0.11), radius 7, y 2`): Text fields and user-editable surfaces.
- **Panel Shadow** (`shadow.opacity(0.13), radius 10, y 4`): Settings panels, empty-state surfaces, and grouped content.
- **Commit Shadow** (`role.accent.opacity(0.12), radius 9, y 3`): Save and commit surfaces only.
- **Thumbnail Card Shadow** (`shadow.opacity(0.16), radius 8, y 4`): Cheap grid card depth.
- **Focused Card Shadow** (`shadow.opacity(0.72), radius 22, y 14`): Full card focus and reveal moments.
- **Skeleton Card Shadow** (`shadow.opacity(0.14), radius 14, y 8`): Decorative empty-state mock card depth.

### Named Rules

**The Focus Earns Depth Rule.** Strong shadows belong to focused cards and saved-card celebration. Scrolling grids stay cheap, muted, and calm.

**The One-Pixel Structure Rule.** Use hairline strokes for structure. Never use thick side stripes or decorative border accents.

## 5. Components

CatLocal components should feel native, tactile, and restrained. Prefer `Button`, SwiftUI sheets, Dynamic Type, VoiceOver grouping, and semantic modifiers from `CatLocalTheme`.

### Buttons

- **Shape:** Action buttons use gently rounded rectangles (24px). Compact glass icon actions are circular or capsule-like (28px).
- **Primary:** Cobalt or role-accent gradient, strong foreground, full-width, 56px minimum height.
- **Commit:** Soft role wash to card-surface gradient, 1px role stroke, 64px minimum height, and a small accent shadow. Use for Save Cat / Add to Collection moments.
- **Secondary:** Card-surface fill, forest ink text, 1px image-outline stroke, 52-56px minimum height.
- **Hover / Focus / Press:** Native iOS focus plus `catTactile`: scale to 0.982, tiny brightness dip, 0.14s smooth animation. Haptics mark intent or completion; do not stack several pulses for the same save moment.

### Chips

- **Style:** Attention chips use role wash, role text, 18px corners, 34-38px minimum height, and compact semibold labels.
- **State:** Use chips for real option sets, proof points, status, or card anatomy. Do not turn every short phrase into a badge.

### Cards / Containers

- **Corner Style:** Thumbnail cards use 22px, style previews use 24px, focused cards use 34px, image stages use 16-26px.
- **Background:** `cardSurface` for tactile card faces, role-derived procedural surfaces for card styles, and `chalk` for elevated app panels.
- **Shadow Strategy:** Thumbnail cards use cheap low shadows; focused cards use the strongest depth; card grids avoid live tilt and heavy foil.
- **Border:** 1px `imageOutline` or style-derived separator only.
- **Internal Padding:** Thumbnail card 11px, style preview 12px, focused card 16px.

### Inputs / Fields

- **Style:** `cardSurface` fill, forest ink text, cobalt tint, 16px corners, 14px vertical and 16px horizontal padding.
- **Focus:** Native focus behavior plus cobalt caret/tint. Avoid custom focus rings that fight iOS.
- **Error / Disabled:** Use semantic roles: warning for recoverable input/cutout issues, destructive for deletion only, secondary text for disabled.

### Navigation

- **Style:** Native SwiftUI tabs and sheets. `RootView` uses `TabView` with sidebar-adaptable behavior and iOS 26 Liquid Glass where the platform provides it.
- **Active State:** Let native tabs own active state. The camera action is special because it starts capture, not because it is a custom floating element.
- **Mobile Treatment:** This is an iPhone-first app. Respect safe areas, Dynamic Type, VoiceOver order, and native sheet behavior.

### Signature Component: Cat Card

Cat cards are the product artifact. They render real local images, sequence numbers, dates, optional notes, manual Catlas labels, and a chosen card style. Card surfaces may use procedural material effects, but the card remains display-only; edit in fields and sheets. Focused cards can use foil, spotlight, tilt, and stronger depth. Grid thumbnails stay static and muted.

### Signature Component: Loci Mascot

Loci is a restrained guide, not a mascot overlay for every screen. Use Loci only for empty collection, recovery, warnings, saved-card success, first-time hint education, and explicit privacy education. Motion must respect Reduce Motion and use transform/opacity only.

## 6. Do's and Don'ts

### Do:

- **Do** lead with `capture/import -> on-device Vision -> card reveal/editor -> local collection`.
- **Do** use `CatLocalTheme`, `CatTypography`, `CatAttentionRole`, and shared surface modifiers before adding one-off styling.
- **Do** make privacy visible through concrete behavior: no account, no map tracking, no cloud database, EXIF/GPS removal, and on-device Vision.
- **Do** keep Home, Catlas, Settings, and edit fields legible and restrained so focused cards can feel special.
- **Do** reserve foil, spotlight, tilt, mascot motion, and stronger haptics for moments that need emphasis.
- **Do** respect Dynamic Type, VoiceOver, Reduce Motion, and native iOS interaction semantics.

### Don't:

- **Don't** build public cat maps, social feeds, follower graphs, leaderboards, discovery networks, or anything that implies shared location data.
- **Don't** make CatLocal feel like a generic camera utility where card reveal is just file processing.
- **Don't** create over-glassy interfaces where every card or panel becomes Liquid Glass and competes with the cat cards.
- **Don't** use fake sample cats, invented social proof, placeholder metrics, or marketing claims not backed by the app.
- **Don't** reintroduce inline card editing, repeated contextual labels, or redundant headers on already-scoped screens such as Catlas.
- **Don't** put heavy premium effects in scrolling grids; foil, spotlight, and tilt are for focused cards and previews.
- **Don't** use side-stripe borders, gradient text, decorative grid backgrounds, beige scrapbook palettes, or loud purple/blue gradients.
