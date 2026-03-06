# Speed Trivia "Clicker" Hand View

## Problem

Alpha user feedback: players stare at their phones instead of the big screen because the hand view duplicates the question text and full answer text. The shared screen experience suffers.

## Design

Turn the phone into a pure "clicker" — no question text, no answer text, just big letter buttons (A/B/C/D). Players must look at the stage to read the question and options, then tap the matching letter on their phone.

### Answer form changes

- **Remove** the question text card from the hand view entirely
- **Replace** the vertical stack of answer buttons with a responsive grid of letter-only buttons:
  - 4 options: 2x2 grid
  - 3 options: 2-col grid, last row centered
  - 2 options: 2x1 (side by side)
- Each button shows only the letter (A, B, C, D) — no answer text
- Buttons fill available phone viewport height for easy tapping
- Our own visual style: rounded corners, our color palette, distinct from Kahoot (no geometric shapes, no bright primary color coding)

### Already-answered state

- Same grid layout persists
- Selected button is highlighted (bright border/glow), others dimmed out
- Small "Locked in!" confirmation text below the grid

### What stays the same

- Header with question counter + room code
- Host controls at the bottom
- Stage view (already shows question + options with A/B/C/D — no changes needed)
- Waiting, instructions, and game_over hand partials
- Stimulus `disableOptions` controller (retargeted to new buttons)

## Files to modify

- `app/views/games/speed_trivia/_answer_form.html.erb` — the only view that changes
