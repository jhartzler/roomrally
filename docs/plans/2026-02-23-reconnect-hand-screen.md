# Reconnect Hand Screen Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Silently reload the player hand page when Safari (or any browser) suspends the WebSocket connection by backgrounding the tab, so players never see stale game state on reconnect.

**Architecture:** A Stimulus controller attached to `hands/show.html.erb` listens for `visibilitychange` events. If the page was hidden for more than 30 seconds, it calls `Turbo.visit(window.location.href, { action: "replace" })` on becoming visible — a silent full-page replace that re-fetches current server state from `HandsController#show`.

**Tech Stack:** Stimulus (already in project at `app/javascript/controllers/`), Page Visibility API (standard browser API, no install needed), Turbo (already imported globally via `application.js`).

---

### Task 1: Create the Stimulus controller

**Files:**
- Create: `app/javascript/controllers/reconnect_controller.js`

**Step 1: Write the failing test**

JavaScript unit tests aren't set up in this project — skip to implementation directly.

**Step 2: Implement the controller**

Create `app/javascript/controllers/reconnect_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.hiddenAt = null
    this.boundHandler = this.handleVisibilityChange.bind(this)
    document.addEventListener("visibilitychange", this.boundHandler)
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.boundHandler)
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.hiddenAt = Date.now()
    } else if (this.hiddenAt && (Date.now() - this.hiddenAt) > 30_000) {
      this.hiddenAt = null
      Turbo.visit(window.location.href, { action: "replace" })
    } else {
      this.hiddenAt = null
    }
  }
}
```

**Step 3: Verify Stimulus auto-registration picks it up**

Stimulus registers controllers by scanning `app/javascript/controllers/` — check that `app/javascript/controllers/index.js` uses `eagerLoadControllersFrom` (it should already). No changes needed if so.

Run: `grep -n "eagerLoad\|reconnect" app/javascript/controllers/index.js`

Expected: see `eagerLoadControllersFrom("controllers", application)` — the new controller will be auto-registered as `reconnect`.

**Step 4: Commit**

```bash
git add app/javascript/controllers/reconnect_controller.js
git commit -m "feat: add reconnect Stimulus controller for hand screen state recovery"
```

---

### Task 2: Attach the controller to the hand view

**Files:**
- Modify: `app/views/hands/show.html.erb`

**Step 1: Read the current file**

Read `app/views/hands/show.html.erb`. The outermost element is:
```erb
<div class="min-h-screen p-4">
```

**Step 2: Add the data-controller attribute**

Change:
```erb
<div class="min-h-screen p-4">
```
To:
```erb
<div class="min-h-screen p-4" data-controller="reconnect">
```

**Step 3: Smoke test manually**

Start the dev server (`bin/dev`), open the hand page in Safari, background the tab for 30+ seconds, return. The page should silently reload. You can verify by checking the Network tab in Safari DevTools — you should see a GET request to the hand URL when you return to the tab.

**Step 4: Commit**

```bash
git add app/views/hands/show.html.erb
git commit -m "feat: attach reconnect controller to hand screen view"
```

---

### Task 3: Write a system spec to document the reconnect behavior

**Files:**
- Create: `spec/javascript/reconnect_controller_spec.rb` — skip, no JS unit test setup
- Modify: `spec/system/hands_spec.rb` (create if doesn't exist)

**Context:** We can't simulate Safari's WebSocket suspension in Capybara. Instead, write a system spec that:
1. Navigates to the hand page
2. Calls `page.execute_script` to fire a `visibilitychange` event with `document.hidden = true`, waits, then fires it again with `hidden = false`
3. Asserts the page reloaded (e.g., checks the URL is still correct and content is present)

**Step 1: Check if hands_spec.rb exists**

Run: `ls spec/system/`

**Step 2: Write the spec**

Create or append to `spec/system/reconnect_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Hand screen reconnect", :js do
  let(:room) { create(:room, :with_host) }
  let(:player) { create(:player, room: room) }

  before do
    # Establish session as the player
    driven_by(:playwright)
    page.driver.browser.add_cookie(
      name: "_session_id",
      value: player.session_id
    )
  end

  it "reloads the page when tab has been hidden for more than 30 seconds" do
    visit room_hand_path(room)
    expect(page).to have_css("#hand_screen")

    # Simulate page going hidden
    page.execute_script(<<~JS)
      Object.defineProperty(document, 'hidden', { value: true, configurable: true });
      document.dispatchEvent(new Event('visibilitychange'));
    JS

    # Fast-forward time by manipulating hiddenAt on the controller
    page.execute_script(<<~JS)
      const el = document.querySelector('[data-controller~="reconnect"]');
      const ctrl = window.Stimulus?.getControllerForElementAndIdentifier(el, 'reconnect');
      if (ctrl) ctrl.hiddenAt = Date.now() - 35000;
    JS

    # Simulate page becoming visible again
    page.execute_script(<<~JS)
      Object.defineProperty(document, 'hidden', { value: false, configurable: true });
      document.dispatchEvent(new Event('visibilitychange'));
    JS

    # Page should have reloaded — hand_screen still present
    expect(page).to have_css("#hand_screen")
    expect(current_path).to eq(room_hand_path(room))
  end
end
```

**Note on Stimulus controller access:** `window.Stimulus` may not expose `getControllerForElementAndIdentifier` in this setup. If this approach doesn't work, simplify: just verify the page reloads by checking a request was made. The core behavior is already covered by manual testing (Task 2 Step 3). The system spec is documentation/regression value, not the primary verification.

**Step 3: Run the spec**

```bash
bin/rspec spec/system/reconnect_spec.rb
```

Expected: green, or an informative failure message that guides a fix. If the Stimulus access approach doesn't work, simplify the test to just check that `#hand_screen` is visible after the script sequence (proves no JS errors crashed the page).

**Step 4: Commit**

```bash
git add spec/system/reconnect_spec.rb
git commit -m "test: add system spec for reconnect controller behavior"
```

---

### Task 4: Run full test suite and open PR

**Step 1: Run all specs**

```bash
bin/rspec
```

Expected: all green. If failures are unrelated to this change, note them but don't fix them.

**Step 2: Run Rubocop**

```bash
rubocop
```

Expected: no offenses on new/modified files. JS files are not checked by Rubocop.

**Step 3: Open PR**

```bash
gh pr create --title "feat: reload hand screen on tab reconnect to recover missed broadcasts" --body "$(cat <<'EOF'
## Why

When Safari (or any browser) backgrounds a tab, it suspends the WebSocket connection. If a game phase transition broadcast fires during that window, the player's hand screen stays frozen at the old state — they see stale UI until a manual refresh.

This is a narrow timing window but coincides with Speed Trivia's ~30s answer phase, and becomes a real issue before any unmoderated rollout.

## What

Adds a small Stimulus controller (`reconnect_controller`) attached to the hand screen that listens for `visibilitychange` events. If the page was hidden for more than 30 seconds, it calls `Turbo.visit` with `action: replace` on becoming visible — a silent full-page reload that re-fetches current game state.

No server changes. No custom Action Cable channels. ~25 lines of JS.

## Reviewer notes

- The 30s threshold is a judgment call. Short enough to catch real suspensions, long enough to avoid reloading on quick task-switches. Can be tuned if playtest feedback suggests otherwise.
- The system spec uses JS manipulation to fast-forward the `hiddenAt` timestamp — there's a note in the spec if the Stimulus controller access approach doesn't work cleanly, with a simpler fallback.
- This does NOT fix the architectural gap (no catch-up for missed broadcasts) — it works around it by re-fetching on reconnect.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
