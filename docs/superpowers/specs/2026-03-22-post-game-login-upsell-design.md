# Post-Game Login Upsell — Design Spec

## Problem

Logged-out room creators host games, have a great time, and leave without ever knowing they could customize games or moderate content by signing up. There's no touchpoint between "game over" and "goodbye" that surfaces these benefits.

## Solution

A soft, non-intrusive upsell card rendered inside the post-game hand view for logged-out room hosts only. The card appears below game scores and the feedback CTA — never blocking content the host wants to see.

## Visibility Logic

The upsell renders when **all conditions** are true:

| Condition | Check |
|-----------|-------|
| Player is the room host | `player == room.host` |
| Room has no logged-in owner | `room.user.nil?` |

The game being finished is implicit — the partial is only rendered inside `_game_over.html.erb`.

**Who does NOT see it:**
- Regular players (not the host)
- Logged-in hosts (`room.user` is present)
- Backstage users (they're already logged in)

No dismissal tracking. The card shows every game. It's soft enough that repetition is acceptable, and logged-out hosts who don't want to sign up aren't a retention priority.

## Implementation

### New file

**`app/views/games/shared/_login_upsell.html.erb`**

A shared partial containing:
- Visibility guard: `<% if player == room.host && room.user.nil? %>`
- Headline: "You just hosted like a pro."
- Two benefit lines:
  - "Make it yours — create custom questions, prompts, and categories."
  - "Keep it clean — moderate answers before they hit the big screen."
- CTA button text: "Sign up free"
- CTA link styled as a button, linking to `host_path`
- Styling: `bg-white/10 backdrop-blur-md rounded-2xl border border-white/20` — matches existing glassmorphism cards

### Modified files

Add `<%= render "games/shared/login_upsell", room: room, player: player %>` to three game-over partials:

1. **`app/views/games/write_and_vote/_game_over.html.erb`** — after `<%= render "shared/feedback_cta" %>`, before the "Back to Home" link
2. **`app/views/games/speed_trivia/_game_over.html.erb`** — after the mini leaderboard (end of file)
3. **`app/views/games/category_list/_game_over.html.erb`** — after the mini leaderboard (end of file)

Note: In Write And Vote the upsell sits between feedback CTA and the "Back to Home" link. In Speed Trivia and Category List it sits after the leaderboard (no "Back to Home" link exists). This inconsistency is intentional — the upsell goes at the natural bottom of each game's layout.

### Copy voice

Follows `docs/copy-voice.md` — warm hype-man tone. "You're already great, here's how to level up" rather than "you're missing out." Under 3 seconds to read.

### What does NOT change

- No model changes
- No controller changes
- No route changes
- No JavaScript/Stimulus changes
- No broadcast changes
- No database changes

## Testing

### System spec

One system spec covering:

1. **Logged-out host sees upsell** — create a room without a logged-in user, play a game to completion, verify the host's hand view contains the upsell card
2. **Regular player does not see upsell** — same game, verify a non-host player's hand view does not contain the upsell
3. **Logged-in host does not see upsell** — create a room with a logged-in user, play a game to completion, verify the host's hand view does not contain the upsell

Use one game type (Speed Trivia is simplest to drive to completion via service methods) — the partial logic is identical across all three.

## Design decisions

| Decision | Rationale |
|----------|-----------|
| Shared partial, not per-game | Same content for all games; one file to maintain |
| Render inside `_game_over`, not router | Keeps router simple (8 lines); upsell is game-over-specific |
| No dismissal tracking | Card is non-intrusive; repetition is acceptable for free users |
| Link to `host_path` not OAuth directly | Hosts page has context + sign-in; destination can change later without touching the upsell |
| Below feedback CTA | Scores → feedback → upsell → home. Most important content first |
