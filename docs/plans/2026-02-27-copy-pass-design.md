# Copy Pass: Think Fast + A-List Design

**Date:** 2026-02-27
**Status:** Approved for implementation
**Scope:** Voice guide copy pass on Think Fast (Speed Trivia) and A-List (Category List) hand views. All changes are copy-only — no new components, no structural changes.

---

## Background

Following the Phase 1 in-game clarity fixes, several remaining copy strings across Think Fast and A-List were written before the voice guide existed. They're functional but flat. This pass brings them in line with the established voice: warm, cheeky, supportive hype-man energy.

Additionally, the A-List REJECTED badge gives players no context for what "REJECTED" means or who did it.

---

## Changes

### Think Fast — `app/views/games/speed_trivia/_answer_form.html.erb`

**Submitted answer state** (lines 19-22):

| Before | After |
|---|---|
| "Answer submitted!" | "Locked in!" |
| "You answered: [X]" | "You went with: [X]" |
| "Waiting for results..." | "Hang tight while everyone finishes up..." |

---

### Think Fast — `app/views/games/speed_trivia/_waiting.html.erb`

**Answer result** (lines 52-63):

| State | Before | After |
|---|---|---|
| Correct | "Correct!" | "That's the one!" |
| Wrong | "Wrong!" | "Not quite." |
| Time's Up | "Time's Up!" | "And... time." |

"The answer was: [X]" line is unchanged — it's clear and useful.

**Motivational messages** (lines 43-49):

| Bucket | Before | After |
|---|---|---|
| 0 pts | "Oof!" / "Next time!" | "Oof." / "Next one's yours." |
| scored + held/improved rank | "Nice one!" / "Way to go!" | "Nice one!" / "That's how you do it." |
| scored + dropped rank | "Keep it up!" / "You can do it!" | "Still in it!" / "Don't count yourself out." |

Note: "Faster answers = more points!" in the waiting state is left alone — it's functional and informative.

---

### A-List — `app/views/games/category_list/_waiting.html.erb`

**REJECTED badge context** (lines 28-30):

After the rejected answer line, add a one-line explanation below the answer block:
```
"The host removed this one — it won't count."
```
Styled small and muted (`text-xs text-red-400/60`), inside the rejected answer's card div.

**Reviewing footer** (line 39):

| Before | After |
|---|---|
| "The host is checking answers..." | "Host is reviewing. Sit tight — shouldn't be long." |

**Scoring state** (line 44):

| Before | After |
|---|---|
| "Check the screen for scores!" | "Scores are in! Your total is below." |

The player already sees their score number directly below this line. Pointing them to "the screen" assumes they can see it. Better to surface what's right in front of them.

---

## Files Changed

| File | Changes |
|---|---|
| `app/views/games/speed_trivia/_answer_form.html.erb` | Submitted state: 3 copy strings |
| `app/views/games/speed_trivia/_waiting.html.erb` | Correct/Wrong/Time's Up: 3 strings · Motivational messages: 6 strings |
| `app/views/games/category_list/_waiting.html.erb` | REJECTED explanation: 1 new line · Reviewing footer: 1 string · Scoring state: 1 string |

---

## Success Criteria

- All copy strings updated as specified
- Existing system specs pass (update any assertions that check the old copy)
- No structural HTML changes — copy only
