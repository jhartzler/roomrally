# Stage Viewport Fit Design

**Date:** 2026-02-13
**Status:** Approved
**Problem:** Stage views sometimes require scrolling when content overflows the viewport, breaking the projected display experience.
**Solution:** Use viewport-relative units (vh/vw) to ensure all stage content fits within 1920x1080 without scrolling.

## Context

Room Rally stages are projected on shared screens (typically 1920x1080 Full HD projectors) for in-person multiplayer games. Currently, some game states overflow the viewport, requiring scrolling which is not viable on a projected, non-interactive display.

Recent overflow issues:
- Score podium cards being cut off (fixed via removing scale-110)
- Voting screens with many responses
- Category reviewing screens with many player answers

## Requirements

1. **No scrolling required** - All content must fit within viewport (except 50+ players in lobby)
2. **Target resolution:** 1920x1080 (Full HD)
3. **Full viewport usage** - Content should scale to use all available vertical space
4. **Proportional scaling** - Text, spacing, and containers scale together to maintain design consistency
5. **Preserve player content** - Never truncate player responses/answers (core game content)

## Approach: Viewport-Relative Units

Replace fixed pixel sizes with viewport-relative units (vh/vw) throughout stage views. This makes all sizing proportional to the available viewport space.

### Layout Architecture

```
┌─────────────────────────────────────┐
│ Header (game name + QR)    ~12vh   │  ← Fixed proportion, compact
├─────────────────────────────────────┤
│                                     │
│  Main Content Area        ~88vh    │  ← Scales based on content
│  (game state partials)              │
│                                     │
└─────────────────────────────────────┘
```

**Key Principle:** Replace `min-h-[60vh]` (allows overflow) with `max-h-[Xvh]` (enforces limits) and use flexbox/grid to distribute space.

## Component Scaling Strategy

### 1. Text Elements
- **Headlines** (prompts, questions): `clamp(2rem, 4vh, 5rem)` - scales with viewport, bounded
- **Body text** (answers, player names): `clamp(1rem, 2.5vh, 3rem)`
- **Labels/metadata**: `clamp(0.75rem, 1.5vh, 1.5rem)`
- **Minimum readable size:** 0.75rem (12px)

### 2. Container Elements
- **Card padding:** `p-[2vh]` instead of `p-8` (scales ~21px at 1080px)
- **Margins between sections:** `mb-[3vh]` instead of `mb-12`
- **Border radius:** Stays in pixels (doesn't affect layout)

### 3. Grid Layouts
- **Gap between items:** `gap-[2vh]` instead of `gap-8`
- **Grid row height:** Auto-calculated by available space
- **Response grids:** Use `auto-rows-fr` to distribute height evenly
- **Dense grids:** Reduce gap to `gap-[1vh]` when many items

### 4. Lists (Score Podiums, Answer Lists)
- **Item height:** Scales based on item count (e.g., `min-h-[8vh]` for 4 items)
- **Use CSS Grid:** `grid-template-rows: repeat(auto-fit, minmax(Xvh, 1fr))`
- **Padding:** Compresses proportionally with available space

### 5. Fixed-Size Elements
- **QR codes:**
  - Lobby screen: Large centered (150px) - stays large to help players join
  - During game: Small corner (24px) - stays fixed/small
- **Icons/checkmarks:** Use `em` units to scale with text

## Implementation Scope

### Files to Update

**1. Main Stage Layout:**
- `app/views/stages/show.html.erb` - header sizing, content area height

**2. Game State Partials (14 files):**

Speed Trivia:
- `_stage_answering.html.erb`
- `_stage_reviewing.html.erb`
- `_stage_reviewing_scores.html.erb`
- `_stage_instructions.html.erb`
- `_stage_finished.html.erb`

Category List:
- `_stage_filling.html.erb`
- `_stage_reviewing.html.erb`
- `_stage_scoring.html.erb`
- `_stage_instructions.html.erb`
- `_stage_finished.html.erb`

Write & Vote:
- `_stage_voting.html.erb`
- `_stage_writing.html.erb`
- `_stage_instructions.html.erb`
- `_stage_finished.html.erb`

**3. Shared Components:**
- `app/views/rooms/_stage_lobby.html.erb`
- `app/views/games/speed_trivia/_score_podium.html.erb`
- `app/views/games/speed_trivia/_vote_summary.html.erb`
- `app/views/players/_stage_player.html.erb`

**4. Tailwind Configuration:**
- `tailwind.config.js` - add custom vh/vw utilities and clamp() text utilities

### What Stays the Same
- Color schemes, animations, borders
- Overall visual design and layout structure
- Game logic and interactions
- Player/backstage views (not stage views)

## Edge Cases

### 1. Player Count Limits
- **Lobby (50+ players):** Only case where cutoff is acceptable. Show as many player cards as fit, prioritize most recent joiners.
- **Score Podium:** Always shows top 4 (fits comfortably)
- **Answer Lists:** Scale down item height and text size to fit all players' answers

### 2. Text Overflow
- **Player responses/answers:** NEVER truncate - scale container and font size down to show complete text (core game content)
- **Prompts/questions:** Scale down font size to fit (created by host, controllable)
- **Player names:** May truncate if extremely long (edge case, less critical than responses)

### 3. Grid Density
When many responses (e.g., 20 answers):
- Reduce gap: `gap-[2vh]` → `gap-[1vh]`
- Scale down card padding
- Use 3-4 columns instead of 2 if needed

### 4. Minimum Sizes
- Text never smaller than `0.75rem` (12px) for readability
- If content can't fit at minimum sizes, that's a game design constraint (future: add character limits on player input)

### 5. Aspect Ratio
- Design assumes 16:9 (1920x1080)
- Different aspect ratios are a future consideration

## Implementation Strategy

1. **Update Tailwind config** with vh/vw utilities
2. **Update main stage layout** (`stages/show.html.erb`) for viewport-based sizing
3. **Update each game state partial** systematically (instructions → gameplay → reviewing → finished)
4. **Update shared components** (podium, vote summary, player cards)
5. **Test with edge cases** (many players, long text, dense grids)
6. **Use visual regression testing** to verify changes don't break design

## Success Criteria

- No scrolling required on any stage screen at 1920x1080
- All player responses/answers visible (never truncated)
- Design maintains visual consistency (proportional scaling)
- Works with edge cases: 50 players, 20 responses, long prompts
- Existing animations and interactions continue to work
