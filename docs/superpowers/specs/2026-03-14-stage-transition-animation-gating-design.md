# Stage Transition Animation Gating

## Problem

Every game action (player answer, vote, host click) calls `broadcast_all`, which calls `GameBroadcaster.broadcast_stage`. This re-renders the stage partial via Turbo morph into `#stage_content`. Every stage partial has `animate-fade-in` on its outer div, so the 0.4s fade-in replays on every broadcast — even when the game phase hasn't changed and the stage content is identical or near-identical.

The animation should only play on meaningful transitions: when the game phase changes (e.g., `answering` → `reviewing`) or when moving to a new round/question (which in all current games involves a phase change).

## Solution

A Stimulus controller on `#stage_content` that detects phase transitions by tracking the child element's ID, and only applies `animate-fade-in` when the phase actually changes.

### Why this approach

- **Zero friction for new game types.** New games already follow the convention of `id="stage_[status]"` on their outer div. No new attributes, keys, or configuration needed — animation gating is inherited automatically.
- **Keeps `broadcast_all` simple.** No changes to game services or the broadcaster. The animation logic lives entirely in one Stimulus controller.
- **Surgical scope.** Only `animate-fade-in` on outer stage containers is affected. All inner decorative animations (`animate-pulse`, `animate-bounce`, podium animations, timer animations, `animate-shrink-width`) remain untouched.

### What changes

1. **Remove `animate-fade-in`** from the outer `<div>` of all 15 stage partials (14 `_stage_*.html.erb` + 1 `_game_over.html.erb` in write_and_vote).

2. **Create `stage_transition_controller.js`** Stimulus controller:
   - Attached to `#stage_content` in `stages/show.html.erb`
   - On `connect`: records current child element ID, adds `animate-fade-in` to child (initial page load should animate)
   - Uses `MutationObserver` watching `childList` on `this.element`
   - On mutation: compares new child ID to stored ID
     - Different ID → phase transition → add `animate-fade-in` to new child, update stored ID
     - Same ID → in-phase morph update → no animation added

3. **Add `data-controller="stage-transition"` to `#stage_content`** in `app/views/stages/show.html.erb`.

### Files affected

**New file:**
- `app/javascript/controllers/stage_transition_controller.js`

**Modified — remove `animate-fade-in` from outer div:**
- `app/views/games/category_list/_stage_filling.html.erb`
- `app/views/games/category_list/_stage_finished.html.erb`
- `app/views/games/category_list/_stage_instructions.html.erb`
- `app/views/games/category_list/_stage_reviewing.html.erb`
- `app/views/games/category_list/_stage_scoring.html.erb`
- `app/views/games/speed_trivia/_stage_answering.html.erb`
- `app/views/games/speed_trivia/_stage_finished.html.erb`
- `app/views/games/speed_trivia/_stage_instructions.html.erb`
- `app/views/games/speed_trivia/_stage_reviewing.html.erb`
- `app/views/games/speed_trivia/_stage_waiting.html.erb`
- `app/views/games/write_and_vote/_stage_finished.html.erb`
- `app/views/games/write_and_vote/_stage_instructions.html.erb`
- `app/views/games/write_and_vote/_stage_voting.html.erb`
- `app/views/games/write_and_vote/_stage_writing.html.erb`
- `app/views/games/write_and_vote/_game_over.html.erb`

**Modified — add controller:**
- `app/views/stages/show.html.erb`

### Stimulus controller design

```javascript
// app/javascript/controllers/stage_transition_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.currentPhaseId = this.#childId()
    this.#animateChild()

    this.observer = new MutationObserver(() => this.#handleMutation())
    this.observer.observe(this.element, { childList: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  #handleMutation() {
    const newId = this.#childId()
    if (newId && newId !== this.currentPhaseId) {
      this.currentPhaseId = newId
      this.#animateChild()
    }
  }

  #childId() {
    return this.element.firstElementChild?.id
  }

  #animateChild() {
    const child = this.element.firstElementChild
    if (!child) return
    child.classList.remove("animate-fade-in")
    // Force reflow so animation restarts if same class is re-added
    void child.offsetWidth
    child.classList.add("animate-fade-in")
  }
}
```

### Edge cases

- **Initial page load (no morph):** Controller `connect` fires, adds animation. Correct.
- **Phase transition via morph:** Child ID changes (`stage_answering` → `stage_reviewing`), animation added to new element. Correct.
- **In-phase morph (player answers/votes):** Child ID unchanged, no animation. Correct.
- **Lobby → game start:** Child goes from lobby partial (no `stage_*` ID) to `stage_instructions`. ID changes, animation fires. Correct.
- **Game end → lobby:** Similar — ID changes, animation fires. Correct.
- **Reconnect controller refresh:** Full page reload via `Turbo.visit`, Stimulus reconnects fresh. Correct.

### What this does NOT change

- `broadcast_all` pattern — unchanged
- `GameBroadcaster` — unchanged
- Game service modules — unchanged
- Inner decorative animations (`animate-pulse`, `animate-bounce`, podium, timers) — unchanged
- Hand view animations — unchanged
- Backstage animations — unchanged

### Future extensibility

If a future game type needs animation on within-phase round changes (stays in `stage_playing` across rounds), the controller can be extended to also check a `data-stage-key` attribute as an opt-in override. But YAGNI for now — all current games transition phases on round changes.

### Testing

- System spec: verify that stage fade-in animation class is present after a phase transition
- System spec: verify that stage fade-in animation class is NOT re-added during in-phase morph updates (e.g., after a player submits an answer)
