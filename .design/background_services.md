# Background Services

This document describes asynchronous services, primarily the Timer Service.

## Timer Service

### Philosophy
The server is the authority on time. Client-side timers are for user experience only and are not trusted. A small amount of variance (±3 seconds) between clients is acceptable for a casual party game.

### MVP Implementation: Sidekiq
The timer is implemented using background jobs.

**How it works:**
1. When a timed phase begins (e.g., "prompting"), the game logic calculates an expiration time.
2. It stores `timer_expires_at` and a `timer_event` (e.g., `"prompting_timer_expired"`) on the `Game` model.
3. It schedules a Sidekiq job to run at the `timer_expires_at` time.
4. When the job executes, it checks if the game is still in the expected state.
5. If so, it publishes the `timer_event` (e.g., `:prompting_timer_expired`).
6. The appropriate game logic module listens for this event to transition the game state (e.g., move from "prompting" to "voting").

**Pros:**
- **Simple**: Uses existing Sidekiq infrastructure.
- **Resilient**: Sidekiq jobs persist across server restarts. If the server crashes, the timer job will still execute when it comes back up (or shortly after), allowing the game to recover.
- **Testable**: Sidekiq provides testing helpers to control job execution in tests.

### Reconnection
If a player disconnects and reconnects while a timer is active, the server can calculate the remaining time from the `game.timer_expires_at` value and send it to the client so their countdown can start from the correct place.

### Future Complexity
We will only add more complex timer synchronization (e.g., per-second broadcasts, clock skew detection) if playtesting reveals it to be a significant problem. The current Sidekiq-based approach is sufficient for the MVP.
