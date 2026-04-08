# Per-Game Visual Themes — Design Spec

## Problem

All three games (Comedy Clash, Think Fast, A-List) share the same blue-to-indigo gradient and color scheme. Back-to-back games feel visually identical, causing fatigue — especially in party/classroom settings where hosts run multiple games in a session.

## Solution

Give each game its own visual identity ("theme") applied via CSS custom properties and native Tailwind utility classes. Themes are composable (any DOM subtree can declare a theme) and the architecture supports future layering (editions, modes, whitelabel) without building those features now.

## Theme Worlds

Each game lives in a distinct visual world — **cousins, not siblings**. Same Room Rally DNA (typography, layout bones, dark backgrounds) but different personalities.

### Comedy Clash → Comedy Club
- **Setting:** Dark comedy club. Brick wall, spotlight, neon signs.
- **Palette:** Deep purple-black base. Hot pink (`#ff3e8a`) primary accent. Warm gold (`#ffc832`) secondary.
- **Energy:** Loose, warm, silly. Open mic night vibes.
- **Future artwork (🎨):** Brick wall texture, neon sign SVGs ("APPLAUSE", "LOL"), microphone stand illustration, cocktail-napkin styled response cards.

### Think Fast → Track Meet
- **Setting:** Stadium under lights. Every question is a heat, every round is a race.
- **Palette:** Dark burnt umber base. Burnt orange (`#e8590c`) primary accent. Cream white secondary.
- **Energy:** Athletic, competitive, celebratory. Olympic urgency without intimidation.
- **Future artwork (🎨):** Track lane curves, stadium floodlights, starting blocks/finish line tape, stadium-style scoreboard.
- **Note:** Medal-count scoring (gold/silver/bronze per question instead of raw points) is backlogged separately.

### A-List → Awards Gala
- **Setting:** The Oscars of trivia. Velvet curtains, gold everything, dramatic letter reveals.
- **Palette:** Deep indigo-black base. Rich gold (`#ffd700`) primary accent. Burgundy (`#8b2252`) secondary.
- **Energy:** Dramatic, elegant, celebratory. Prestige game show.
- **Future artwork (🎨):** Velvet curtain texture, spotlight/award show lighting, red carpet, trophy/statuette illustration.

## Architecture

### Token System

Themes are defined as CSS custom properties, exposed as native Tailwind color utilities via `@theme`. Templates use classes like `bg-theme-accent`, `text-theme-text-muted`, `border-theme-surface-border/30` — with full support for opacity modifiers, hover states, etc.

**Token vocabulary (11 tokens):**

| Token | Purpose |
|-------|---------|
| `theme-bg-from` | Gradient start |
| `theme-bg-to` | Gradient end |
| `theme-accent` | Primary accent (headings, highlights) |
| `theme-accent-subtle` | Muted accent (borders, hover states) |
| `theme-secondary` | Secondary color (labels, metadata) |
| `theme-surface` | Card/panel background |
| `theme-surface-border` | Card/panel border |
| `theme-text` | Primary text |
| `theme-text-muted` | Secondary text |
| `theme-timer-start` | Timer bar start color |
| `theme-timer-end` | Timer bar danger color |

### Theme Application

**Data attribute on containers:**
```erb
<div data-game-theme="<%= game_theme_name(@game) %>" class="...">
```

A helper maps game type → theme name:
- `WriteAndVoteGame` → `"comedy-club"`
- `SpeedTriviaGame` → `"track-meet"`
- `CategoryListGame` → `"awards-gala"`

**Composability:** Any element can declare `data-game-theme` to scope its subtree. A preview card on a different page can use `data-game-theme="comedy-club"` independently.

**CSS structure:**
```
app/assets/tailwind/application.css
├── @theme { ... }                              ← theme-* Tailwind tokens
├── [data-game-theme="comedy-club"] { ... }     ← sets CSS vars
├── [data-game-theme="track-meet"] { ... }
├── [data-game-theme="awards-gala"] { ... }
└── (existing vh utilities, etc.)
```

### What Changes in Partials

Hardcoded Tailwind colors → theme tokens:
```diff
- bg-gradient-to-b from-blue-600 to-indigo-900
+ bg-gradient-to-b from-theme-bg-from to-theme-bg-to

- text-yellow-400
+ text-theme-accent

- bg-white/10 border-white/20
+ bg-theme-surface border-theme-surface-border
```

### What Does NOT Change
- Layout structure (flex, grid, spacing, vh units)
- Typography sizing (`text-vh-*` classes)
- Animations (future work)
- Non-themed semantic colors (success green, error red, pure white/black)
- Controllers, models, JS/Stimulus, database

## Surfaces

| Surface | Themed? | Notes |
|---------|---------|-------|
| Stage (projected) | Yes — full theme | Primary surface, highest visual impact |
| Hand (player phones) | Yes — follows stage theme | Same tokens, but maintains consistent UX patterns (button placement, form layouts, navigation stay stable) |
| Backstage (host dashboard) | No | Stays neutral/functional |
| Lobby | No | Generic Room Rally brand. Theme activates at game start. |

## Future Layering (Not Built Now — Backlogged)

The architecture supports additional dimensions via layered data attributes:
- `data-theme-mode="dark|light"` — user preference
- `data-theme-edition="halloween"` — seasonal overrides
- Whitelabel — brand color overrides

These layer on top of the game theme, overriding specific slots. Not in scope for this work.

## Rollout Plan

1. **Infrastructure:** Theme tokens in `@theme`, CSS custom property rulesets per game, helper method
2. **First game (Track Meet):** Apply to all stage + hand partials, verify end-to-end
3. **Remaining games:** Comedy Club, then Awards Gala
4. **Cleanup:** Verify shared partials (`_host_controls`, `_hand_instructions`, `_game_over`) adapt correctly, catch any leftover hardcoded colors

Use screenshot comparison workflow (`rake screenshots:capture/approve/report`) after each game to catch visual regressions.

## Refactoring Scope

| Area | Approx. Files | Work |
|------|---------------|------|
| Theme definitions | `application.css` | `@theme` tokens + 3 theme rulesets |
| Theme helper | 1 new helper | `game_theme_name` mapping |
| Stage container | `stages/show.html.erb` | Add data attribute, swap gradient |
| Hand container | `hands/show.html.erb` | Add data attribute, swap gradient |
| Stage partials | ~13 files | Swap hardcoded colors → tokens |
| Hand partials | ~10 files | Swap hardcoded colors → tokens |
| Shared partials | ~3 files | Swap to theme tokens |

No model changes, no migrations, no controller changes, no JS changes.
