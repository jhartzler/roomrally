# In-Game Clarity: UX Improvement Design

**Date:** 2026-02-26
**Status:** Approved for implementation
**Scope:** Comedy Clash (Write & Vote) + A-List (Category List) confusion fixes, plus a copy voice guide for all future in-game text.

---

## Background

User testing with teens and college-age players revealed four recurring confusion points across the games:

1. In Comedy Clash voting, players who wrote a *response* to the current prompt are excluded from voting on it — they watch while everyone else decides. The current state is a vague "Voting in Progress" that doesn't tell them what's actually happening (their answer is being judged!).
2. The stage shows response letters (A, B, C, D) during voting, but the hand doesn't — players can't coordinate.
3. Comedy Clash has 2 rounds but nothing communicates this before or during round 1. Players think the game ends after round 1.
4. A-List scoring rules (alliterative = 2pts, duplicate = 0pts) are mentioned in the stage instructions but not surfaced again when it matters — during the filling phase on the player's hand.

Additionally: existing in-game copy is dry and functional. For teens in a group-play context, the tone should be warm, cheeky, and occasionally surprising — not flat instructions.

---

## Copy Voice Guide

See [`docs/copy-voice.md`](../copy-voice.md) for the full guide.

**Short version:** Supportive hype-man energy. Affectionate cheekiness, unexpected enthusiasm, self-aware about game mechanics. Short and punchy. Never smug, never dry, never forced slang.

---

## Phase 1: Minimal Targeted Fixes

These fixes are copy changes and small UI additions — no new components, no structural changes.

### Fix 1: Comedy Clash — Author Waiting State

**Problem:** Players who wrote a response to the current prompt are excluded from voting on it — they watch while everyone else decides. The current copy ("Voting in Progress / May the best answer win!") is vague and doesn't tell them what's actually happening. Their answer is out there being judged — that's exciting! The copy should lean into that instead of reading like a generic loading state.

**Mechanic (from code):** `_voting.html.erb` line 38 — `if responses.exists?(player: player)` — if the current player authored a response to this prompt, the voting UI is replaced with a waiting state. They don't vote at all for this prompt; they just watch.

**Solution:** Replace the vague waiting copy with something that frames this as an exciting moment ("your answer is being voted on!") rather than a vague hold screen.

**Location:** `app/views/games/write_and_vote/_voting.html.erb` — the branch at line 38–44.

**Before:**
```
🗳️ "Voting in Progress"
   "May the best answer win!"
   "Waiting for other players..."
```

**After:**
```
🗳️ "Your answer is up for a vote!"
   "Sit tight — the room is deciding if you're a comedy genius or just... brave."
   "Waiting for everyone to vote..."
```

---

### Fix 2: Comedy Clash — Letter Labels on Hand Vote Buttons

**Problem:** Stage shows large A/B/C/D letter badges on response cards. Hand vote buttons have no letters. Players can't coordinate or cross-reference.

**Solution:** Add the same letter badge (small circle with letter) to each response card on the hand, before the response text. Order must match the stage rendering order.

**Location:** `app/views/games/write_and_vote/_voting.html.erb` — response cards loop, add `each_with_index` if not already present.

**Visual target:**
```
[A]  "Whatever you want it to be I guess"   [Vote for this answer]
[B]  "A series of extremely bad decisions"  [Vote for this answer]
```

The letter badge style should match the stage: a small filled circle with the letter, using the same `bg-white/20 text-white font-bold` pattern already used on stage.

**Implementation note:** Verify that `responses_for_current_prompt` returns in the same order on both stage and hand views. They should (both are server-rendered from the same query) but confirm before shipping.

---

### Fix 3: Comedy Clash — Round Count

**Problem:** Players don't know Comedy Clash has 2 rounds. When round 1 ends and scoring happens, they think it's over — then the game continues and they're confused.

**Solution:** Show "Round X of Y" anywhere the current round is displayed.

**Locations:**
- `app/views/games/write_and_vote/_voting.html.erb` — progress header: `"Round 1 • Prompt 1 of 4"` → `"Round 1 of 2 • Prompt 1 of 4"`
- `app/views/games/write_and_vote/hand_writing.html.erb` (or prompt screen partial) — add round indicator if not present
- Stage writing view `stage_writing.html.erb` — `"Writing Phase: Round 1"` → `"Writing Phase: Round 1 of 2"`

**What to pass:** `game.game_round` (current) and the max round count. The max is 2 for Write and Vote — check if this is a constant on the model or hardcoded. If it's a constant (`WriteAndVoteGame::MAX_ROUNDS` or similar), use it. If hardcoded to 2, pass `2` as a local or look it up from the service.

---

### Fix 4: A-List — Scoring Hint During Filling

**Problem:** Scoring rules are shown briefly in stage instructions but not visible on the player's hand during the filling phase, when they actually make decisions.

**Solution:** Add a small, muted one-line scoring hint on the hand filling screen, between the letter display and the category form.

**Location:** `app/views/games/category_list/hand_filling.html.erb` (or `_answer_form.html.erb` if it's in a partial)

**Copy:**
```
💡  Starts with [A] = 2pts · unique answer = 1pt · same as someone else = 0pts
```

Where `[A]` is the actual current round letter, pulled from `@game.current_letter` (or equivalent).

**Styling:** Small, muted — `text-sm text-white/60` or similar. Not a banner, not a warning — just a reminder. Should be unobtrusive but findable for the player who's wondering "wait, how does scoring work again?"

---

## Phase 2: Visual Improvements (Future)

To be planned separately after Phase 1 is shipped and tested.

- **Richer author-waiting state:** Instead of just copy, show an animated "watching the votes come in" visual — e.g., bouncing vote bubbles, or a small counter of votes cast so far (without revealing which response is winning).
- **Styled letter badges with colors:** A = blue, B = orange, C = green, D = purple — consistent between stage and hand, so "vote for the blue one" works verbally.
- **Round progress dots:** On stage during writing/voting, show `● ○` (filled/empty) for rounds completed vs remaining. Small, in the header area.
- **A-List instructions with examples:** On the hand instructions screen, show a real example: `"Apple" (starts with A) = 2pts · "Pineapple" = 1pt · same as someone else = 0pts`

---

## Phase 3: Component Extraction (Future)

To be planned separately after Phase 2.

- **`games/shared/_submitted_card.html.erb`:** The "answer submitted, waiting for others" green card appears in all 3 games. Extract to shared partial with `emoji:`, `title:`, `subtitle:` locals.
- **`games/shared/_mini_leaderboard.html.erb`:** Post-game hand view leaderboard (top 5). Used by all games, currently implemented separately in each.
- **`games/shared/_stage_leaderboard.html.erb`:** Final game-over leaderboard on stage. Visually identical across all games.
- **`games/shared/_waiting_state.html.erb`:** Generic waiting state with emoji, title, subtitle, and optional pulsing subtext. Replaces per-game waiting implementations.
- **`games/shared/_round_header.html.erb`:** `"Round X of Y • Phase"` header used across Category List and Comedy Clash.

---

## Files Changed in Phase 1

| File | Change |
|---|---|
| `app/views/games/write_and_vote/_voting.html.erb` | Fix 1: author waiting copy · Fix 2: letter badges on response cards |
| `app/views/games/write_and_vote/stage_writing.html.erb` | Fix 3: add "of N" to round indicator |
| `app/views/games/write_and_vote/hand_writing.html.erb` (or prompt screen partial) | Fix 3: add round indicator |
| `app/views/games/category_list/hand_filling.html.erb` (or answer_form partial) | Fix 4: scoring hint line |
| `docs/copy-voice.md` | New: copy voice guide (symlink or copy from this doc's voice section) |

---

## Success Criteria

Phase 1 is complete when:
- Playing Comedy Clash, a player who wrote a prompt sees a clear explanation of why they can't vote
- Letter badges (A/B/C/D) appear on hand vote cards and match the stage display
- Round count is visible during writing and voting phases
- A-List filling screen shows a scoring hint with the current letter
- Copy voice guide is committed and linked from CLAUDE.md
