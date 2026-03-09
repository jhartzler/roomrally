# Turbo Morph Broadcasts Design

## Problem

Full DOM replacement on every broadcast causes three UX issues:

1. **Waiting jitter** — when another player submits, every player's hand re-renders even if nothing changed for them. Full innerHTML swap causes layout reflow and visual flicker.
2. **Phase transition flash** — switching game phases nukes the entire target and rebuilds, causing a blank frame before new content paints.
3. **Animation restart** — CSS animations on unchanged elements restart on every broadcast because the DOM nodes are destroyed and recreated.

## Solution

Add `method: :morph` attribute to `broadcast_action_to` calls for high-churn targets. Turbo 8's idiomorph diffs incoming HTML against the current DOM and patches only what changed. Unchanged elements stay in place — no reflow, no animation restart, no blank frame.

## Scope

### Changes (Approach A — targeted morph)

**`GameBroadcaster`** — four broadcast sites switch to morph:

| Method | Target | Why morph helps |
|--------|--------|-----------------|
| `broadcast_hand` | `hand_screen` (per-player) | Eliminates jitter when nothing changed for the receiving player |
| `broadcast_stage` | `stage_content` (room-wide) | Preserves animations, reduces reflow on score/timer updates |
| `update_all_host_controls` | `host-controls`, `backstage-host-controls` | Same content re-rendered frequently during gameplay |

**`RendersHand`** — HTTP response switches to `turbo_stream.action(:update, ..., method: :morph)` for consistency.

### Not changed

- `broadcast_append_to`, `broadcast_prepend_to`, `broadcast_remove_to`, `broadcast_replace_to` — structurally correct actions for adding/removing elements
- Views, partials, Stimulus controllers, routes, models — zero changes
- `broadcast_game_start`, `clear_moderation_queue` — these update small static HTML targets where morph adds no value

### ID stability

Morph matches elements by `id` attribute to decide what to patch vs replace. Partials that render lists must use stable IDs (e.g., `dom_id(player)`) on each item. This is already the convention in the codebase.

### API detail

Turbo 8 morph is NOT a separate stream action. It's a `method` attribute on the existing `update` (or `replace`) action:

```html
<turbo-stream action="update" target="hand_screen" method="morph">
```

In Rails: `broadcast_action_to(stream, action: :update, attributes: { method: :morph }, target:, partial:, locals:)`

## Follow-on: Tap Feedback (Approach C)

Separate branch. A `tap_feedback_controller` Stimulus controller providing instant visual feedback on `pointerdown` (opacity + scale) before form submission. Applied to hand view game action containers.

## Testing

- All 212 unit/request specs pass
- All 84 system specs pass (0 failures, 10 pending screenshot-only)
- Rubocop clean
