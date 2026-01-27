# Background Services

## Timer System

### Philosophy

The server is the authority on time. Client-side timers are for display only and are not trusted. A small amount of variance between clients is acceptable for a casual party game.

### Implementation

Timers are implemented using Sidekiq jobs:

1. When a timed phase begins, the game logic calls `game.start_timer!(duration)`
2. The `HasRoundTimer` concern stores `round_ends_at` on the game model and schedules a `GameTimerJob`
3. When the job executes, it calls `game.process_timeout(round_number, step_number)`
4. The game model verifies it's still in the expected state before handling the timeout
5. Timeout handling is game-specific (e.g., fill empty responses, advance to next phase)

### Reconnection

Timer state (`round_ends_at`) is stored on the game model. When a client reconnects, the server can calculate remaining time and send it to the client.

### Sidekiq

Sidekiq handles all background job processing. Configuration is in `config/sidekiq.yml` if present, otherwise uses defaults. In development, `bin/dev` starts Sidekiq automatically via Procfile.dev.
