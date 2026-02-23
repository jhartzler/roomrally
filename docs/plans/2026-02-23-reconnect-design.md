# Reconnect Design: Hand Screen State Recovery

**Date:** 2026-02-23
**Branch:** fix/reconnect-hand-screen (to be created)

## Problem

`GameBroadcaster.broadcast_hand` pushes Turbo Stream updates to each player's individual
Action Cable subscription. If a player's WebSocket is down when a broadcast fires, the
message is permanently lost — Turbo has no replay mechanism. The `#hand_screen` div stays
frozen at the last state the client received.

Safari is the primary culprit: it aggressively suspends WebSocket connections when a tab
is backgrounded, throttled, or power-managed. Other browsers are more permissive.

## Decision

Use the **Page Visibility API** (`visibilitychange` event) to detect when a player's
device returns from a suspended state, and silently reload the hand page via
`Turbo.visit(..., { action: "replace" })`.

This directly addresses the root cause (Safari backgrounding = WS suspension) without
touching Action Cable internals, adding server endpoints, or introducing custom channels.

Rejected alternatives:
- **Action Cable consumer callbacks** — not exposed as DOM events; requires monkey-patching internal objects
- **Custom ApplicationCable channel** — breaks the no-custom-channels architectural constraint and adds more code than the problem warrants
- **Periodic polling** — adds server load, overkill for a narrow timing window

## Architecture

One new Stimulus controller. No server changes.

```
User switches away from tab
  → visibilitychange fires (hidden=true) → controller records hiddenAt timestamp
User returns to tab
  → visibilitychange fires (hidden=false)
  → if (Date.now() - hiddenAt) > 30_000ms
      → Turbo.visit(window.location.href, { action: "replace" })
      → HandsController#show renders fresh server state
      → #hand_screen is replaced with current content
```

The 30-second threshold avoids spurious reloads on quick task-switches while reliably
catching Safari's WS suspension (typically kicks in after 30+ seconds of backgrounding).

## Components

### `app/javascript/controllers/reconnect_controller.js` (new)

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

### `app/views/hands/show.html.erb` (modified)

Add `data-controller="reconnect"` to the outermost div.

## Testing

System specs cannot reliably simulate Safari's `visibilitychange` behavior in CI.
Test strategy:

- **Unit test** the controller logic in isolation: stub `document.hidden`, verify
  `Turbo.visit` is called when hidden >30s, not called when hidden <30s
- No system spec needed — `HandsController#show` has existing coverage; the controller
  has no server interaction of its own

## Effort

~1 hour: ~25 lines of JS + 1 line in ERB + ~30 lines of tests.

## Cost of Deferring

Low likelihood (narrow timing window), low severity in-person (manual refresh works).
Becomes a real UX problem during longer game phases (Speed Trivia ~30s answer timer) and
before any unmoderated or wider rollout. Fix is small enough that deferring costs more
than doing it.
