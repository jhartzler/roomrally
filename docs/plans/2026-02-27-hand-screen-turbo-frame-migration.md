# Hand Screen Turbo Frame Migration

**Date:** 2026-02-27
**Updated:** 2026-03-03
**Status:** Approved — ready for implementation

## Problem

The player hand view (`rooms/:code/hand`) has a structural tension between two
update mechanisms:

1. **HTTP responses** — player actions (submit answers, cast votes) fire a Turbo
   form POST and get back `head :no_content` (204). The controller says "got it,
   nothing to render."
2. **WebSocket broadcasts** — `GameBroadcaster.broadcast_hand` pushes the new
   hand state to the player via Action Cable after the action is processed.

This push-only model means the player's phone always experiences a two-step
update: submit → wait for broadcast → see result. The latency gap is usually
imperceptible on a good WiFi network, but it's structural overhead on every
action, and it exposes two failure modes:

- **Missed broadcasts** — if the WebSocket is down at the moment of broadcast
  (common on Safari), the player's hand freezes.
- **CSRF fragility** — when form HTML is delivered via broadcast, it has no real
  session context. The current workaround (Turbo reads CSRF from `<meta>` tag,
  204 prevents URL drift) is correct but requires knowing obscure rules.

## Solution

Convert `<div id="hand_screen">` to `<turbo-frame id="hand_screen">`. When a
player submits any form inside the frame, Turbo targets the frame and the HTTP
response replaces it directly — no waiting for a WebSocket broadcast. Broadcasts
still fire for all *other* players.

Create a `RendersHand` concern that all in-scope controllers include. Controllers
replace their `respond_to` block with a single `render_hand` call. The concern
resolves room and player automatically from controller state:

```ruby
# app/controllers/concerns/renders_hand.rb
module RendersHand
  def render_hand
    room = (@game&.room || @room || current_player&.room)&.reload
    player = current_player
    respond_to do |format|
      format.turbo_stream do
        render partial: "rooms/hand_screen_content", locals: { room:, player: }
      end
      format.html { redirect_to room_hand_path(room) }
    end
  end
end
```

Controllers just call `render_hand` — no arguments needed.

## Benefits

- **Lower latency** — submitter sees their result from the HTTP response, not the broadcast.
- **CSRF is automatic** — turbo-frame submissions always use the meta tag token.
- **URL drift is impossible** — turbo-frame submissions never update `window.location.href`.
- **Missed broadcasts don't freeze the submitter** — their frame updates from HTTP regardless.

## Controllers in Scope

**Player actions:**
- `TriviaAnswersController#create`
- `VotesController#create`
- `CategoryList::SubmissionsController#create`

**Host actions (buttons rendered inside `#hand_screen`):**
- `SpeedTrivia::GameStartsController#create`
- `SpeedTrivia::AdvancementsController#create`
- `SpeedTrivia::QuestionsController#create`
- `SpeedTrivia::RoundClosuresController#create`
- `SpeedTrivia::ScoreRevealsController#create` *(dead code — skip)*
- `CategoryList::GameStartsController#create`
- `CategoryList::RoundsController#create`
- `CategoryList::ReviewsController#update`
- `CategoryList::ReviewNavigationsController#create`
- `CategoryList::StageScoresController#create`
- `WriteAndVote::GameStartsController#create`

**Out of scope:** `ScoreTrackerEntriesController` (backstage-only, not rendered in `#hand_screen`).

## The `_hand_instructions` Exception

`_hand_instructions.html.erb` currently has `data: { turbo: false }` on the
Start Game button, relying on a `format.html` redirect to reload the hand.

**Fix:** Remove `data: { turbo: false }`. The `GameStarts` controllers return
rendered hand HTML like everything else. No special case needed.

## Broadcast Strategy

`GameBroadcaster.broadcast_hand` continues to fire unchanged — it's still needed
to update all other players' frames. It's just no longer load-bearing for the
submitter, who already has fresh state from the HTTP response.

Future optimization: pass `except_player:` to skip broadcasting to the
submitter. Not required for correctness.

## CLAUDE.md Cleanup

The two hard rules ("no `turbo: false` in broadcasted partials", "use 204 not
200") were workarounds for the `<div>` architecture. Once the frame is in place,
update CLAUDE.md to document the new architecture instead.

## Testing Strategy

- Existing system specs that visit `room_hand_path` before submitting continue
  to work unchanged.
- Add regression specs per game type: submit a player action and assert the
  frame updates from the HTTP response.
- `_hand_instructions` regression: host clicks Start Game from the hand, assert
  game transitions and hand updates without full-page reload.

## Risks

**`format.turbo_stream` renders partial with stale `current_player`.**
Mitigation: `room.reload` before rendering (already done in broadcasts).
`current_player` is scoped to the room via `params[:code]` in `set_current_player`.

**Race condition — HTTP response updates frame, then broadcast also updates it.**
Mitigation: Two identical updates to the same content is idempotent. Safe.

**`reconnect_controller.js` uses `Turbo.visit` (full-page visit).**
Mitigation: `Turbo.visit` replaces the entire page including the frame. Unchanged.

**Nested turbo-frames (invalid HTML).**
Mitigation: Audit confirmed no game partials contain `<turbo-frame>` tags.

## Implementation Steps

1. Convert `<div id="hand_screen">` → `<turbo-frame id="hand_screen">` in `hands/show.html.erb`
2. Create `app/controllers/concerns/renders_hand.rb`
3. Update all 13 in-scope controllers to include `RendersHand` and call `render_hand`
4. Remove `data: { turbo: false }` from `_hand_instructions.html.erb`
5. Update CLAUDE.md to document the new architecture (remove workaround rules)
6. Add system spec regression tests
