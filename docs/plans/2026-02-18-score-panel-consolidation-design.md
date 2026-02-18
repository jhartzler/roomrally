# Score Panel Consolidation — Design

**Date:** 2026-02-18

## Problem

The current hand view shows the answer reveal (emoji + Correct/Wrong) at step 1, then transitions to a separate score panel at step 2. Step 2 is too brief to read comfortably, and the screen switch is jarring.

## Solution

Collapse both reviewing steps into a single combined view that shows the answer result **and** the score panel together. Players see everything on one screen for the full 5-second step 1 window. Step 2 re-renders the same view with identical-looking data (the animation won't noticeably replay since scores match).

## Combined Screen Layout

```
🎉  Correct!   +248
────────────────────
1ST PLACE
[animated: 750 → 998]
+248 this round
```

Or for wrong:
```
😅  Wrong!
The answer was: Paris
────────────────────
4TH PLACE
[stays at: 750]
+0 this round
```

## Score Formula

`points_awarded` is set during `close_round!` and is available at step 1. Use a step-aware formula that produces the same `from`/`to` values regardless of which step re-renders:

```ruby
round_points = player_answer&.points_awarded.to_i
if game.reviewing_step == 1
  score_from = player.score                   # old cumulative total
  score_to   = player.score + round_points    # projected new total
else # reviewing_step == 2: player.score already updated by calculate_scores!
  score_from = player.score - round_points    # back-computes old total
  score_to   = player.score                   # actual new total
end
```

Both produce the same `from`/`to`, so the animation is identical whether triggered at step 1 or step 2.

## Rank Computation

Use a projected-rank approach that also works at both steps:

```ruby
# Project all players' new scores using points_awarded already on the DB
round_points_by_id = current_question.trivia_answers
  .each_with_object({}) { |a, h| h[a.player_id] = a.points_awarded.to_i }

if game.reviewing_step == 1
  sorted_now  = all_players.sort_by { |p| -(p.score + round_points_by_id.fetch(p.id, 0)) }
  sorted_prev = all_players.sort_by { |p| -p.score }
else
  sorted_now  = all_players.sort_by { |p| -p.score }
  sorted_prev = all_players.sort_by { |p| -(p.score - round_points_by_id.fetch(p.id, 0)) }
end
```

## Motivational Message

Keep rank-change logic (improved/held vs. fell) since it works at both steps with the unified rank formula.

## Files Changed

- `app/views/games/speed_trivia/_waiting.html.erb` — collapse the two reviewing sub-branches into one combined view
- `spec/system/games/speed_trivia_happy_path_spec.rb` — move score panel assertions to after `close_round` (step 1) instead of after `show_scores` (step 2)

## Non-Goals

- No changes to the step 1/step 2 broadcast timing or game service
- No changes to the Stimulus controller (score-tally already handles `from == to` gracefully)
