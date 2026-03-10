# HasScoring Concern Design

## Problem

Every game type implements scoring independently. The same pattern — accumulate `points_awarded` on per-player records, sum into `player.score` — is reimplemented with different method names and slightly different shapes:

| Game | Sum method | Source of truth | Column |
|------|-----------|-----------------|--------|
| SpeedTrivia | `calculate_scores!` | `trivia_answers.sum(:points_awarded)` | `points_awarded` |
| WriteAndVote | `calculate_scores!` | `votes.count * 500` | (derived, no column) |
| CategoryList | `calculate_total_scores` | `category_answers.sum(:points_awarded)` | `points_awarded` |

As we add more game types (5+ expected near-term), this drift will compound. New games will copy-paste from whichever existing game the author looks at first, and the inconsistency makes it harder to build shared scoring UI, shared tests, and shared debugging tools.

## Solution

Extract a `HasScoring` concern with a minimal interface. Games include the concern and define one method. The concern provides default implementations of everything else.

## Interface

### Required — game must implement

```ruby
def scoring_records_for(player)
```

Returns an ActiveRecord relation of records that carry points for this player. Must respond to `.sum(:points_awarded)`. The actual model can be anything — `TriviaAnswer`, `CategoryAnswer`, `JudgeScore`, `RoundResult` — the concern doesn't care.

Examples:

```ruby
# SpeedTriviaGame
def scoring_records_for(player)
  trivia_answers.where(player:)
end

# CategoryListGame
def scoring_records_for(player)
  category_answers.where(player:)
end

# WriteAndVoteGame — needs migration to add points_awarded to responses
def scoring_records_for(player)
  responses.joins(:prompt_instance)
           .where(player:, prompt_instances: { write_and_vote_game_id: id })
end
```

### Provided by concern — default implementations

```ruby
def calculate_scores!
  room.players.active_players.each do |player|
    player.update!(score: total_points_for(player))
  end
end

def total_points_for(player)
  scoring_records_for(player).sum(:points_awarded)
end
```

Games can override either method if they score differently (e.g., a game where score decreases, or a team-based game that shares points across team members).

### That's the whole interface

Three messages total. One required, two provided with defaults.

Everything else — round-level presentation (`score_reveal_for`, `players_with_round_scores`), scoring configuration (point values, decay formulas), round scoring (`score_current_round`, `calculate_round_scores`) — stays game-specific. These are not part of the concern.

## What `scoring_records_for` must return

The relation must:
- Be scoped to a single player
- Have a `points_awarded` integer column (this is the convention — all scoring record models use this column name)
- Be summable via `.sum(:points_awarded)`

The relation does NOT need to:
- Be a specific model type
- Represent "answers" — it could be judge awards, team bonuses, penalty records, etc.
- Cover a single round — it should return ALL scoring records for the entire game

## `player.score` is a denormalized cache

`player.score` exists so views can do `order(score: :desc)` without joining through game-specific answer tables. It is NOT the source of truth. The source of truth is always `total_points_for(player)`.

Rules:
- `calculate_scores!` is the only writer. Always call inside a lock.
- Views that need a player's score for display should use `total_points_for(player)` (not `player.score`) when accuracy matters (e.g., score animations with arithmetic).
- Views that only need ordering (`order(score: :desc)` for leaderboards) can use `player.score` since it's always written before broadcasts.

## `points_awarded` is the standard column

All scoring record models use `points_awarded` (integer, default 0). This is already true for `TriviaAnswer` and `CategoryAnswer`. `WriteAndVote` currently derives score from vote counts — it should add `points_awarded` to responses to align.

## Team games

For team-based games (Codenames, Family Feud), `scoring_records_for(player)` can scope through the player's team:

```ruby
def scoring_records_for(player)
  round_results.where(team: player.team)
end
```

The concern doesn't need to know about teams. It just sums whatever the game returns.

## What this does NOT cover

- **Round-level scoring** (`score_current_round`, `calculate_round_scores`) — game-specific, depends on each game's concept of rounds and how points are assigned
- **Score presentation** (`score_reveal_for`, `players_with_round_scores`) — game-specific, depends on what the score reveal UI looks like
- **Point values and formulas** (decay, alliteration bonuses, vote multipliers) — game-specific configuration
- **When to call `calculate_scores!`** — game-specific, called from the service module at the right moment in the game flow

## Implementation steps

1. Create `app/models/concerns/has_scoring.rb` with the concern
2. Add `scoring_records_for` to `SpeedTriviaGame`, include `HasScoring`, remove the inline `calculate_scores!` and `total_points_for`
3. Add `scoring_records_for` to `CategoryListGame`, include `HasScoring`, rename `calculate_total_scores` callers to `calculate_scores!`
4. Add `points_awarded` column to responses, add `scoring_records_for` to `WriteAndVoteGame`, include `HasScoring`, update vote-counting logic to write `points_awarded`
5. Update `Games::CategoryList` service to call `calculate_scores!` instead of `calculate_total_scores`

Steps 2-3 are safe refactors (rename + extract). Step 4 is a small migration + behavior change for WriteAndVote.
