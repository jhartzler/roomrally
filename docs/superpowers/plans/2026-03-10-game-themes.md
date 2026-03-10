# Per-Game Visual Themes Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each game (Comedy Clash, Think Fast, A-List) its own visual identity via a composable CSS theme system using native Tailwind utilities.

**Architecture:** CSS custom properties scoped via `data-game-theme` attribute, exposed as Tailwind color tokens in `@theme`. Templates use `bg-theme-accent`, `text-theme-text-muted`, etc. — full Tailwind fluency with opacity modifiers, hover states, etc. Themes cascade: any DOM subtree can declare a theme.

**Tech Stack:** Tailwind CSS v4, CSS custom properties, Rails view helpers, ERB partials.

**Spec:** `docs/superpowers/specs/2026-03-10-game-themes-design.md`

---

## Chunk 1: Theme Infrastructure

### Task 1: Define theme tokens and CSS custom properties

**Files:**
- Modify: `app/assets/tailwind/application.css`

- [ ] **Step 1: Add theme color tokens to @theme block**

Add after the existing `--text-vh-5xl` line (line 28) in the `@theme` block:

```css
  /* Game theme color tokens — set by [data-game-theme] selectors below */
  --color-theme-bg-from: oklch(0.45 0.15 260);      /* default: blue-600 */
  --color-theme-bg-to: oklch(0.28 0.12 280);         /* default: indigo-900 */
  --color-theme-accent: oklch(0.80 0.18 85);          /* default: yellow-400 */
  --color-theme-accent-subtle: oklch(0.80 0.18 85 / 0.3);
  --color-theme-secondary: oklch(0.80 0.10 250);      /* default: blue-200 */
  --color-theme-surface: oklch(1 0 0 / 0.1);          /* default: white/10 */
  --color-theme-surface-border: oklch(1 0 0 / 0.2);   /* default: white/20 */
  --color-theme-text: oklch(1 0 0);                    /* default: white */
  --color-theme-text-muted: oklch(1 0 0 / 0.6);       /* default: white/60 */
  --color-theme-timer-start: oklch(0.80 0.18 85);     /* default: yellow */
  --color-theme-timer-end: oklch(0.55 0.22 25);       /* default: red */
```

Note: The defaults match the current blue/indigo scheme so unthemed views don't break.

- [ ] **Step 2: Add game theme rulesets after @theme block**

Add after the `@theme { }` block closing brace, before the `.ai-loader` section:

```css
/* === Game Themes === */

[data-game-theme="comedy-club"] {
  --color-theme-bg-from: oklch(0.25 0.10 300);        /* deep purple */
  --color-theme-bg-to: oklch(0.15 0.08 290);          /* near-black purple */
  --color-theme-accent: oklch(0.65 0.28 350);         /* hot pink #ff3e8a */
  --color-theme-accent-subtle: oklch(0.65 0.28 350 / 0.3);
  --color-theme-secondary: oklch(0.82 0.15 85);       /* warm gold #ffc832 */
  --color-theme-surface: oklch(1 0 0 / 0.1);
  --color-theme-surface-border: oklch(0.65 0.28 350 / 0.25);
  --color-theme-text: oklch(1 0 0);
  --color-theme-text-muted: oklch(1 0 0 / 0.6);
  --color-theme-timer-start: oklch(0.65 0.28 350);
  --color-theme-timer-end: oklch(0.55 0.22 25);
}

[data-game-theme="track-meet"] {
  --color-theme-bg-from: oklch(0.22 0.08 55);         /* burnt umber */
  --color-theme-bg-to: oklch(0.12 0.05 40);           /* dark brown-black */
  --color-theme-accent: oklch(0.62 0.20 45);          /* burnt orange #e8590c */
  --color-theme-accent-subtle: oklch(0.62 0.20 45 / 0.3);
  --color-theme-secondary: oklch(0.92 0.02 90);       /* cream white */
  --color-theme-surface: oklch(1 0 0 / 0.06);
  --color-theme-surface-border: oklch(0.62 0.20 45 / 0.2);
  --color-theme-text: oklch(1 0 0);
  --color-theme-text-muted: oklch(1 0 0 / 0.6);
  --color-theme-timer-start: oklch(0.62 0.20 45);
  --color-theme-timer-end: oklch(0.50 0.22 25);
}

[data-game-theme="awards-gala"] {
  --color-theme-bg-from: oklch(0.18 0.08 280);        /* deep indigo */
  --color-theme-bg-to: oklch(0.15 0.10 310);          /* dark purple */
  --color-theme-accent: oklch(0.82 0.17 85);          /* rich gold #ffd700 */
  --color-theme-accent-subtle: oklch(0.82 0.17 85 / 0.3);
  --color-theme-secondary: oklch(0.42 0.15 350);      /* burgundy #8b2252 */
  --color-theme-surface: oklch(1 0 0 / 0.06);
  --color-theme-surface-border: oklch(0.82 0.17 85 / 0.2);
  --color-theme-text: oklch(1 0 0);
  --color-theme-text-muted: oklch(0.82 0.17 85 / 0.6);
  --color-theme-timer-start: oklch(0.82 0.17 85);
  --color-theme-timer-end: oklch(0.55 0.22 25);
}
```

- [ ] **Step 3: Verify Tailwind builds successfully**

Run: `RAILS_ENV=test bin/rails tailwindcss:build`
Expected: Build completes with no errors.

- [ ] **Step 4: Commit**

```bash
git add app/assets/tailwind/application.css
git commit -m "feat: add game theme token system with 3 theme definitions

Defines theme-* color tokens in Tailwind @theme and CSS custom property
rulesets for comedy-club, track-meet, and awards-gala themes."
```

---

### Task 2: Add theme helper method

**Files:**
- Modify: `app/helpers/games_helper.rb`
- Create: `spec/helpers/games_helper_spec.rb`

- [ ] **Step 1: Write the test**

```ruby
# spec/helpers/games_helper_spec.rb
require "rails_helper"

RSpec.describe GamesHelper do
  describe "#game_theme_name" do
    it "returns comedy-club for WriteAndVoteGame" do
      game = build(:write_and_vote_game)
      expect(helper.game_theme_name(game)).to eq("comedy-club")
    end

    it "returns track-meet for SpeedTriviaGame" do
      game = build(:speed_trivia_game)
      expect(helper.game_theme_name(game)).to eq("track-meet")
    end

    it "returns awards-gala for CategoryListGame" do
      game = build(:category_list_game)
      expect(helper.game_theme_name(game)).to eq("awards-gala")
    end

    it "returns nil when game is nil" do
      expect(helper.game_theme_name(nil)).to be_nil
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rspec spec/helpers/games_helper_spec.rb`
Expected: FAIL — `undefined method 'game_theme_name'`

- [ ] **Step 3: Implement the helper**

```ruby
# app/helpers/games_helper.rb
module GamesHelper
  GAME_THEMES = {
    "WriteAndVoteGame" => "comedy-club",
    "SpeedTriviaGame" => "track-meet",
    "CategoryListGame" => "awards-gala"
  }.freeze

  def game_theme_name(game)
    return nil unless game

    GAME_THEMES[game.class.name]
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rspec spec/helpers/games_helper_spec.rb`
Expected: 4 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/helpers/games_helper.rb spec/helpers/games_helper_spec.rb
git commit -m "feat: add game_theme_name helper for theme resolution"
```

---

### Task 3: Apply data-game-theme attribute to stage container

**Files:**
- Modify: `app/views/stages/show.html.erb`

- [ ] **Step 1: Add data-game-theme and swap gradient to theme tokens**

Change line 4 from:
```erb
<div class="fixed inset-0 overflow-hidden text-white p-[2vh] flex flex-col bg-gradient-to-b from-blue-600 to-indigo-900 z-40" data-controller="reconnect">
```
to:
```erb
<div class="fixed inset-0 overflow-hidden text-white p-[2vh] flex flex-col bg-gradient-to-b from-theme-bg-from to-theme-bg-to z-40" data-controller="reconnect" data-game-theme="<%= game_theme_name(@room.current_game) if @room.current_game %>">
```

When no game is active (lobby), `data-game-theme` will be empty — the defaults from `@theme` apply (current blue/indigo).

- [ ] **Step 2: Verify the stage still renders**

Run: `bin/rspec spec/system` (just check for no compilation errors — visual verification comes later)
Expected: Existing tests pass. The default theme colors match the old hardcoded blue/indigo.

- [ ] **Step 3: Commit**

```bash
git add app/views/stages/show.html.erb
git commit -m "feat: apply data-game-theme to stage container with theme gradient"
```

---

### Task 4: Apply data-game-theme attribute to hand container

**Files:**
- Modify: `app/views/hands/show.html.erb`

- [ ] **Step 1: Add data-game-theme to hand container**

The hand view needs to resolve the current game from the room. Change line 5 from:
```erb
<div class="min-h-screen p-4" data-controller="reconnect">
```
to:
```erb
<% current_game = @room.current_game %>
<div class="min-h-screen p-4 bg-gradient-to-b from-theme-bg-from to-theme-bg-to" data-controller="reconnect" data-game-theme="<%= game_theme_name(current_game) if current_game %>">
```

- [ ] **Step 2: Commit**

```bash
git add app/views/hands/show.html.erb
git commit -m "feat: apply data-game-theme to hand container"
```

---

## Chunk 2: Refactor Speed Trivia (Track Meet Theme)

Starting with Speed Trivia / Track Meet because it's the most visually distinct theme — easiest to verify changes are working.

**Color mapping for Track Meet:**

| Old class | New class | Notes |
|-----------|-----------|-------|
| `text-blue-200` | `text-theme-secondary` | Labels, metadata |
| `text-blue-300` | `text-theme-secondary` | Similar usage |
| `text-blue-100/80` | `text-theme-text-muted` | Subtle text |
| `bg-gray-800/80 border-gray-600` | `bg-theme-surface border-theme-surface-border` | Option cards |
| `text-yellow-400` | `text-theme-accent` | Scores, winners |
| `border-yellow-400/50` | `border-theme-accent-subtle` | Winner borders |
| `bg-blue-600 border-blue-300` | `bg-theme-accent border-theme-accent` | Selected answer (hand) |
| `ring-blue-400/50` | `ring-theme-accent-subtle` | Focus ring |
| `bg-blue-900/40` | `bg-theme-surface` | Highlights |
| `border-blue-400/30` | `border-theme-surface-border` | Timer borders |
| `bg-blue-950/40` | `bg-theme-surface` | Timer background |

**Colors that stay hardcoded (semantic, not themed):**
- `text-green-400` / `bg-green-500/10` — correct answers
- `text-red-400` — wrong answers
- `bg-gradient-to-r from-green-600 to-emerald-600` — start button (shared)
- `text-white`, `bg-white`, `text-black` — structural

### Task 5: Refactor Speed Trivia stage partials

**Files:**
- Modify: `app/views/games/speed_trivia/_stage_answering.html.erb`
- Modify: `app/views/games/speed_trivia/_stage_instructions.html.erb`
- Modify: `app/views/games/speed_trivia/_stage_waiting.html.erb`
- Modify: `app/views/games/speed_trivia/_stage_reviewing.html.erb`
- Modify: `app/views/games/speed_trivia/_stage_finished.html.erb`
- Modify: `app/views/games/speed_trivia/_score_podium.html.erb` (if exists)
- Modify: `app/views/games/speed_trivia/_vote_summary.html.erb` (if exists)

- [ ] **Step 1: Capture baseline screenshots (if UI is runnable)**

Run: `rake screenshots:capture && rake screenshots:approve`
This gives us a visual baseline to compare against after changes.

- [ ] **Step 2: Refactor `_stage_answering.html.erb`**

Apply the color mapping table above. Key replacements:
- `text-blue-200` → `text-theme-secondary`
- `bg-gray-800/80` → `bg-theme-surface`
- `border-gray-600` → `border-theme-surface-border`
- `bg-white/10 border-white/20` → `bg-theme-surface border-theme-surface-border`

Do NOT change: layout classes, vh units, font sizes, animation classes, `text-white`, `bg-white`, `text-black`.

- [ ] **Step 3: Refactor `_stage_instructions.html.erb`**

Same pattern: `text-blue-200` → `text-theme-secondary`, `text-blue-300` → `text-theme-secondary`.

- [ ] **Step 4: Refactor `_stage_waiting.html.erb`**

Same pattern.

- [ ] **Step 5: Refactor `_stage_reviewing.html.erb`**

Same pattern. Keep `text-green-400` (correct answer) hardcoded — it's semantic.

- [ ] **Step 6: Refactor `_stage_finished.html.erb` and `_score_podium.html.erb`**

- `text-yellow-400` → `text-theme-accent`
- `border-yellow-400/50` → `border-theme-accent-subtle`
- `from-yellow-300 via-yellow-100 to-yellow-500` — this is the winner celebration gradient. Replace with `from-theme-accent via-theme-accent/40 to-theme-accent` or similar. May need visual tuning.
- `text-gray-400` → `text-theme-text-muted`

- [ ] **Step 7: Refactor `_vote_summary.html.erb` (if exists)**

Same mapping. Keep `text-green-400`, `border-green-500`, `bg-green-500/10` hardcoded.

- [ ] **Step 8: Run system tests**

Run: `bin/rspec spec/system/games/speed_trivia_spec.rb`
Expected: All pass. Tests don't check colors, but they verify nothing is structurally broken.

- [ ] **Step 9: Capture new screenshots and compare**

Run: `rake screenshots:capture && rake screenshots:report`
Review the side-by-side diff. Track Meet theme should show burnt orange/umber instead of blue/indigo.

- [ ] **Step 10: Commit**

```bash
git add app/views/games/speed_trivia/
git commit -m "feat: apply theme tokens to Speed Trivia stage partials (Track Meet)"
```

---

### Task 6: Refactor Speed Trivia hand partials (including host controls)

**Files:**
- Modify: `app/views/games/speed_trivia/_hand.html.erb`
- Modify: `app/views/games/speed_trivia/_answer_form.html.erb`
- Modify: `app/views/games/speed_trivia/_waiting.html.erb`
- Modify: `app/views/games/speed_trivia/_game_over.html.erb`
- Modify: `app/views/games/speed_trivia/_host_controls.html.erb`

- [ ] **Step 1: Refactor `_answer_form.html.erb`**

Key replacements:
- Selected: `bg-blue-600` → `bg-theme-accent`, `border-blue-300` → `border-theme-accent`, `ring-blue-400/50` → `ring-theme-accent-subtle`
- Unselected: `bg-gray-800/40 border-gray-700` → `bg-theme-surface border-theme-surface-border`
- Text: `text-blue-100/80` → `text-theme-text-muted`, `text-blue-200` → `text-theme-secondary`
- Room code box: `bg-white/10 border-white/20` → `bg-theme-surface border-theme-surface-border`

- [ ] **Step 2: Refactor `_waiting.html.erb`**

- `text-blue-200` → `text-theme-secondary`
- `text-yellow-400` → `text-theme-accent`
- `bg-white/5` → `bg-theme-surface`
- `bg-blue-900/40` → `bg-theme-surface`
- Keep `text-green-400`, `text-red-400` hardcoded.

- [ ] **Step 3: Refactor `_game_over.html.erb`**

- `text-yellow-400` → `text-theme-accent`
- `text-blue-200` → `text-theme-secondary`
- `bg-white/5` → `bg-theme-surface`
- `border-white/10` → `border-theme-surface-border`

- [ ] **Step 4: Refactor `_host_controls.html.erb`**

Host controls render inside `#hand_screen` (for hand-view hosts) AND `#backstage-host-controls` (for backstage users). Since they sit inside the themed container for hand-view hosts, theme them:
- `text-blue-200` → `text-theme-secondary`
- `bg-blue-500/20 text-blue-300` → `bg-theme-surface text-theme-secondary`
- `from-indigo-600 to-blue-600` → `from-theme-accent to-theme-accent/80` (action buttons)
- `text-blue-300 hover:text-blue-100` → `text-theme-secondary hover:text-theme-text`

- [ ] **Step 5: Run system tests**

Run: `bin/rspec spec/system/games/speed_trivia_spec.rb`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add app/views/games/speed_trivia/
git commit -m "feat: apply theme tokens to Speed Trivia hand partials (Track Meet)"
```

---

## Chunk 3: Refactor Write And Vote (Comedy Club Theme)

**Color mapping for Comedy Club:**

Same base mapping as Track Meet — the token names are the same, CSS values differ per theme. The key additional patterns in Write And Vote:

| Old class | New class | Notes |
|-----------|-----------|-------|
| `bg-blue-600/20 border-blue-400/30` | `bg-theme-surface border-theme-surface-border` | Response cards |
| `border-green-400/30 text-green-400` | Keep hardcoded | Voted confirmation (semantic) |
| `bg-orange-500 hover:bg-orange-600` | `bg-theme-accent hover:bg-theme-accent/80` | Vote buttons — orange becomes hot pink |
| `text-blue-400` | `text-theme-secondary` | Timer text |
| `bg-blue-950/40 border-blue-400/30` | `bg-theme-surface border-theme-surface-border` | Timer containers |
| `from-yellow-500/20 to-orange-600/20 border-yellow-500/30` | `from-theme-accent/20 to-theme-secondary/20 border-theme-accent-subtle` | Winner banner |
| `text-yellow-100` | `text-theme-accent` | Winner score text |
| `bg-gradient-to-r from-blue-400 to-blue-600` | `bg-theme-accent` | Progress bar fill |

### Task 7: Refactor Write And Vote stage partials

**Files:**
- Modify: `app/views/games/write_and_vote/_stage_instructions.html.erb`
- Modify: `app/views/games/write_and_vote/_stage_writing.html.erb`
- Modify: `app/views/games/write_and_vote/_stage_voting.html.erb`
- Modify: `app/views/games/write_and_vote/_stage_finished.html.erb`

- [ ] **Step 1: Refactor `_stage_instructions.html.erb`**

`text-blue-200` → `text-theme-secondary`, `text-blue-300` → `text-theme-secondary`

- [ ] **Step 2: Refactor `_stage_writing.html.erb`**

- `text-blue-200` → `text-theme-secondary`
- `bg-gradient-to-r from-blue-400 to-blue-600` → `bg-theme-accent` (solid fill for progress bar)

- [ ] **Step 3: Refactor `_stage_voting.html.erb`**

- Response cards: `bg-blue-600/20 border-blue-400/30` → `bg-theme-surface border-theme-surface-border`
- Timer: `border-blue-400/30` → `border-theme-surface-border`, `text-blue-400` → `text-theme-secondary`
- CTA: `text-blue-200` → `text-theme-secondary`
- Keep `border-green-400/30` for voted state — semantic.

- [ ] **Step 4: Refactor `_stage_finished.html.erb`**

- Winner banner: `from-yellow-500/20 to-orange-600/20 border-yellow-500/30` → `from-theme-accent/20 to-theme-secondary/20 border-theme-accent-subtle`
- `text-yellow-100` → `text-theme-accent`
- `text-blue-300` → `text-theme-secondary`

- [ ] **Step 5: Run system tests**

Run: `bin/rspec spec/system/games/write_and_vote_spec.rb`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add app/views/games/write_and_vote/
git commit -m "feat: apply theme tokens to Write And Vote stage partials (Comedy Club)"
```

---

### Task 8: Refactor Write And Vote hand partials (including host controls)

**Files:**
- Modify: `app/views/games/write_and_vote/_voting.html.erb`
- Modify: `app/views/games/write_and_vote/_prompt_screen.html.erb`
- Modify: `app/views/games/write_and_vote/_game_over.html.erb`
- Modify: `app/views/games/write_and_vote/_host_controls.html.erb`

- [ ] **Step 1: Refactor `_voting.html.erb`**

- `text-blue-200` → `text-theme-secondary`
- Timer: `bg-blue-950/40 border-blue-400/30` → `bg-theme-surface border-theme-surface-border`, `text-blue-400` → `text-theme-secondary`
- Cards: `bg-blue-600/20 border-blue-400/30` → `bg-theme-surface border-theme-surface-border`
- Vote button: `bg-orange-500 hover:bg-orange-600` → `bg-theme-accent hover:bg-theme-accent/80`
- Keep green voted states hardcoded.

- [ ] **Step 2: Refactor `_prompt_screen.html.erb`**

- Active step: `bg-white/15 border-blue-400/50` → `bg-theme-surface border-theme-accent-subtle`, `text-blue-300` → `text-theme-secondary`
- Inactive step: `text-blue-200/40` → `text-theme-text-muted`
- Timer: same as voting
- Keep `text-green-400` for done steps.

- [ ] **Step 3: Refactor `_game_over.html.erb`**

- Winner gradient: `from-yellow-500/20 to-orange-600/20 border-yellow-500/30` → `from-theme-accent/20 to-theme-secondary/20 border-theme-accent-subtle`
- `text-yellow-100`, `text-yellow-400` → `text-theme-accent`
- `text-blue-300` → `text-theme-secondary`
- `text-slate-400` → `text-theme-text-muted`
- Back button: `bg-orange-500 hover:bg-orange-600` → `bg-theme-accent hover:bg-theme-accent/80`

- [ ] **Step 4: Refactor `_host_controls.html.erb`**

Same pattern as Speed Trivia host controls:
- `text-blue-200` → `text-theme-secondary`
- `bg-blue-500/20 text-blue-300` → `bg-theme-surface text-theme-secondary`
- `text-blue-300 hover:text-blue-100` → `text-theme-secondary hover:text-theme-text`
- `bg-indigo-600/20 border-indigo-500/30` → `bg-theme-surface border-theme-surface-border`
- `text-blue-100` → `text-theme-text`
- `bg-indigo-400` → `bg-theme-accent`

- [ ] **Step 5: Run system tests**

Run: `bin/rspec spec/system/games/write_and_vote_spec.rb`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add app/views/games/write_and_vote/
git commit -m "feat: apply theme tokens to Write And Vote hand partials (Comedy Club)"
```

---

## Chunk 4: Refactor Category List (Awards Gala Theme)

**Additional color patterns for Category List:**

| Old class | New class | Notes |
|-----------|-----------|-------|
| `from-yellow-300 via-yellow-100 to-yellow-500` | `from-theme-accent via-theme-accent/40 to-theme-accent` | Letter display gradient |
| `text-yellow-400` | `text-theme-accent` | Category title, letter, points |
| `border-yellow-400/50 text-yellow-300` | `border-theme-accent-subtle text-theme-accent` | Alliterative badges |
| `bg-orange-400/20 text-orange-400` | `bg-theme-secondary/20 text-theme-secondary` | Answer tags |
| `border-yellow-400/50 shadow-[0_0_20px_rgba(234,179,8,0.2)]` | `border-theme-accent-subtle shadow-[0_0_20px_var(--color-theme-accent-subtle)]` | Top score glow |
| `focus:border-yellow-400 focus:ring-yellow-400` | `focus:border-theme-accent focus:ring-theme-accent` | Input focus |
| `bg-blue-600/30 border-blue-400/30` | `bg-theme-surface border-theme-surface-border` | Current player highlight |

**Keep hardcoded:**
- `text-red-400`, `bg-red-400/20`, `border-red-500/50` — rejected answers (semantic)
- `text-gray-400`, `border-gray-500/50` — duplicate answers (semantic)
- `text-green-400` — positive scores

### Task 9: Refactor Category List stage partials

**Files:**
- Modify: `app/views/games/category_list/_stage_instructions.html.erb`
- Modify: `app/views/games/category_list/_stage_filling.html.erb`
- Modify: `app/views/games/category_list/_stage_reviewing.html.erb`
- Modify: `app/views/games/category_list/_stage_scoring.html.erb`
- Modify: `app/views/games/category_list/_stage_finished.html.erb`

- [ ] **Step 1: Refactor `_stage_instructions.html.erb`**

`text-blue-200` → `text-theme-secondary`, `text-blue-300` → `text-theme-secondary`

- [ ] **Step 2: Refactor `_stage_filling.html.erb`**

- Letter gradient: `from-yellow-300 via-yellow-100 to-yellow-500` → `from-theme-accent via-theme-accent/40 to-theme-accent`
- Cards: `bg-white/10 border-white/20` → `bg-theme-surface border-theme-surface-border`
- `text-yellow-400` → `text-theme-accent`
- `text-blue-200` → `text-theme-secondary`

- [ ] **Step 3: Refactor `_stage_reviewing.html.erb`**

- `text-yellow-400` → `text-theme-accent`
- `text-blue-300` → `text-theme-secondary`
- `border-white/10` → `border-theme-surface-border`
- `bg-orange-400/20 text-orange-400` → `bg-theme-secondary/20 text-theme-secondary`
- Keep `text-red-400` and strikethrough styling hardcoded.

- [ ] **Step 4: Refactor `_stage_scoring.html.erb`**

- `text-blue-200` → `text-theme-secondary`
- `text-yellow-400` → `text-theme-accent`
- `border-yellow-400/50 text-yellow-300` → `border-theme-accent-subtle text-theme-accent` (alliterative badge)
- Top score glow: `border-yellow-400/50 shadow-[0_0_20px_rgba(234,179,8,0.2)]` → `border-theme-accent-subtle shadow-[0_0_20px_var(--color-theme-accent-subtle)]`
- Keep `text-green-400`, `text-gray-500`, `text-gray-400`, `border-gray-500/50`, `text-red-400`, `border-red-500/50` — all semantic.

- [ ] **Step 5: Refactor `_stage_finished.html.erb`**

Same podium pattern as Speed Trivia. Apply same mapping.

- [ ] **Step 6: Run system tests**

Run: `bin/rspec spec/system/games/category_list_spec.rb`
Expected: All pass.

- [ ] **Step 7: Commit**

```bash
git add app/views/games/category_list/
git commit -m "feat: apply theme tokens to Category List stage partials (Awards Gala)"
```

---

### Task 10: Refactor Category List hand partials (including host controls)

**Files:**
- Modify: `app/views/games/category_list/_hand.html.erb`
- Modify: `app/views/games/category_list/_answer_form.html.erb`
- Modify: `app/views/games/category_list/_waiting.html.erb`
- Modify: `app/views/games/category_list/_game_over.html.erb`
- Modify: `app/views/games/category_list/_host_controls.html.erb`

- [ ] **Step 1: Refactor `_answer_form.html.erb`**

- `text-yellow-400` → `text-theme-accent`
- `bg-white/10 border-white/20` → `bg-theme-surface border-theme-surface-border`
- `focus:border-yellow-400 focus:ring-yellow-400` → `focus:border-theme-accent focus:ring-theme-accent`
- `text-white/50` → `text-theme-text-muted`
- Keep `from-green-600 to-emerald-600` start button — it's a shared action color.

- [ ] **Step 2: Refactor `_waiting.html.erb`**

- `bg-white/10 border-white/20` → `bg-theme-surface border-theme-surface-border`
- `bg-blue-600/30 border-blue-400/30` → `bg-theme-surface border-theme-surface-border`
- `text-blue-200` → `text-theme-secondary`
- Keep red/orange status badges hardcoded.

- [ ] **Step 3: Refactor `_game_over.html.erb`**

Same as Speed Trivia game over — apply same mapping.

- [ ] **Step 4: Refactor `_host_controls.html.erb`**

Category List host controls have the most blue/indigo references (~15). Apply the same pattern:
- `text-blue-200` → `text-theme-secondary`
- `bg-blue-500/20 text-blue-300` → `bg-theme-surface text-theme-secondary`
- `from-indigo-600 to-blue-600` → `from-theme-accent to-theme-accent/80` (action buttons)
- `text-blue-300` → `text-theme-secondary`
- `from-purple-600 to-indigo-600` → `from-theme-accent to-theme-accent/80`

- [ ] **Step 5: Run system tests**

Run: `bin/rspec spec/system/games/category_list_spec.rb`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add app/views/games/category_list/
git commit -m "feat: apply theme tokens to Category List hand partials (Awards Gala)"
```

---

## Chunk 5: Shared Partials & Final Verification

### Task 11: Refactor shared partials

**Files:**
- Modify: `app/views/games/shared/_hand_instructions.html.erb`

- [ ] **Step 1: Refactor `_hand_instructions.html.erb`**

- `bg-white/10 border-white/20` → `bg-theme-surface border-theme-surface-border`
- `text-blue-200` → `text-theme-secondary`
- Keep `from-green-600 to-emerald-600` on the start button — universal action color.
- Keep `border-white/20` on the host controls divider — structural.

- [ ] **Step 2: Check for any other shared partials that use themed colors**

Run a grep for remaining `text-blue-` and `border-blue-` in game view files:
```bash
grep -rn "text-blue-\|border-blue-\|from-blue-\|to-blue-\|bg-blue-" app/views/games/ app/views/stages/ app/views/hands/
```

Fix any remaining instances using the same mapping pattern.

- [ ] **Step 3: Commit**

```bash
git add app/views/games/shared/ app/views/
git commit -m "feat: apply theme tokens to shared game partials"
```

---

### Task 12: Full test suite and visual verification

- [ ] **Step 1: Run full system test suite**

Run: `bin/rspec spec/system`
Expected: All pass.

- [ ] **Step 2: Run rubocop**

Run: `rubocop`
Expected: No new offenses.

- [ ] **Step 3: Capture screenshots and compare to baseline**

Run: `rake screenshots:capture && rake screenshots:report`
Review the side-by-side diff for all three games. Verify:
- Track Meet: Burnt orange/umber gradient, orange accents
- Comedy Club: Purple gradient, hot pink accents, gold secondary
- Awards Gala: Indigo/purple gradient, gold accents
- Lobby: Unchanged blue/indigo (no theme applied)

- [ ] **Step 4: Visual spot-check in browser**

Run: `bin/dev`
Play through each game type manually (or use playtest). Check:
- Stage gradient changes per game
- Hand view picks up theme
- Timer colors work
- Winner/scoring colors work
- Shared elements (instructions, host controls) adapt

- [ ] **Step 5: Clean up screenshots**

Run: `rake screenshots:clean`

- [ ] **Step 6: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: theme color adjustments from visual review"
```

---

## Summary

| Chunk | Tasks | What it delivers |
|-------|-------|-----------------|
| 1: Infrastructure | 1-4 | Theme tokens, helper, data attributes on containers |
| 2: Speed Trivia | 5-6 | Track Meet theme on all stage + hand + host control partials |
| 3: Write And Vote | 7-8 | Comedy Club theme on all stage + hand + host control partials |
| 4: Category List | 9-10 | Awards Gala theme on all stage + hand + host control partials |
| 5: Shared & Verify | 11-12 | Shared partials, full test suite, visual review |

**Total files modified:** ~35 partials + 1 CSS file + 1 helper + 1 test file.

Each chunk produces a working, testable state. The default theme values match the current blue/indigo, so partially-completed work won't break unthemed views.

**Note on oklch alpha tokens:** `theme-accent-subtle` and `theme-text-muted` have baked-in alpha values. Tailwind opacity modifiers (e.g., `bg-theme-accent-subtle/50`) won't override the built-in alpha — use these tokens at their defined opacity.
