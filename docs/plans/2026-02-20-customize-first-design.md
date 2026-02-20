# Customize-First: Landing Page & Dashboard Redesign

**Date:** 2026-02-20
**Status:** Approved

## Problem

The landing page leads with content moderation ("The Backstage Advantage") as the primary value proposition. Users who want to customize games for their specific group (birthday party, bible study, team meeting) don't see that pitch until they're already logged in. Additionally, the dashboard surfaces content packs (the tool) before game templates (the workflow), which is backwards from how users think about their event.

## Goals

1. Pivot the landing page primary feature from moderation → customization
2. Make it clear that Google login unlocks game customization
3. Reorient the dashboard around "Customize a Game" (game templates) as the primary workflow, with content pack management as a discoverable sub-step

## Out of Scope

- Top nav bar with login button (future work)
- Any changes to the `/customize` hub page itself
- Any changes to game template or content pack functionality

---

## Landing Page Changes (`app/views/pages/landing.html.erb`)

### Section order (new)

1. Hero — **no change**
2. **NEW: "Games Built for Your Group"** — primary feature block
3. "The Backstage Advantage" — demoted, simplified
4. How It Works — step 3 updated
5. **NEW: Login callout** — sign in to customize
6. Footer CTA — no change

### Section 2 — New primary feature block

**Headline:** "Games Built for Your Group"

**Description:** "Pick a game mode, add your own questions or prompts, and save it as a template for your next event — birthday party, bible study, team meeting. RoomRally remembers your setup so you can launch in seconds."

**3-card grid:**
- **Game Templates** — Save a game config (type + content pack) and reuse it with one click
- **Custom Prompts** — Write Comedy Clash prompts tuned to your group's sense of humor
- **Custom Trivia** — Add questions about topics your group actually cares about

### Section 3 — Backstage Advantage (demoted)

Keep same 3 cards (Approve/Reject, No Accounts, Browser Based). Change heading from "The 'Backstage' Advantage" to something lighter like "Plus, you stay in control." Reduce visual weight to match a secondary feature.

### Section 4 — How It Works (step 3 only)

- Step 1: Launch — unchanged
- Step 2: Join — unchanged
- Step 3: **Customize** (was "Curate") — "Before your event, build a game template with your own questions or prompts. Launch it in seconds when the room is ready."

### Section 5 — Login callout (new, logged-out only)

Small callout between "How It Works" and the footer CTA. For logged-out users only:

> "Sign in with Google to save game templates and create custom content — free."
> [Google OAuth button]

---

## Dashboard Changes (`app/views/dashboard/index.html.erb`)

### "Customize Games" card → "Customize a Game"

- **Rename:** "Customize a Game"
- **Relink:** `/game_templates/new` (was `/customize`)
- **New copy:** "Create a game template for your next event — pick a game type, add a custom content pack, and save it for one-click launching."
- **Sub-link:** "Manage content packs →" pointing to `/customize`

All other sections (My Games, Recent Prompt Packs, Host a Game) remain in place.

---

## `/play` Page Changes (`app/views/home/index.html.erb`)

Add one line near the Google login button:

> "Sign in to save game templates and create custom content."
