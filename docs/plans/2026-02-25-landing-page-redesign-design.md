# Landing Page Redesign — Design Doc
**Date:** 2026-02-25

## Problem

The current landing page has three core issues:
1. **Too much scroll, too little content per view** — oversized logo (`h-64`–`h-72`), sections with `p-12–p-16` padding and `mb-16–mb-24` gaps, and full-width screenshots dominate vertical space
2. **No game mode showcase** — visitor has no idea what games are available or why they're fun before being asked to host/join
3. **"How It Works" is anemic** — three steps with one sentence each, in the wrong order (Launch → Join → Customize instead of Choose → Customize → Launch → Play)

## Design Approach: Hero with Embedded Game Tiles (Approach B)

The game tiles become the hero's visual centerpiece — all three modes are visible near the top, answering "what is this?" before the visitor decides to scroll. Subsequent sections are tighter.

## Section Order (new)

1. Hero (logo + tagline + game tiles + CTA buttons)
2. Customization ("Games Built for Your Group")
3. Moderation (compact strip)
4. How It Works (expanded, 4 steps)
5. Sign-in CTA (logged-out only, unchanged)
6. Footer CTA (unchanged)

---

## Section 1: Hero

**Logo:** `h-20 md:h-28` (~96px). Compact but present.

**Tagline:** `text-2xl md:text-3xl` — same copy ("Where 'you had to be there' begins."), less vertical cost.

**Game tiles:** 3-column grid (`grid-cols-1 sm:grid-cols-3`), directly below tagline. Each tile is a gradient card with:
- SVG icon at top (large, ~48px)
- Game name (`text-xl font-black`)
- Tagline (punchy 1-liner)
- "How you play" descriptor (1–2 lines, smaller text)
- Distinct gradient background, `rounded-2xl`, `shadow-xl`

| Game | Icon | Gradient | Tagline | How you play |
|------|------|----------|---------|--------------|
| Comedy Clash | Mic | purple-600 → pink-500 | "Your words, their laughs" | Write funny answers to prompts. The room votes for the best. |
| A-List | Checklist/list | teal-600 → emerald-500 | "Think fast, list faster" | Name as many as you can before time runs out. |
| Think Fast | Lightning bolt | orange-500 → red-500 | "Trivia with a twist" | Answer before the clock does. |

**Designed for future splash art:** tile layout is image-ready — the gradient is a background layer, and a splash image can replace it later with zero layout changes (similar to the Framer stacked/draggable card pattern seen at reference site).

**CTA buttons:** Host a Game + Join a Game, unchanged, below tiles.

---

## Section 2: Customization

Same content as today. Spacing reduced:
- `p-8 md:p-10` (was `p-12 md:p-16`)
- `mb-10 md:mb-16` (was `mb-16 md:mb-24`)
- Screenshot and 3 feature cards (Templates, Custom Prompts, Custom Trivia) unchanged

---

## Section 3: Moderation (compact)

Becomes a single compact horizontal strip — no large heading, no screenshot. Three items inline:

> ✓ **Approve or reject** submissions before they hit the screen · 🔓 **No player accounts** — join via QR code · 🌐 **Any device**, nothing to install

Implemented as a `flex` row of 3 icon+text items in a thin card (`p-6`, half the current height). The host dashboard screenshot is dropped from this section.

---

## Section 4: How It Works (expanded)

Four steps, corrected order. Structure for host to fill in exact wording:

1. **Pick Your Game Mode** — Three modes available (Comedy Clash, A-List, Think Fast). Brief description of each or a general "pick what sounds fun."
2. **Make It Yours** — Customize prompts/questions to fit your group. Save as a reusable template so your next launch is one click.
3. **Launch & Display** — Host starts the session, projects on the big screen (TV, projector) via browser tab. No cables, no app.
4. **Everyone Joins & Plays** — Players scan the QR code from their phones. No accounts, no installs. Game begins.

Visual treatment: numbered orange circles (existing pattern), two-column layout (`number+icon | text`), 3–4 sentences per step instead of 1.

**Copy:** Placeholder copy used in implementation. Host to supply final wording before launch.

---

## Scroll Improvement Estimate

- Hero section: ~3 viewport-heights → ~1 (tiles fit near fold on laptop)
- Two screenshots remain but surrounding sections are tighter
- Total page height: ~35–40% reduction

---

## Future: Stacked/Draggable Cards

The Framer-style stacked card pattern (slight rotation, drop shadow, drag-to-reorder) is noted for a future iteration of the game mode tiles. The current gradient card layout is designed to accommodate this upgrade: same card structure, same dimensions, same content — just add `transform: rotate(Ndeg)` and a drag library.

---

## Files to Modify

- `app/views/pages/landing.html.erb` — primary file, full rewrite of layout
- No controller, model, or route changes needed
