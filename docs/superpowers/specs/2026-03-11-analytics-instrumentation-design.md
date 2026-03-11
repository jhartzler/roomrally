# Analytics Instrumentation Design

## Problem

Room Rally has few users and spiky usage. Every session matters for collecting feedback and improving the product. The current PostHog instrumentation covers 10 server-side events but has gaps in coverage and consistency. More importantly, there's no way to review what happened during a session after the fact — no admin UI, no session recap, no health checks. The DB contains rich data about every game session but it's only accessible via Rails console.

## Goals

1. **Session feed in admin dashboard** — chronological list of all room sessions at `/admin/sessions`, viewable on phone
2. **Session timeline reconstruction** — expandable per-session narrative built from DB records and a new `game_events` table
3. **Session health checks** — lightweight anomaly detection that flags system misbehavior (stuck states, missing data, count mismatches)
4. **New PostHog events** — fill blind spots where no DB record exists (studio editing, pre-game funnels, abandonment)
5. **Clean up existing PostHog events** — fix inconsistent `distinct_id` patterns and empty properties

## Non-Goals

- Client-side JS tracking or session replay
- PostHog data displayed in the admin dashboard (use PostHog's own UI)
- Pre-computed anomaly scores or stored health state
- Pagination (unnecessary at current scale)

## Design Split

| Concern | Tool | Purpose |
|---------|------|---------|
| "Did the system behave correctly?" | Admin dashboard (DB-driven) | Session timelines, health flags, anomaly spotting |
| "Did the user behave the way I expected?" | PostHog | Funnels, behavioral patterns, trends over time |

---

## Part 1: Admin Session Feed

### Route & Navigation

New admin controller at `Admin::SessionsController` inheriting from `Admin::BaseController`. Routes:

```ruby
namespace :admin do
  resources :sessions, only: [:index, :show]
end
```

Add "Sessions" tab to admin nav alongside existing "Users" tab.

### Index Page (`/admin/sessions`)

Chronological feed, newest first. Each row shows:

- **Health dot** — green (clean), yellow (oddities), red (broken), gray (never started)
- **Room code** + game type display name
- **Date**, player count, duration, terminal state
- **Anomaly badges** — short chip labels for flagged issues
- **Expand/collapse** — click to reveal full timeline

### Hidden Sessions

Sessions can be hidden via a dismiss button on each row. Hidden state stored in browser `localStorage` keyed by room code. A "Show hidden" toggle at the top reveals them. No DB column needed — this is an admin UI preference.

### Show Page (`/admin/sessions/:room_code`)

Direct-linkable detail view for a single session. Same timeline content as the expanded index row, but full-page with more room for detail. Useful for sharing a link or bookmarking a problematic session.

---

## Part 2: GameEvent Model

### Schema

```ruby
create_table :game_events do |t|
  t.references :eventable, polymorphic: true, null: false
  t.string :event_name, null: false
  t.jsonb :metadata, default: {}
  t.datetime :created_at, null: false  # no updated_at — events are immutable
end

add_index :game_events, [:eventable_type, :eventable_id, :created_at]
```

### Initial Event Types

| event_name | metadata | Fired from |
|---|---|---|
| `state_changed` | `{ from: "waiting", to: "answering" }` | Game service methods on AASM transitions |
| `game_created` | `{ player_count:, timer_enabled:, game_type: }` | `game_started` service methods |
| `game_finished` | `{ duration_seconds:, player_count: }` | Service methods where game transitions to `finished` |

### Model

```ruby
class GameEvent < ApplicationRecord
  belongs_to :eventable, polymorphic: true

  def self.log(eventable, event_name, **metadata)
    create!(eventable:, event_name:, metadata:)
  rescue => e
    Rails.logger.warn("[GameEvent] Failed to log #{event_name}: #{e.message}")
  end
end
```

GameEvent writes are fire-and-forget — a failed insert must never halt game flow or prevent broadcasts. Same philosophy as `Analytics.track`.

### Placement Pattern

GameEvent and Analytics.track calls go side-by-side in game service methods. Both are called from the same chokepoint (game services), making it hard to add one without the other:

```ruby
def self.transition_to_answering(game:)
  game.with_lock { game.begin_answering! }
  GameEvent.log(game, "state_changed", from: "waiting", to: "answering")
  Analytics.track(distinct_id: ..., event: "round_started", properties: { ... })
  broadcast_all(game)
end
```

---

## Part 3: SessionRecap Service

`SessionRecap.for(room)` returns an ordered array of event structs assembled from multiple sources:

| Source | Events |
|---|---|
| `rooms` | Room created (with host user info) |
| `players` | Player joined (ordered by `created_at`) |
| `game_events` | State transitions, game created/finished (precise timestamps) |
| `trivia_answers` | Answer submitted (via `submitted_at`) |
| `responses` | Response submitted (via `created_at`) |
| `category_answers` | Answer submitted (via `created_at`) |
| `votes` | Vote cast (via `created_at`) |

Each event is a struct with `timestamp`, `event_type`, `description`, and optional `metadata`.

For sessions that predate the `game_events` table, the timeline simply omits state transition events — it still shows player joins, answer submissions, and votes from the domain tables. No inference logic for historical sessions; not worth the complexity given the small number of past sessions.

---

## Part 4: SessionHealth Service

`SessionHealth.check(room)` returns a list of flags, each with severity and description. Pure Ruby methods, no stored state — runs on page load.

### Initial Health Checks

| Check | Severity | Logic |
|---|---|---|
| Stuck in non-terminal state | `:error` | Game exists, status != `finished`, `updated_at` > 30 min ago |
| Never started | `:warning` | Room has players but no game record |
| Player with 0 submissions | `:warning` | Player active in room, game finished, 0 answers/responses for that player |
| Vote count mismatch | `:warning` | Write & Vote: total votes cast != expected based on player count and prompts |
| Winner score inconsistency | `:warning` | Highest-scoring player doesn't match expected winner |
| Abandoned mid-game | `:error` | Room status is `finished` but game status is not `finished` |

### Severity → Dot Color Mapping

- Green: zero flags
- Yellow: any `:warning` flags, no `:error` flags
- Red: any `:error` flags
- Gray: room never left lobby (no game record)

---

## Part 5: New PostHog Events

### New Events (4)

| Event | Location | distinct_id | Properties |
|---|---|---|---|
| `template_edited` | `GameTemplatesController#update` | `"user_#{user.id}"` | `game_type`, `template_id` |
| `template_deleted` | `GameTemplatesController#destroy` | `"user_#{user.id}"` | `game_type`, `template_id` |
| `join_page_viewed` | `PlayersController#new` (GET `/rooms/:code/join`) | `"session_#{session.id}"` | `room_code` |
| `instructions_skipped` | Game `start_from_instructions` methods | `room.user_id ? "user_#{room.user_id}" : "room_#{room.code}"` | `game_type`, `room_code` |

**Dropped from initial scope:**
- `game_abandoned` — no clean single-fire instrumentation point. The admin dashboard's `SessionHealth` flags already surface this. Can revisit if a periodic cleanup job is added later.
- `login_page_viewed` — no dedicated login page exists (Google OAuth only). The login button lives on various pages, making this impractical to track server-side.

---

## Part 6: Existing PostHog Cleanup

### Fix 1: Empty properties on auth events

`user_signed_up` and `user_logged_in` currently pass `properties: {}`. Add `provider: "google"` to both.

### Fix 2: Inconsistent distinct_id patterns

Current state:
- Player actions use `"player_#{session_id}"`
- Game lifecycle uses `"user_#{user_id}"` or `"room_#{code}"`

A casual host appears as two different people in PostHog.

Fix: Standardize game events to use `"user_#{user_id}"` when the room has an owner, `"room_#{code}"` as fallback. Ensure `room_code` is always in properties regardless of distinct_id choice. This matches the current pattern but needs to be applied consistently — audit all call sites during implementation.

**Note on player-scoped events:** `player_joined`, `vote_attempt`, `vote_failed`, and `vote_cast` intentionally use `"player_#{session_id}"` because these represent anonymous player actions, not host actions. The divergence between player events and game lifecycle events is correct — they represent different actors. The inconsistency to fix is within game lifecycle events only (some game services already use the conditional pattern correctly, just need to verify all do).

---

## Testing Strategy

- **SessionRecap**: Unit tests with factory-created rooms/games/answers, assert correct event ordering and completeness
- **SessionHealth**: Unit tests per check — create specific broken scenarios and assert correct flags
- **GameEvent**: Model spec for `.log`, integration tests verifying events are written during game service calls
- **Admin controllers**: Request specs for auth gating, system spec for index page rendering
- **PostHog events**: Assert `Analytics.track` calls in existing controller/service specs (already pattern-established)
