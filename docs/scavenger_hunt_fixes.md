# Scavenger Hunt Post-Rebase Fixes

Tracking the must-fix items from the [review by a 37signals-style reviewer](#37signals-review-2026-05-09). These are objective bugs, performance problems, or architectural issues. No design judgment calls needed.

## Status

Feature flagged off. Safe to merge and iterate.

---

## 🔴 MUST FIX

### 1. `broadcast_host_controls` triggers polymorphic N+1 on every game type

**File:** `app/broadcaster/game_broadcaster.rb`
**Problem:** `room.current_game.is_a?(ScavengerHuntGame)` materializes the polymorphic association on *every* broadcast for *every* game type. `room.reload` before broadcast guarantees cache miss.

```ruby
def self.broadcast_host_controls(room:)
  update_all_host_controls(room)
  update_scavenger_hunt_curation(room) if room.current_game.is_a?(ScavengerHuntGame)  # <-- bad
end
```

**Fix:** Gate on the string column you already have:
```ruby
update_scavenger_hunt_curation(room) if room.game_type == Room::SCAVENGER_HUNT
```

No query needed.

---

### 2. FK columns use `t.integer` mixed with `t.bigint` primary keys

**Files:** `db/migrate/20260310144619_create_scavenger_hunt_games.rb`, `db/migrate/20260310144705_create_hunt_prompt_instances.rb`

```ruby
t.integer :currently_showing_submission_id, null: true   # id is bigint
t.integer :winner_submission_id, null: true              # id is bigint
```

**Problem:** Type mismatch. PG tolerates it, but schema diffs, pg_dump, and some tooling complain. The fix migration (`20260509044500`) added the FK on `winner_submission_id` but didn't change the column type.

**Fix:** New migration:
```ruby
change_column :scavenger_hunt_games, :currently_showing_submission_id, :bigint
change_column :hunt_prompt_instances, :winner_submission_id, :bigint

add_foreign_key :scavenger_hunt_games, :hunt_submissions,
                column: :currently_showing_submission_id,
                on_delete: :nullify
add_index :scavenger_hunt_games, :currently_showing_submission_id
```

Also change the DB default on `currently_showing_submission_id` — the column was added as `t.integer` and now has the association `belongs_to :currently_showing_submission` on the model. Make the DB match.

---

### 3. ActiveStorage N+1 on every hand broadcast

**File:** `app/views/games/scavenger_hunt/_prompt_list.html.erb`

```erb
<% game.hunt_prompt_instances.includes(:hunt_prompt, :hunt_submissions).each do |instance| %>
  <% submission = instance.hunt_submissions.find { |s| s.player_id == player.id } %>
  <% if submission&.media&.attached? %>
    <%= image_tag url_for(submission.media), ... %>
```

`hunt_submissions` are preloaded, but `media_attachment` and `blob` are not. Every player's hand view, on every broadcast, issues N queries for the attachment + N for the blob. With 30 players and 10 prompts: 600 extra queries per broadcast.

**Fix:** Use `with_attached_media` on the association preload. Either:

Option A — in the view (quick):
```erb
<% game.hunt_prompt_instances.includes(:hunt_prompt, ...).each do |instance| %>
  <% submissions = instance.hunt_submissions.select { ... } %>
```
then `submissions.each { |s| s = HuntSubmission.with_attached_media.find(s.id) }` — ugly.

Option B — model scope (cleaner):
Add a scope on `ScavengerHuntGame`:
```ruby
scope :for_hand, -> { includes(hunt_prompt_instances: { hunt_submissions: [:player, { media_attachment: :blob }] }) }
```
And use it anywhere that renders `_prompt_list`. Same issue in `_stage_revealing.html.erb` with `currently_showing_submission`.

Option C — presenter object (follow-up): pass a presenter into the view that preloads everything. Out of scope for this fix; just do B.

---

### 4. Scoring logic is the chattiest possible implementation

**File:** `app/services/games/scavenger_hunt.rb`

```ruby
def self.calculate_scores(game)
  game.hunt_prompt_instances.find_each do |instance|
    instance.hunt_submissions.joins(:media_attachment).each do |sub|
      sub.player.increment!(:score, weight)   # one UPDATE per submission
    end

    if instance.winner_submission
      instance.winner_submission.player.increment!(:score, weight)   # another
    end
  end
end
```

For 30 players × 20 prompts: 900 UPDATE statements.

**Fix:** Accumulate deltas, update once per player.
```ruby
def self.calculate_scores(game)
  score_changes = Hash.new(0)

  game.hunt_prompt_instances.includes(:hunt_prompt, :hunt_submissions, :winner_submission).find_each do |instance|
    weight = instance.weight

    instance.hunt_submissions.joins(:media_attachment).each do |sub|
      score_changes[sub.player_id] += weight
    end

    if instance.winner_submission
      score_changes[instance.winner_submission.player_id] += weight
    end
  end

  score_changes.each do |player_id, delta|
    Player.where(id: player_id).update_all("score = score + #{delta}")
  end
end
```

Use `Arel.sql` or parameterized SQL for the delta if `update_all` doesn't quote it cleanly.

---

### 5. iPhone HEIC uploads silently break client-side compression

**File:** `app/javascript/controllers/games/image_upload_controller.js`

The controller reads `file` into `new Image()`, draws it to a canvas, and re-encodes as JPEG. **iPhones default to HEIC**, which `<img>` cannot decode outside Safari. The `img.onload` never fires; no error is surfaced. User taps "Take Photo", sees "Compressing...", and waits forever.

**Fix — minimum:** Add `onerror` on the Image, surface an error, skip compression for non-JPEG/PNG:
```javascript
img.onerror = () => {
  this.statusTarget.textContent = "Upload failed: unsupported photo format. Try again with a JPEG or PNG."
  this.barTarget.style.width = "0%"
  // fall through to form.submit() with original file
  form.requestSubmit()
}
```

Better: check `file.type` early:
```javascript
const canCompress = /^image\/(jpeg|png)$/.test(file.type)
if (!canCompress) {
  // skip canvas, submit original
  form.requestSubmit()
  return
}
```

**Fix — recommended:** Move compression server-side with `image_processing` + `vips`. The JS controller becomes "submit the file, let ActiveStorage variants handle it." This removes 75 lines of canvas code and the HEIC problem entirely. It requires ActiveStorage to process on upload, which may need a background job.

Do the minimum fix first; server-side compression is a follow-up bead.

---

### 6. `team_name.presence || name` copy-pasted in 8+ views

**File:** Various views across the scavenger hunt and shared partials.

```erb
<%= player.team_name.presence || player.name %>
```

Appears in:
- `_host_controls.html.erb`
- `_prompt_list.html.erb`
- `_stage_revealing.html.erb`
- `_stage_awarding.html.erb`
- `_curation_panel.html.erb`
- `_game_over.html.erb`
- `_stage_finished.html.erb`
- `_stage_player.html.erb` (shared)

**Fix:** Add to `Player` model:
```ruby
def display_name = team_name.presence || name
```

Replace all 8 occurrences with `player.display_name`. The reviewer says 8+; grep to confirm exact count.

---

### 7. Move curation TODO comment out of production ERB

**File:** `app/views/games/scavenger_hunt/_host_controls.html.erb` (lines ~45-55)

There is a multi-line ERB comment documenting the card picker / curation panel tension. It was added as a source-code TODO so the next agent wouldn't lose track. The reviewer rightly flagged it: production ERB should not host unresolved architecture debates.

**Decision:** Remove from ERB. Track as a **bead** if the project uses beads; otherwise open a GitHub issue titled:
> "Scavenger Hunt: resolve card picker vs. curation panel UX tension"

Body: "`card_picker.html.erb` shows every submission with media for the reveal carousel. `curation_panel.html.erb` has `completed` / `favorite` / `notes` toggles, but the card picker ignores `completed?`. Need to decide: (a) curation is backstage-only, card picker is casual-host; (b) card picker only shows `completed` submissions; or (c) remove curation if card picker is primary."

This project **does use beads**. Move it to a bead.

---

### 8. (Deferred — design smell, not blocking) Hardcoded `timer_enabled: true` ignores contracted param

**File:** `app/services/games/scavenger_hunt.rb`

```ruby
def self.game_started(room:, timer_enabled: true, ...)
  # ...
  game = ScavengerHuntGame.create!(
    timer_duration: duration_seconds,
    timer_enabled: true,   # <-- ignores the argument
    ...
  )
```

The reviewer says: "either respect the param or remove it from the signature." The UI hides the timer checkbox for scavenger hunt, so the argument is always `true` in practice. Removing it from the signature would break the `GameEventRouter` contract, which passes `timer_enabled` for all game types.

**Recommendation (deferred):** Think about a more robust contract. Maybe the router should not pass timer params to game types that don't support disabling timers, or each game type should declare its supported params. Not worth a fix now; document as a convention note in CLAUDE.md or a bead.

---

## 🟡 SHOULD FIX (included here because cheap)

### 9. Empty Stimulus controller for "future enhancements"

**File:** `app/javascript/controllers/games/card_picker_controller.js`

```javascript
export default class extends Controller {
  static targets = ["carousel"]
  // This controller exists for future enhancements (swipe gestures, snap scrolling).
}
```

Remove it. Re-add when there's actual gesture code. A controller with no behavior is dead code.

---

## Test Plan

After all fixes above, verify:
- `TEST_ENV_NUMBER=3 bin/rspec spec/system/games/scavenger_hunt_happy_path_spec.rb` passes
- `TEST_ENV_NUMBER=3 bin/rspec spec/models/scavenger_hunt_game_spec.rb spec/services/games/scavenger_hunt_spec.rb` passes
- `rubocop` clean on all touched files
- `brakeman` returns 0 warnings

---

## Dependencies

- None. These are all self-contained fixes on the scavenger hunt branch.
- The N+1 and timer_comment items touch broadcast infrastructure but stay within this branch's changes.

## Context Window Note

This plan was generated to keep context under the 40-message limit. A new agent session should start here.
