# Turbo Morph Broadcasts Design

## Problem

Full DOM replacement on every broadcast causes three UX issues:

1. **Waiting jitter** — when another player submits, every player's hand re-renders even if nothing changed for them. Full innerHTML swap causes layout reflow and visual flicker.
2. **Phase transition flash** — switching game phases nukes the entire target and rebuilds, causing a blank frame before new content paints.
3. **Animation restart** — CSS animations on unchanged elements restart on every broadcast because the DOM nodes are destroyed and recreated.

## Solution

Replace `broadcast_update_to` with `broadcast_action_to(action: :morph)` for high-churn targets. Turbo 8's idiomorph diffs incoming HTML against the current DOM and patches only what changed. Unchanged elements stay in place — no reflow, no animation restart, no blank frame.

## Scope

### Changes (Approach A — targeted morph)

**`GameBroadcaster`** — four broadcast sites switch to morph:

| Method | Target | Why morph helps |
|--------|--------|-----------------|
| `broadcast_hand` | `hand_screen` (per-player) | Eliminates jitter when nothing changed for the receiving player |
| `broadcast_stage` | `stage_content` (room-wide) | Preserves animations, reduces reflow on score/timer updates |
| `update_all_host_controls` | `host-controls`, `backstage-host-controls` | Same content re-rendered frequently during gameplay |

**`RendersHand`** — HTTP response switches from `turbo_stream.update` to `turbo_stream.action(:morph, ...)` for consistency with broadcast behavior.

### Not changed

- `broadcast_append_to`, `broadcast_prepend_to`, `broadcast_remove_to`, `broadcast_replace_to` — structurally correct actions for adding/removing elements
- Views, partials, Stimulus controllers, routes, models — zero changes
- `broadcast_game_start`, `clear_moderation_queue` — these update small static HTML targets where morph adds no value

### ID stability

Morph matches elements by `id` attribute to decide what to patch vs replace. Partials that render lists must use stable IDs (e.g., `dom_id(player)`) on each item. This is already the convention in the codebase.

## Follow-on: Tap Feedback (Approach C)

Separate branch. A `tap_feedback_controller` Stimulus controller providing instant visual feedback on `pointerdown` (opacity + scale) before form submission. Applied to hand view game action containers.

## Testing

- Existing system specs exercise full broadcast flow — regressions will surface there.
- Manual playtest with 2+ players to verify visual improvements.

## Technical notes

- `turbo-rails 2.0.23` supports `broadcast_action_to(action: :morph)` — verified in Rails console.
- No `broadcast_morph_to` convenience method exists; `broadcast_action_to` is the generic API.
- Morph falls back to full replacement when DOM structures differ completely (phase transitions), which is correct behavior.
