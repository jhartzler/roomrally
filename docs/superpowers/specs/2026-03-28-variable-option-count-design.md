# Variable Option Count for Think Fast (Speed Trivia)

**Date:** 2026-03-28
**Status:** Draft
**Motivation:** A host wants to create 2-option "poll-style" questions (e.g., "Who will change more diapers: John or Janice?") within a Think Fast trivia pack for a baby shower. Current implementation hardcodes exactly 4 options per question.

## Scope

Allow 1-4 answer options per trivia question. Improve the stage results display with percentages and a bigger card layout for 1-2 option questions. Update the trivia editor to support adding/removing option fields.

**Out of scope:** Dedicated Poll game type, unscored question mode, majority-wins scoring. The "poll feel" is achieved by marking all options correct — every player scores based on speed.

## Changes

### 1. TriviaQuestion Model

Replace `OPTIONS_COUNT = 4` with range validation:

```ruby
MIN_OPTIONS = 1
MAX_OPTIONS = 4

def options_must_be_valid_count
  unless options.is_a?(Array) && options.length.between?(MIN_OPTIONS, MAX_OPTIONS)
    errors.add(:options, "must contain between #{MIN_OPTIONS} and #{MAX_OPTIONS} choices")
    return
  end

  if options.any?(&:blank?)
    errors.add(:options, "must not contain blank choices")
  end
end
```

No migration needed — `options` is already a Postgres array column.

### 2. Vote Summary Partial (Stage Results)

`app/views/games/speed_trivia/_vote_summary.html.erb`

**Layout by option count:**
- **1-2 options:** Face-Off Cards — large side-by-side (or single centered) cards with percentage prominently displayed, plus raw vote count below
- **3 options:** `grid-cols-3` — current compact card style, one clean row, with percentage added
- **4 options:** `grid-cols-4` — current compact card style with percentage added

**Percentage display:** `votes / total_votes * 100`, shown as "62%". Display "—" when no votes have been cast.

**Face-Off Card style (1-2 options):**
- Colored background tint and border (distinct color per option)
- Letter badge (A/B) centered at top
- Option text
- Large percentage number
- Raw vote count ("18 votes") below

### 3. Stage Answering Partial

`app/views/games/speed_trivia/_stage_answering.html.erb`

Grid columns adapt to option count:
- 1 option: single centered card
- 2 options: `grid-cols-2` (already works)
- 3 options: `grid-cols-3` (one row, no orphan)
- 4 options: `grid-cols-1 md:grid-cols-2` (current behavior, two rows)

### 4. Hand Answer Form

`app/views/games/speed_trivia/_answer_form.html.erb`

Already iterates `options.each_with_index` and handles variable sizes with `options.size` guards. Verify 1-option renders as a single centered button. No structural changes expected.

### 5. Trivia Editor

`app/javascript/controllers/trivia_editor_controller.js` and the question template partial.

**Option field management:**
- New questions start with 4 option fields (unchanged default — no added friction for the common case)
- Each option field gets a small X button to remove it (disabled/hidden when at minimum 1 option)
- "+ Add Option" link appears when below 4 options, hidden at 4
- When an option is removed: if it was marked as a correct answer, uncheck it and re-sync the `correct_answers` hidden fields

### 6. No Other Changes

- **Scoring:** Unchanged. Speed-based points for correct answers. For "poll-style" questions, the host marks all options correct — every player scores.
- **TriviaQuestionInstance:** No validation on option count currently, just presence. No change needed.
- **Playtest module:** `bot_act` already calls `current_question.options.sample` — works with any count.
- **Migration:** None. Array column is already flexible.

## Testing

- Model specs: TriviaQuestion validates 1, 2, 3, 4 options (valid) and 0, 5+ options (invalid)
- System spec: Play through a Think Fast game with a mixed pack (a 2-option question and a 4-option question), verify both display correctly on stage and hand
- Editor: Verify add/remove option fields, correct answer sync on removal
