# Scavenger Hunt Game — Design Spec

## Overview

A team-based scavenger hunt where players go out into the real world, take photos against a list of prompts, and submit them from their phones. The host curates submissions as they roll in, then presents the best moments to everyone in a live presentation. Awards are given per-prompt and overall.

This game is designed for **in-person events** (youth groups, retreats, team building) where teams physically leave to complete challenges. A typical game runs 30–60 minutes. The host automates what was previously a painful manual process of collecting photos via text/Instagram/Google Drive and assembling a slideshow.

## Context & Motivation

The creator has run this game many times manually. The pain points this solves:
- Collecting submissions (previously via texting, Instagram, shared drives)
- Curating and organizing media under time pressure
- Building a presentation while people wait
- Scoring and tracking completion across teams

## Data Model

### ScavengerHuntGame

AASM states: `instructions → hunting → submissions_locked → revealing → awarding → finished`

| Field | Type | Notes |
|-------|------|-------|
| timer_duration | integer | Seconds (typically 1800–3600) |
| timer_enabled | boolean | |
| round_ends_at | datetime | For countdown display |

- `include HasRoundTimer`, implements `process_timeout`
- `has_one :room, as: :current_game`
- `belongs_to :hunt_pack, optional: true`
- `has_many :hunt_prompt_instances, dependent: :destroy`
- `self.supports_response_moderation?` returns `false`

State transitions:
- `instructions → hunting`: host starts, timer begins
- `hunting → submissions_locked`: timer expires (via GameTimerJob) OR host manually locks
- `hunting → revealing`: host skips straight to reveal (submissions cut off, no late window)
- `submissions_locked → revealing`: host starts reveal
- `revealing → awarding`: host starts awards ceremony
- `awarding → finished`: host ends awards, `room.finish!` called

Submissions are only accepted during `hunting` and `submissions_locked`. Once the game enters `revealing`, no further submissions are accepted.

### HuntPack (content pack, reusable)

Follows the `TriviaPack` / `CategoryPack` pattern.

| Field | Type | Notes |
|-------|------|-------|
| name | string | Pack name |
| user_id | integer | Owner (nullable for system packs) |

- `has_many :hunt_prompts, dependent: :destroy`
- Room gets `belongs_to :hunt_pack, optional: true`

### HuntPrompt (content pack level, reusable)

| Field | Type | Notes |
|-------|------|-------|
| body | text | The prompt text |
| weight | integer | Default 5. Points for completion. |
| position | integer | Ordering within pack |

- `belongs_to :hunt_pack`

### HuntPromptInstance (per-game instance)

| Field | Type | Notes |
|-------|------|-------|
| position | integer | Display/reveal order, host can reorder |

- `belongs_to :scavenger_hunt_game`
- `belongs_to :hunt_prompt`
- `has_many :hunt_submissions`
- `belongs_to :winner_submission, class_name: "HuntSubmission", optional: true` (set during awards)

### HuntSubmission

| Field | Type | Notes |
|-------|------|-------|
| late | boolean | Default false. Auto-set if submitted during `submissions_locked`. |
| completed | boolean | Default false. Host marks during curation. |
| favorite | boolean | Default false. Host shortlist for awards. |
| host_notes | text | Nullable. Host's private notes/quips. |

- `belongs_to :hunt_prompt_instance`
- `belongs_to :player` (the photographer)
- `has_one_attached :media` (Active Storage → R2)

### Player changes

- Add `team_name` (string, nullable) — used in scavenger hunt context
- One player per team in v1 (the photographer). They represent their team.
- The join form conditionally shows a "Team name" field when the room's game type is Scavenger Hunt.
- **v1 limitation:** `player.score` doubles as the team score since there's one photographer per team. This breaks if multiple photographers share a team — the fast-follow "multiple photographers per team" will need score aggregation by `team_name` or a proper Team model.

## Game Registration

- Internal model: `ScavengerHuntGame`
- Display name: "Photo Scavenger Hunt"
- Game type string: `"Scavenger Hunt"`
- Register in `game_registry.rb` (GameEventRouter + DevPlaytest::Registry)
- Add to `Room::GAME_TYPES` and `Room::GAME_DISPLAY_NAMES`

## Game Service Contract

```ruby
module Games
  module ScavengerHunt
    def self.requires_capacity_check? = false
    def self.game_started(room:, timer_enabled:, timer_increment:, show_instructions:, timer_duration:, **_extra)
    def self.start_from_instructions(game:)
    def self.handle_timeout(game:)  # locks submissions when timer expires
  end
end
```

## Game Flow

### 1. Lobby → Instructions

- Host creates room, selects "Photo Scavenger Hunt"
- Players join with name + team name field (one photographer per team)
- Host starts game → instructions screen

### 2. Instructions → Hunting

- Shared `_hand_instructions` partial
- Host clicks start → timer begins, game enters `hunting`

### 3. Hunting (30–60 minutes)

**Stage:** Countdown timer + submission count ("12 of 45 prompts completed across 6 teams"). No photos shown — preserves the presentation.

**Photographer hand:**
- Full prompt list with status icons (empty / submitted / late)
- Tap prompt → native file picker (`<input type="file" accept="image/*">` — gives camera or photo library choice on mobile)
- Client-side image compression (resize to 1920px wide, 80% JPEG quality via canvas API in a Stimulus controller) before upload
- Upload progress indicator on the prompt card
- Failure handling: "Upload failed, tap to retry"
- After upload: thumbnail shown on the prompt card, can re-submit (replaces previous)
- Timer visible at top

**Host backstage (laptop — primary curation surface):**
- Left panel: prompt list sidebar with submission count badges
- Right panel: submission grid for selected prompt — thumbnail, team name, timestamp, late badge
- Per-submission actions: mark completed (checkmark), favorite (star), add note (inline text)
- Global actions: "Lock Submissions" button, "Start Presentation" button
- Timer + submission count always visible

**Host hand (phone — simplified curation):**
- Same actions (complete, favorite, note) but in a simpler list layout
- Lock Submissions + Start Presentation buttons

### 4. Submissions Locked

- Triggered by timer expiration or host manual lock
- Stage: countdown replaced with waiting message
- Photographers can still submit — submissions auto-flagged `late: true`
- Host continues curating
- Transitions to `revealing` when host is ready

### 5. Revealing (the main event)

**No further submissions accepted once revealing begins.**

**Host controls — Card Picker:**
- Grid of thumbnail cards, one per submission the host marked as completed
- Grouped by prompt with header dividers
- Tap a card → pushes it to stage full-screen, card dims with checkmark
- Already-shown cards sort to end (not hidden — host can revisit)
- On mobile: horizontal carousel swipe within each prompt group
- On backstage: grid layout (more screen real estate)

**Stage:**
- Full-screen media display, one submission at a time
- Prompt text at top, team name at bottom
- Simple fade/slide transitions between submissions

**Photographer hand during reveal:**
- Spectator view: "The host is presenting!" with current prompt name

### 6. Awarding

- Host taps "Start Awards" → game enters `awarding` state
- Stage: awards ceremony UI
- Host picks **best submission per prompt** from completed submissions → stage shows winner with prompt context
- **Winning team** auto-calculated from total points
- Stage: per-prompt winners announced, then final scoreboard

### 7. Finished

- `room.finish!` called on transition to finished
- Stage: final scoreboard — teams ranked by total points, winning team highlighted
- Photographer hand: game over screen

## Scoring

| Event | Points |
|-------|--------|
| Prompt completed | `weight` (default 5) |
| Prompt winner (best submission) | `weight` additional (so 2x total) |

- Winning team = highest total points (auto-calculated)
- Default prompt weight: 5

## Technical Notes

### File Upload

- Active Storage with Cloudflare R2 (already configured)
- Client-side image compression via Stimulus controller using native canvas API — new pattern, no existing Stimulus controller does canvas processing. Deserves its own implementation step with dedicated testing.
- Resize to max 1920px wide, JPEG 80% quality (~200-400KB vs 5-8MB raw)
- Direct upload with progress indicator
- `<input type="file" accept="image/*">` — lets user choose camera or photo library on mobile
- **Infrastructure note:** Direct upload from player-facing views is new (existing direct upload is admin-only in trivia pack form). May need CORS configuration on R2 and verification that `ActiveStorage::DirectUploadsController` route is available.

### Concurrency

- `with_lock` for all state transitions (standard pattern)
- Submission uploads are independent (no lock needed for individual uploads)
- Timer expiration via `GameTimerJob` + `process_timeout` (standard HasRoundTimer pattern)

### Broadcasting

- Standard `broadcast_all` private method pattern
- Stage, hand, and host controls updated via GameBroadcaster
- Submission count on stage updates in real-time as uploads complete

### Viewport Units

- All stage views use `vh` units per project convention
- Stage never scrolls

### Playtest Module

`Games::ScavengerHunt::Playtest` follows the standard contract (`start`, `advance`, `bot_act`, `auto_play_step`, `progress_label`, `dashboard_actions`). Bot photo submissions use fixture image files attached via Active Storage in test/development. This avoids needing real camera input for playtesting.

## MVP Scope

**In v1:**
- HuntPack model with HuntPrompts (reusable prompt packs)
- Single photographer per team
- Photo uploads only
- Simple weighted prompts (no compound)
- Timer with late submission support
- Backstage curation (complete, favorite, notes)
- Hand-view curation (simplified)
- Card picker presentation (carousel mobile, grid backstage)
- Awards ceremony with own AASM state (best per prompt, auto-calculated winning team)
- Client-side image compression
- Stage views for all states
- Playtest module with fixture-based bot submissions

**Fast follow:**
- Video uploads (original size, stage playback)
- Multiple photographers per team (shared team_name, score aggregation)
- Compound prompts (modifier attributes on base prompts)
- Host override on winning team ("points suggest, host decides")
- Custom bonus multipliers
- Shared/public prompt pack library

**Not planned yet:**
- Player voting on submissions
- Live submission feed on stage during hunting
- Team formation UI (drag players into teams)
