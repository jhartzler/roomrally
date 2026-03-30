# Skip Question in Speed Trivia

## Problem

Hosts sometimes need to skip upcoming questions to shorten a game in progress — e.g., "I have a great closer but time is running short." There's currently no way to do this without playing through every question.

## Behavior

- The host can skip the **next** question, not the current one. If players already answered, the right move is to close the round normally. Skip prevents a question from ever being shown.
- Skip is available during the `reviewing` state only, alongside the existing "Next Question" button.
- Skip is a secondary action — smaller, muted styling so the host doesn't accidentally hit it instead of "Next Question."
- Only visible when `questions_remaining?` — no skip button if the current question is the last one.
- The button shows a preview of the question that will be skipped so the host knows what they're bypassing.
- Skipping is single-step: one tap skips one question. Host can mash the button to skip multiple.
- After skipping, the host controls re-render with the new next-up preview. Players see nothing — they stay on the score reveal screen.

### Player experience

- Players are unaware a question was skipped. No announcement, no visual change.
- Question numbering stays objective: if host skips from Q5 to Q8, the stage shows "Question 8 of 18." Players may notice the jump but there's no "SKIPPED" callout.
- Skipped questions are never scored — they were never shown.

## Implementation

### Service method

New `Games::SpeedTrivia.skip_next_question(game:)`:

1. Guard: game must be `reviewing?` and `questions_remaining?`
2. `game.with_lock { game.increment!(:current_question_index) }`
3. Log observability events (see Observability section)
4. Broadcast host controls and hand — `GameBroadcaster.broadcast_host_controls(room: game.room)` and `GameBroadcaster.broadcast_hand(room: game.room)`. Hand broadcast is needed because the host-player sees host controls rendered inside their hand view. No stage broadcast (players see no change on the big screen).

After the skip, the existing host controls template naturally handles the new state:
- If `questions_remaining?` is still true: "Next Question" + "Skip Next Question" with updated preview
- If the skip landed on the last question: "Next Question" only (skip button hidden), or "Finish Game" if there are no questions left at all

Edge case: if skip causes `!questions_remaining?` and the host then clicks "Next Question," the existing `next_question` method already handles finishing the game. No special logic needed.

### Controller

New `SpeedTrivia::QuestionSkipsController`:
- Includes `GameHostAuthorization` and `RendersHand`
- Single `create` action that calls `Games::SpeedTrivia.skip_next_question(game: @game)` then `render_hand`
- Follows the same pattern as `AdvancementsController`, `RoundClosuresController`, etc.

### Route

```ruby
resources :speed_trivia_games, only: [] do
  resource :question_skip, only: [:create], module: :speed_trivia
end
```

### Host controls view

In `_host_controls.html.erb`, during the `reviewing` state, below the existing "Next Question" / "Finish Game" button:

```erb
<% if game.questions_remaining? %>
  <div class="mt-2">
    <%= button_to "Skip Next Question",
        speed_trivia_game_question_skip_path(game),
        params: { code: room.code },
        class: "text-sm text-gray-400 underline hover:text-gray-200" %>
    <p class="text-xs text-gray-500 mt-1">
      Up next: <%= game.trivia_question_instances[game.current_question_index + 1]&.question&.body&.truncate(60) %>
    </p>
  </div>
<% end %>
```

Exact styling TBD during implementation — the key constraint is lower visual hierarchy than the primary action button.

### Observability

Three channels, matching existing patterns:

1. **Rails.logger.info** — structured log with room code, skipped question index, and question body
2. **Analytics.track** (PostHog) — `"question_skipped"` event with `game_type`, `room_code`, `question_index`, `questions_remaining` properties. Enables product queries like: how often do hosts skip? Do games with skips have different completion rates?
3. **GameEvent.log** — `"question_skipped"` event with `question_index` and `question_body` metadata. Appears in admin session timeline.

Additionally, update `SessionRecap#format_game_event` to handle the new event:
```ruby
when "question_skipped"
  "Question #{ge.metadata["question_index"] + 1} skipped"
```

### What doesn't change

- **Stage view**: players stay on reviewing screen during skip, no broadcast needed
- **Hand view for players**: score reveal stays put, no change
- **Question numbering**: objective index preserved — "Question 17 of 18"
- **Scoring**: skipped questions were never answered, no scoring impact
- **Timer**: no timer running during reviewing state, nothing to cancel
- **AASM states**: no new states or transitions. Skip is purely an index increment.
- **Model schema**: no migration needed. `current_question_index` already exists.

## Testing

- **System spec**: host starts Speed Trivia, plays through a question, skips the next one, verifies the following question appears with correct numbering. Verify skipped question's content never appears on stage.
- **Service spec**: `skip_next_question` increments index, creates GameEvent, raises/no-ops when not in reviewing state.
- **Edge case**: skip to last question, then "Next Question" finishes the game normally.
- **Edge case**: skip all remaining questions (mash skip), verify "Finish Game" appears.
