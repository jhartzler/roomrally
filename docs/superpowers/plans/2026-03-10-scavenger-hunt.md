# Scavenger Hunt Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a team-based photo scavenger hunt game where teams submit photos against prompts, the host curates in real-time, and presents the best moments in a card-picker-driven reveal with awards.

**Architecture:** Follows the existing game type pattern (AASM model + service module + broadcasted Turbo Streams). Key differences from existing games: longer timer (30-60 min vs seconds), Active Storage file uploads from player hand view, card-picker reveal UI, and backstage-first curation experience.

**Tech Stack:** Rails 8, AASM, Active Storage (R2), Turbo Streams, Stimulus, Tailwind CSS with vh units.

**Spec:** `docs/superpowers/specs/2026-03-10-scavenger-hunt-design.md` — READ THIS FIRST. It contains design principles that explain _why_ decisions were made. The presentation is the product, the host is a performer, and the card picker exists because a ProPresenter-style slideshow is overwhelming for a host standing in front of a crowd.

---

## File Structure

### New files to create:

**Models:**
- `app/models/scavenger_hunt_game.rb` — AASM state machine, HasRoundTimer
- `app/models/hunt_pack.rb` — content pack (reusable prompt sets)
- `app/models/hunt_prompt.rb` — individual prompt in a pack
- `app/models/hunt_prompt_instance.rb` — per-game prompt instance
- `app/models/hunt_submission.rb` — player photo submission

**Migrations:**
- `db/migrate/TIMESTAMP_create_scavenger_hunt_games.rb`
- `db/migrate/TIMESTAMP_create_hunt_packs.rb`
- `db/migrate/TIMESTAMP_create_hunt_prompts.rb`
- `db/migrate/TIMESTAMP_create_hunt_prompt_instances.rb`
- `db/migrate/TIMESTAMP_create_hunt_submissions.rb`
- `db/migrate/TIMESTAMP_add_team_name_to_players.rb`
- `db/migrate/TIMESTAMP_add_hunt_pack_to_rooms.rb`

**Service:**
- `app/services/games/scavenger_hunt.rb` — game logic + nested Playtest module

**Controllers:**
- `app/controllers/scavenger_hunt/game_starts_controller.rb` — start from instructions
- `app/controllers/scavenger_hunt/submissions_controller.rb` — photo upload
- `app/controllers/scavenger_hunt/submission_locks_controller.rb` — lock submissions
- `app/controllers/scavenger_hunt/reveals_controller.rb` — start reveal, show submission on stage
- `app/controllers/scavenger_hunt/awards_controller.rb` — start awards, pick prompt winners
- `app/controllers/scavenger_hunt/finishes_controller.rb` — finish the game
- `app/controllers/scavenger_hunt/completions_controller.rb` — mark submission complete/favorite
- `app/controllers/hunt_packs_controller.rb` — CRUD for hunt packs (studio)

**Views — Hand:**
- `app/views/games/scavenger_hunt/_hand.html.erb` — router partial
- `app/views/games/scavenger_hunt/_prompt_list.html.erb` — photographer prompt list during hunting
- `app/views/games/scavenger_hunt/_spectator.html.erb` — spectator view during reveal
- `app/views/games/scavenger_hunt/_game_over.html.erb` — finished state

**Views — Stage (one per AASM state):**
- `app/views/games/scavenger_hunt/_stage_instructions.html.erb`
- `app/views/games/scavenger_hunt/_stage_hunting.html.erb`
- `app/views/games/scavenger_hunt/_stage_submissions_locked.html.erb`
- `app/views/games/scavenger_hunt/_stage_revealing.html.erb`
- `app/views/games/scavenger_hunt/_stage_awarding.html.erb`
- `app/views/games/scavenger_hunt/_stage_finished.html.erb`

**Views — Host controls:**
- `app/views/games/scavenger_hunt/_host_controls.html.erb` — state-dependent host buttons
- `app/views/games/scavenger_hunt/_card_picker.html.erb` — reveal card picker UI
- `app/views/games/scavenger_hunt/_curation_panel.html.erb` — backstage curation grid

**Views — Hunt packs (studio):**
- `app/views/hunt_packs/index.html.erb`
- `app/views/hunt_packs/new.html.erb`
- `app/views/hunt_packs/edit.html.erb`
- `app/views/hunt_packs/show.html.erb`
- `app/views/hunt_packs/_form.html.erb`
- `app/views/hunt_packs/_card.html.erb`

**Stimulus controllers:**
- `app/javascript/controllers/games/image_upload_controller.js` — client-side compression + upload progress
- `app/javascript/controllers/games/card_picker_controller.js` — carousel swipe on mobile

**Factories:**
- `spec/factories/scavenger_hunt_games.rb`
- `spec/factories/hunt_packs.rb`
- `spec/factories/hunt_prompts.rb`
- `spec/factories/hunt_prompt_instances.rb`
- `spec/factories/hunt_submissions.rb`

**Tests:**
- `spec/models/scavenger_hunt_game_spec.rb`
- `spec/models/hunt_submission_spec.rb`
- `spec/services/games/scavenger_hunt_spec.rb`
- `spec/system/games/scavenger_hunt_happy_path_spec.rb`

### Files to modify:

- `app/models/room.rb` — add SCAVENGER_HUNT constant, GAME_TYPES, GAME_DISPLAY_NAMES, `belongs_to :hunt_pack`
- `app/models/player.rb` — permit `team_name` (migration adds column)
- `app/views/players/new.html.erb` — conditional team_name field
- `app/controllers/players_controller.rb` — permit `team_name` in strong params
- `app/views/rooms/_game_settings_fields.html.erb` — scavenger hunt settings (timer duration, pack picker)
- `app/views/rooms/_hand_screen_content.html.erb` — already dynamic via `game_type.parameterize.underscore` (no change needed)
- `config/initializers/game_registry.rb` — register game + playtest
- `config/routes.rb` — add scavenger hunt routes + hunt pack routes

---

## Chunk 1: Foundation — Models, Migrations, Registration

This chunk creates the database schema, models, and wires the game type into the registry. After this chunk, the game type exists and can be selected in a room, but has no gameplay.

### Task 1: Create HuntPack and HuntPrompt models

**Files:**
- Create: `db/migrate/TIMESTAMP_create_hunt_packs.rb`
- Create: `db/migrate/TIMESTAMP_create_hunt_prompts.rb`
- Create: `app/models/hunt_pack.rb`
- Create: `app/models/hunt_prompt.rb`
- Create: `spec/factories/hunt_packs.rb`
- Create: `spec/factories/hunt_prompts.rb`

- [ ] **Step 1: Generate migrations**

```bash
bin/rails generate migration CreateHuntPacks name:string user_id:integer is_default:boolean game_type:string status:integer
bin/rails generate migration CreateHuntPrompts body:text weight:integer position:integer hunt_pack:references
```

Then edit the hunt_packs migration to add defaults:
```ruby
class CreateHuntPacks < ActiveRecord::Migration[8.1]
  def change
    create_table :hunt_packs do |t|
      t.string :name
      t.references :user, null: true, foreign_key: true
      t.boolean :is_default, default: false, null: false
      t.string :game_type, default: "Scavenger Hunt"
      t.integer :status, default: 0, null: false
      t.timestamps
    end
  end
end
```

Edit the hunt_prompts migration:
```ruby
class CreateHuntPrompts < ActiveRecord::Migration[8.1]
  def change
    create_table :hunt_prompts do |t|
      t.text :body, null: false
      t.integer :weight, default: 5, null: false
      t.integer :position, default: 0, null: false
      t.references :hunt_pack, null: false, foreign_key: true
      t.timestamps
    end
  end
end
```

- [ ] **Step 2: Run migrations**

```bash
bin/rails db:migrate
```

- [ ] **Step 3: Create HuntPack model**

```ruby
# app/models/hunt_pack.rb
class HuntPack < ApplicationRecord
  belongs_to :user, optional: true
  has_many :hunt_prompts, dependent: :destroy
  accepts_nested_attributes_for :hunt_prompts, allow_destroy: true, reject_if: :all_blank

  include SharedScopes

  scope :global, -> { where(user_id: nil) }
  scope :accessible_by, ->(user) { where(user_id: user&.id).or(global) }

  before_validation :set_default_name

  def self.default
    find_by(is_default: true) || global.first
  end

  enum :status, { draft: 0, live: 1 }

  private

  def set_default_name
    self.name = "Untitled Hunt Pack" if name.blank?
  end
end
```

- [ ] **Step 4: Create HuntPrompt model**

```ruby
# app/models/hunt_prompt.rb
class HuntPrompt < ApplicationRecord
  belongs_to :hunt_pack

  validates :body, presence: true
  validates :weight, presence: true, numericality: { greater_than: 0 }

  scope :ordered, -> { order(:position) }
end
```

- [ ] **Step 5: Create factories**

```ruby
# spec/factories/hunt_packs.rb
FactoryBot.define do
  factory :hunt_pack do
    name { "Test Hunt Pack" }
    game_type { "Scavenger Hunt" }
    status { :live }

    trait :global do
      user { nil }
    end

    trait :default do
      user { nil }
      is_default { true }
    end
  end
end
```

```ruby
# spec/factories/hunt_prompts.rb
FactoryBot.define do
  factory :hunt_prompt do
    hunt_pack
    body { "Take a photo reenacting a famous painting" }
    weight { 5 }
    sequence(:position) { |n| n }
  end
end
```

- [ ] **Step 6: Run rubocop and fix**

```bash
rubocop -A app/models/hunt_pack.rb app/models/hunt_prompt.rb spec/factories/hunt_packs.rb spec/factories/hunt_prompts.rb
```

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: add HuntPack and HuntPrompt models with factories"
```

### Task 2: Create ScavengerHuntGame model

**Files:**
- Create: `db/migrate/TIMESTAMP_create_scavenger_hunt_games.rb`
- Create: `app/models/scavenger_hunt_game.rb`
- Create: `spec/factories/scavenger_hunt_games.rb`
- Create: `spec/models/scavenger_hunt_game_spec.rb`

- [ ] **Step 1: Generate migration**

```bash
bin/rails generate migration CreateScavengerHuntGames status:string timer_duration:integer timer_enabled:boolean round_ends_at:datetime hunt_pack:references
```

Edit migration:
```ruby
class CreateScavengerHuntGames < ActiveRecord::Migration[8.1]
  def change
    create_table :scavenger_hunt_games do |t|
      t.string :status
      t.integer :timer_duration, default: 1800
      t.boolean :timer_enabled, default: true, null: false
      t.datetime :round_ends_at
      t.references :hunt_pack, null: true, foreign_key: true
      t.timestamps
    end
  end
end
```

- [ ] **Step 2: Run migration**

```bash
bin/rails db:migrate
```

- [ ] **Step 3: Create ScavengerHuntGame model**

```ruby
# app/models/scavenger_hunt_game.rb
class ScavengerHuntGame < ApplicationRecord
  include AASM
  include HasRoundTimer

  has_one :room, as: :current_game
  belongs_to :hunt_pack, optional: true
  has_many :hunt_prompt_instances, dependent: :destroy

  aasm column: :status, whiny_transitions: false do
    state :instructions, initial: true
    state :hunting
    state :submissions_locked
    state :revealing
    state :awarding
    state :finished

    event :start_hunt do
      transitions from: :instructions, to: :hunting
    end

    event :lock_submissions do
      transitions from: :hunting, to: :submissions_locked
    end

    event :start_reveal do
      transitions from: %i[hunting submissions_locked], to: :revealing
    end

    event :start_awards do
      transitions from: :revealing, to: :awarding
    end

    event :finish_game do
      transitions from: :awarding, to: :finished
    end
  end

  def round
    0 # Single-round game, but needed for HasRoundTimer compatibility
  end

  def process_timeout(round_number, _step_number)
    return unless round_number == round
    return unless hunting?
    Games::ScavengerHunt.handle_timeout(game: self)
  end

  def self.supports_response_moderation?
    false
  end

  def accepts_submissions?
    hunting? || submissions_locked?
  end

  def total_prompts
    hunt_prompt_instances.count
  end

  def completed_submissions_count
    HuntSubmission.joins(:hunt_prompt_instance)
                  .where(hunt_prompt_instances: { scavenger_hunt_game_id: id })
                  .where(completed: true)
                  .count
  end
end
```

- [ ] **Step 4: Write model spec**

```ruby
# spec/models/scavenger_hunt_game_spec.rb
require "rails_helper"

RSpec.describe ScavengerHuntGame, type: :model do
  describe "AASM states" do
    subject(:game) { described_class.new(status: "instructions") }

    it "starts in instructions state" do
      expect(game).to be_instructions
    end

    it "transitions instructions -> hunting" do
      game.start_hunt!
      expect(game).to be_hunting
    end

    it "transitions hunting -> submissions_locked" do
      game.status = "hunting"
      game.lock_submissions!
      expect(game).to be_submissions_locked
    end

    it "transitions hunting -> revealing (skip lock)" do
      game.status = "hunting"
      game.start_reveal!
      expect(game).to be_revealing
    end

    it "transitions submissions_locked -> revealing" do
      game.status = "submissions_locked"
      game.start_reveal!
      expect(game).to be_revealing
    end

    it "transitions revealing -> awarding" do
      game.status = "revealing"
      game.start_awards!
      expect(game).to be_awarding
    end

    it "transitions awarding -> finished" do
      game.status = "awarding"
      game.finish_game!
      expect(game).to be_finished
    end
  end

  describe "#accepts_submissions?" do
    it "returns true when hunting" do
      game = described_class.new(status: "hunting")
      expect(game.accepts_submissions?).to be true
    end

    it "returns true when submissions_locked" do
      game = described_class.new(status: "submissions_locked")
      expect(game.accepts_submissions?).to be true
    end

    it "returns false when revealing" do
      game = described_class.new(status: "revealing")
      expect(game.accepts_submissions?).to be false
    end
  end
end
```

- [ ] **Step 5: Create factory**

```ruby
# spec/factories/scavenger_hunt_games.rb
FactoryBot.define do
  factory :scavenger_hunt_game do
    status { "instructions" }
    timer_duration { 1800 }
    timer_enabled { true }
  end
end
```

- [ ] **Step 6: Run tests**

```bash
bin/rspec spec/models/scavenger_hunt_game_spec.rb
```

- [ ] **Step 7: Rubocop and commit**

```bash
rubocop -A app/models/scavenger_hunt_game.rb spec/models/scavenger_hunt_game_spec.rb spec/factories/scavenger_hunt_games.rb
git add -A && git commit -m "feat: add ScavengerHuntGame model with AASM states and specs"
```

### Task 3: Create HuntPromptInstance and HuntSubmission models

**Files:**
- Create: `db/migrate/TIMESTAMP_create_hunt_prompt_instances.rb`
- Create: `db/migrate/TIMESTAMP_create_hunt_submissions.rb`
- Create: `app/models/hunt_prompt_instance.rb`
- Create: `app/models/hunt_submission.rb`
- Create: `spec/factories/hunt_prompt_instances.rb`
- Create: `spec/factories/hunt_submissions.rb`
- Create: `spec/models/hunt_submission_spec.rb`

- [ ] **Step 1: Generate migrations**

```bash
bin/rails generate migration CreateHuntPromptInstances scavenger_hunt_game:references hunt_prompt:references position:integer winner_submission_id:integer
bin/rails generate migration CreateHuntSubmissions hunt_prompt_instance:references player:references late:boolean completed:boolean favorite:boolean host_notes:text
```

Edit hunt_prompt_instances migration:
```ruby
class CreateHuntPromptInstances < ActiveRecord::Migration[8.1]
  def change
    create_table :hunt_prompt_instances do |t|
      t.references :scavenger_hunt_game, null: false, foreign_key: true
      t.references :hunt_prompt, null: false, foreign_key: true
      t.integer :position, default: 0, null: false
      t.integer :winner_submission_id, null: true
      t.timestamps
    end
  end
end
```

Edit hunt_submissions migration:
```ruby
class CreateHuntSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :hunt_submissions do |t|
      t.references :hunt_prompt_instance, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.boolean :late, default: false, null: false
      t.boolean :completed, default: false, null: false
      t.boolean :favorite, default: false, null: false
      t.text :host_notes
      t.timestamps
    end

    add_index :hunt_submissions, %i[hunt_prompt_instance_id player_id], unique: true, name: "idx_hunt_submissions_prompt_player"
  end
end
```

- [ ] **Step 2: Run migrations**

```bash
bin/rails db:migrate
```

- [ ] **Step 3: Create models**

```ruby
# app/models/hunt_prompt_instance.rb
class HuntPromptInstance < ApplicationRecord
  belongs_to :scavenger_hunt_game
  belongs_to :hunt_prompt
  has_many :hunt_submissions, dependent: :destroy
  belongs_to :winner_submission, class_name: "HuntSubmission", optional: true

  scope :ordered, -> { order(:position) }

  delegate :body, :weight, to: :hunt_prompt
end
```

```ruby
# app/models/hunt_submission.rb
class HuntSubmission < ApplicationRecord
  belongs_to :hunt_prompt_instance
  belongs_to :player
  has_one_attached :media

  validates :player_id, uniqueness: { scope: :hunt_prompt_instance_id, message: "has already submitted for this prompt" }

  scope :completed, -> { where(completed: true) }
  scope :favorites, -> { where(favorite: true) }
  scope :on_time, -> { where(late: false) }

  delegate :body, :weight, to: :hunt_prompt_instance
end
```

- [ ] **Step 4: Create factories**

```ruby
# spec/factories/hunt_prompt_instances.rb
FactoryBot.define do
  factory :hunt_prompt_instance do
    scavenger_hunt_game
    hunt_prompt
    sequence(:position) { |n| n }
  end
end
```

```ruby
# spec/factories/hunt_submissions.rb
FactoryBot.define do
  factory :hunt_submission do
    hunt_prompt_instance
    player
    late { false }
    completed { false }
    favorite { false }
  end
end
```

- [ ] **Step 5: Write submission spec**

```ruby
# spec/models/hunt_submission_spec.rb
require "rails_helper"

RSpec.describe HuntSubmission, type: :model do
  describe "validations" do
    it "prevents duplicate submissions for same prompt and player" do
      instance = create(:hunt_prompt_instance)
      player = create(:player)
      create(:hunt_submission, hunt_prompt_instance: instance, player: player)

      duplicate = build(:hunt_submission, hunt_prompt_instance: instance, player: player)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:player_id]).to include("has already submitted for this prompt")
    end
  end
end
```

- [ ] **Step 6: Run tests**

```bash
bin/rspec spec/models/hunt_submission_spec.rb
```

- [ ] **Step 7: Rubocop and commit**

```bash
rubocop -A app/models/hunt_prompt_instance.rb app/models/hunt_submission.rb spec/models/hunt_submission_spec.rb spec/factories/hunt_prompt_instances.rb spec/factories/hunt_submissions.rb
git add -A && git commit -m "feat: add HuntPromptInstance and HuntSubmission models"
```

### Task 4: Add team_name to Player, hunt_pack to Room, register game type

**Files:**
- Create: `db/migrate/TIMESTAMP_add_team_name_to_players.rb`
- Create: `db/migrate/TIMESTAMP_add_hunt_pack_to_rooms.rb`
- Modify: `app/models/room.rb`
- Modify: `app/models/player.rb`
- Modify: `app/controllers/players_controller.rb`
- Modify: `app/views/players/new.html.erb`
- Modify: `config/initializers/game_registry.rb`

- [ ] **Step 1: Generate migrations**

```bash
bin/rails generate migration AddTeamNameToPlayers team_name:string
bin/rails generate migration AddHuntPackToRooms hunt_pack:references
```

Edit the rooms migration to allow null:
```ruby
class AddHuntPackToRooms < ActiveRecord::Migration[8.1]
  def change
    add_reference :rooms, :hunt_pack, null: true, foreign_key: true
  end
end
```

- [ ] **Step 2: Run migrations**

```bash
bin/rails db:migrate
```

- [ ] **Step 3: Update Room model**

Add to `app/models/room.rb`:
- Add `SCAVENGER_HUNT = "Scavenger Hunt".freeze` constant
- Add `"Scavenger Hunt"` to `GAME_TYPES` array
- Add `SCAVENGER_HUNT => "Photo Scavenger Hunt"` to `GAME_DISPLAY_NAMES`
- Add `belongs_to :hunt_pack, optional: true`

- [ ] **Step 4: Update Player strong params**

In `app/controllers/players_controller.rb`, update `player_params`:
```ruby
def player_params
  params.require(:player).permit(:name, :team_name)
end
```

- [ ] **Step 5: Add conditional team_name field to join form**

In `app/views/players/new.html.erb`, add after the name field div and before the submit button:

```erb
<% if @room.game_type == "Scavenger Hunt" %>
  <div>
    <%= form.label :team_name, "Team name", class: "block text-blue-200 font-bold text-xs tracking-widest mb-3" %>
    <%= form.text_field :team_name, class: "w-full px-4 py-4 bg-white/20 border-2 border-white/10 rounded-xl text-white placeholder-white/30 focus:outline-none focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20 transition-all text-lg", placeholder: "Enter your team name" %>
  </div>
<% end %>
```

- [ ] **Step 6: Register game type**

In `config/initializers/game_registry.rb`, add:
```ruby
GameEventRouter.register_game("Scavenger Hunt", Games::ScavengerHunt)
DevPlaytest::Registry.register(ScavengerHuntGame, Games::ScavengerHunt::Playtest)
```

Note: The service module doesn't exist yet — this registration will be loaded lazily via `to_prepare`, so it won't error until the game is actually used. We'll create the service in Chunk 2.

- [ ] **Step 7: Rubocop and commit**

```bash
rubocop -A app/models/room.rb app/controllers/players_controller.rb app/views/players/new.html.erb config/initializers/game_registry.rb
git add -A && git commit -m "feat: register Scavenger Hunt game type, add team_name to Player"
```

---

## Chunk 2: Game Service — Core Logic

This chunk implements the game service module with all state transitions, timer handling, submission logic, and scoring. After this chunk, the game can be started and played via the service layer (no UI yet).

### Task 5: Create the game service module (game_started + start_from_instructions)

**Files:**
- Create: `app/services/games/scavenger_hunt.rb`

- [ ] **Step 1: Create service module with required contract methods**

```ruby
# app/services/games/scavenger_hunt.rb
module Games
  module ScavengerHunt
    DEFAULT_TIMER_DURATION = 1800 # 30 minutes

    def self.requires_capacity_check? = false

    def self.game_started(room:, timer_enabled: true, timer_increment: nil, show_instructions: true, timer_duration: DEFAULT_TIMER_DURATION, **_extra)
      return if room.current_game.present?

      pack = room.hunt_pack || HuntPack.default
      return unless pack
      return if pack.hunt_prompts.empty?

      duration_seconds = timer_duration.to_i * 60 # Form sends minutes, store seconds

      game = ScavengerHuntGame.create!(
        timer_duration: duration_seconds,
        timer_enabled: timer_enabled == "1" || timer_enabled == true,
        hunt_pack: pack
      )

      # Create prompt instances from pack
      pack.hunt_prompts.each_with_index do |prompt, index|
        game.hunt_prompt_instances.create!(
          hunt_prompt: prompt,
          position: index
        )
      end

      room.update!(current_game: game)
      GameBroadcaster.broadcast_game_start(room: room)

      if show_instructions
        broadcast_all(game)
      else
        start_from_instructions(game: game)
      end
    end

    def self.start_from_instructions(game:)
      game.with_lock do
        return unless game.instructions?
        game.start_hunt!
      end

      start_timer_if_enabled(game)
      broadcast_all(game)
    end

    def self.handle_timeout(game:)
      game.with_lock do
        return unless game.hunting?
        game.lock_submissions!
      end

      broadcast_all(game)
    end

    def self.submit_photo(game:, player:, prompt_instance:, media:)
      return unless game.accepts_submissions?

      submission = prompt_instance.hunt_submissions.find_or_initialize_by(player: player)
      submission.late = game.submissions_locked?
      submission.media.attach(media)
      submission.save!

      broadcast_all(game)
      submission
    rescue ActiveRecord::RecordNotUnique
      # Concurrent duplicate — reload and retry
      submission = prompt_instance.hunt_submissions.find_by!(player: player)
      submission.media.attach(media)
      submission.save!
      broadcast_all(game)
      submission
    end

    def self.lock_submissions_manually(game:)
      game.with_lock do
        return unless game.hunting?
        game.lock_submissions!
      end

      broadcast_all(game)
    end

    def self.start_reveal(game:)
      game.with_lock do
        return unless game.hunting? || game.submissions_locked?
        game.start_reveal!
      end

      broadcast_all(game)
    end

    def self.show_submission_on_stage(game:, submission:)
      return unless game.revealing?

      # Store which submission is currently shown for stage rendering
      game.update!(currently_showing_submission_id: submission.id)
      broadcast_all(game)
    end

    def self.start_awards(game:)
      game.with_lock do
        return unless game.revealing?
        game.start_awards!
      end

      broadcast_all(game)
    end

    def self.pick_winner(game:, prompt_instance:, submission:)
      return unless game.awarding?

      prompt_instance.update!(winner_submission: submission)
      broadcast_all(game)
    end

    def self.finish_game(game:)
      game.with_lock do
        return unless game.awarding?
        calculate_scores(game)
        game.finish_game!
      end

      game.room.finish!
      broadcast_all(game)
    end

    def self.mark_completed(game:, submission:, completed:)
      submission.update!(completed: completed)
      broadcast_all(game)
    end

    def self.mark_favorite(game:, submission:, favorite:)
      submission.update!(favorite: favorite)
      broadcast_all(game)
    end

    def self.update_host_notes(game:, submission:, notes:)
      submission.update!(host_notes: notes)
      broadcast_all(game)
    end

    # --- Private ---

    def self.start_timer_if_enabled(game)
      return unless game.timer_enabled?
      game.start_timer!(game.timer_duration)
    end

    def self.calculate_scores(game)
      game.hunt_prompt_instances.includes(:hunt_submissions, :winner_submission, :hunt_prompt).find_each do |instance|
        weight = instance.weight

        # Completion points
        instance.hunt_submissions.completed.each do |sub|
          sub.player.increment!(:score, weight)
        end

        # Winner bonus
        if instance.winner_submission
          instance.winner_submission.player.increment!(:score, weight)
        end
      end
    end

    def self.broadcast_all(game)
      room = game.room
      GameBroadcaster.broadcast_stage(room:, game:)
      GameBroadcaster.broadcast_hand(room:)
      GameBroadcaster.broadcast_host_controls(room:)
    end

    private_class_method :start_timer_if_enabled, :calculate_scores, :broadcast_all
  end
end
```

- [ ] **Step 2: Add currently_showing_submission_id to game model**

```bash
bin/rails generate migration AddCurrentlyShowingSubmissionToScavengerHuntGames currently_showing_submission_id:integer
bin/rails db:migrate
```

- [ ] **Step 3: Rubocop**

```bash
rubocop -A app/services/games/scavenger_hunt.rb
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add ScavengerHunt game service with core logic"
```

### Task 6: Write service specs

**Files:**
- Create: `spec/services/games/scavenger_hunt_spec.rb`

- [ ] **Step 1: Write service specs**

```ruby
# spec/services/games/scavenger_hunt_spec.rb
require "rails_helper"

RSpec.describe Games::ScavengerHunt do
  let!(:hunt_pack) { create(:hunt_pack, :default) }
  let!(:prompts) do
    3.times.map { |i| create(:hunt_prompt, hunt_pack: hunt_pack, body: "Prompt #{i + 1}", position: i) }
  end
  let!(:room) { create(:room, game_type: "Scavenger Hunt") }
  let!(:host) { create(:player, room: room, name: "Host", team_name: "Team Alpha") }
  let!(:player2) { create(:player, room: room, name: "Alice", team_name: "Team Beta") }

  describe ".game_started" do
    it "creates a game with prompt instances" do
      described_class.game_started(room: room, timer_enabled: true, timer_duration: 1800, show_instructions: true)
      game = room.reload.current_game

      expect(game).to be_a(ScavengerHuntGame)
      expect(game).to be_instructions
      expect(game.hunt_prompt_instances.count).to eq(3)
    end
  end

  describe ".start_from_instructions" do
    let!(:game) { start_game }

    it "transitions to hunting" do
      described_class.start_from_instructions(game: game)
      expect(game.reload).to be_hunting
    end
  end

  describe ".submit_photo" do
    let!(:game) { start_and_begin_hunt }

    it "creates a submission for a prompt" do
      instance = game.hunt_prompt_instances.first
      media = fixture_file_upload("spec/fixtures/files/test_photo.jpg", "image/jpeg")

      submission = described_class.submit_photo(game: game, player: host, prompt_instance: instance, media: media)

      expect(submission).to be_persisted
      expect(submission.media).to be_attached
      expect(submission.late).to be false
    end

    it "flags late submissions when locked" do
      described_class.lock_submissions_manually(game: game)
      instance = game.hunt_prompt_instances.first
      media = fixture_file_upload("spec/fixtures/files/test_photo.jpg", "image/jpeg")

      submission = described_class.submit_photo(game: game, player: host, prompt_instance: instance, media: media)

      expect(submission.late).to be true
    end

    it "replaces existing submission for same prompt and player" do
      instance = game.hunt_prompt_instances.first
      media1 = fixture_file_upload("spec/fixtures/files/test_photo.jpg", "image/jpeg")
      media2 = fixture_file_upload("spec/fixtures/files/test_photo.jpg", "image/jpeg")

      described_class.submit_photo(game: game, player: host, prompt_instance: instance, media: media1)
      described_class.submit_photo(game: game, player: host, prompt_instance: instance, media: media2)

      expect(instance.hunt_submissions.where(player: host).count).to eq(1)
    end
  end

  describe ".handle_timeout" do
    it "locks submissions when timer expires" do
      game = start_and_begin_hunt
      described_class.handle_timeout(game: game)
      expect(game.reload).to be_submissions_locked
    end
  end

  describe ".finish_game" do
    it "calculates scores based on completions and winners" do
      game = start_and_begin_hunt
      instance = game.hunt_prompt_instances.first

      # Create submissions
      sub_host = create(:hunt_submission, hunt_prompt_instance: instance, player: host, completed: true)
      create(:hunt_submission, hunt_prompt_instance: instance, player: player2, completed: true)

      # Set winner
      instance.update!(winner_submission: sub_host)

      # Advance to awarding
      described_class.start_reveal(game: game)
      described_class.start_awards(game: game)
      described_class.finish_game(game: game)

      # Host: 5 (completion) + 5 (winner) = 10
      expect(host.reload.score).to eq(10)
      # Player2: 5 (completion)
      expect(player2.reload.score).to eq(5)
    end
  end

  # Helper methods
  def start_game
    described_class.game_started(room: room, timer_enabled: false, timer_duration: 1800, show_instructions: true)
    room.reload.current_game
  end

  def start_and_begin_hunt
    game = start_game
    described_class.start_from_instructions(game: game)
    game.reload
  end
end
```

- [ ] **Step 2: Create test fixture image**

```bash
mkdir -p spec/fixtures/files
# Create a minimal valid JPEG (1x1 pixel)
convert -size 1x1 xc:red spec/fixtures/files/test_photo.jpg 2>/dev/null || \
  printf '\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.\x27 ",#\x1c\x1c(7),01444\x1f\x27444444444444\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\xff\xc4\x00\xb5\x10\x00\x02\x01\x03\x03\x02\x04\x03\x05\x05\x04\x04\x00\x00\x01}\x01\x02\x03\x00\x04\x11\x05\x12!1A\x06\x13Qa\x07"q\x142\x81\x91\xa1\x08#B\xb1\xc1\x15R\xd1\xf0$3br\x82\t\n\x16\x17\x18\x19\x1a%&\x27()*456789:CDEFGHIJSTUVWXYZcdefghijstuvwxyz\x83\x84\x85\x86\x87\x88\x89\x8a\x92\x93\x94\x95\x96\x97\x98\x99\x9a\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xff\xda\x00\x08\x01\x01\x00\x00?\x00\xfb\xd2\x8a(\x03\xff\xd9' > spec/fixtures/files/test_photo.jpg
```

- [ ] **Step 3: Run tests**

```bash
bin/rspec spec/services/games/scavenger_hunt_spec.rb
```

- [ ] **Step 4: Rubocop and commit**

```bash
rubocop -A spec/services/games/scavenger_hunt_spec.rb
git add -A && git commit -m "test: add ScavengerHunt service specs"
```

### Task 7: Add Playtest module

**Files:**
- Modify: `app/services/games/scavenger_hunt.rb` — add nested Playtest module

- [ ] **Step 1: Add Playtest module inside the service**

Add at the bottom of `app/services/games/scavenger_hunt.rb`, before the final `end`s:

```ruby
module Playtest
  def self.start(room:)
    Games::ScavengerHunt.game_started(room: room, timer_enabled: false, show_instructions: true)
  end

  def self.advance(game:)
    case game.status
    when "instructions"
      Games::ScavengerHunt.start_from_instructions(game: game)
    when "hunting"
      Games::ScavengerHunt.lock_submissions_manually(game: game)
    when "submissions_locked"
      Games::ScavengerHunt.start_reveal(game: game)
    when "revealing"
      Games::ScavengerHunt.start_awards(game: game)
    when "awarding"
      Games::ScavengerHunt.finish_game(game: game)
    end
  end

  def self.bot_act(game:, exclude_player:)
    return unless game.hunting? || game.submissions_locked?

    players = game.room.players.active_players.where.not(id: exclude_player&.id)
    fixture_path = Rails.root.join("spec/fixtures/files/test_photo.jpg")

    players.each do |player|
      game.hunt_prompt_instances.each do |instance|
        next if instance.hunt_submissions.exists?(player: player)
        next if rand > 0.6 # Bots don't submit everything

        submission = instance.hunt_submissions.find_or_initialize_by(player: player)
        submission.late = game.submissions_locked?
        submission.media.attach(
          io: File.open(fixture_path),
          filename: "bot_photo_#{player.id}_#{instance.id}.jpg",
          content_type: "image/jpeg"
        )
        submission.save!
      end
    end

    Games::ScavengerHunt.send(:broadcast_all, game)
  end

  def self.auto_play_step(game:)
    case game.status
    when "instructions"
      Games::ScavengerHunt.start_from_instructions(game: game)
    when "hunting"
      bot_act(game: game, exclude_player: nil)
      # Mark all submissions as completed
      HuntSubmission.joins(:hunt_prompt_instance)
                    .where(hunt_prompt_instances: { scavenger_hunt_game_id: game.id })
                    .update_all(completed: true)
      Games::ScavengerHunt.lock_submissions_manually(game: game)
    when "submissions_locked"
      Games::ScavengerHunt.start_reveal(game: game)
    when "revealing"
      Games::ScavengerHunt.start_awards(game: game)
    when "awarding"
      # Auto-pick winners (first completed submission per prompt)
      game.hunt_prompt_instances.each do |instance|
        winner = instance.hunt_submissions.completed.first
        instance.update!(winner_submission: winner) if winner
      end
      Games::ScavengerHunt.finish_game(game: game)
    end
  end

  def self.progress_label(game:)
    submitted = HuntSubmission.joins(:hunt_prompt_instance)
                              .where(hunt_prompt_instances: { scavenger_hunt_game_id: game.id })
                              .count
    total = game.hunt_prompt_instances.count * game.room.players.active_players.count
    "#{submitted}/#{total} submissions"
  end

  def self.dashboard_actions(status)
    case status
    when "lobby"
      [ { label: "Start Game", action: :start, style: :primary } ]
    when "instructions"
      [ { label: "Skip Instructions", action: :advance, style: :primary } ]
    when "hunting"
      [
        { label: "Bots: Submit Photos", action: :bot_act, style: :bot },
        { label: "Lock Submissions", action: :advance, style: :primary }
      ]
    when "submissions_locked"
      [ { label: "Start Presentation", action: :advance, style: :primary } ]
    when "revealing"
      [ { label: "Start Awards", action: :advance, style: :primary } ]
    when "awarding"
      [ { label: "Finish Game", action: :advance, style: :primary } ]
    else
      []
    end
  end
end
```

- [ ] **Step 2: Rubocop and commit**

```bash
rubocop -A app/services/games/scavenger_hunt.rb
git add -A && git commit -m "feat: add ScavengerHunt Playtest module"
```

---

## Chunk 3: Controllers & Routes

This chunk wires up the HTTP layer — controllers for all game actions and routes.

### Task 8: Add routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Add scavenger hunt game routes**

Add to `config/routes.rb` alongside existing game routes:

```ruby
resources :scavenger_hunt_games, only: [] do
  scope module: :scavenger_hunt do
    resource :game_start, only: :create
    resources :submissions, only: :create
    resource :submission_lock, only: :create
    resource :reveal, only: :create
    resources :awards, only: %i[create update]
    resource :finish, only: :create
    resources :completions, only: :update
  end
end

resources :hunt_packs do
  member do
    patch :duplicate
  end
end
```

- [ ] **Step 2: Rubocop and commit**

```bash
rubocop -A config/routes.rb
git add -A && git commit -m "feat: add scavenger hunt and hunt pack routes"
```

### Task 9: Create game action controllers

**Files:**
- Create: `app/controllers/scavenger_hunt/game_starts_controller.rb`
- Create: `app/controllers/scavenger_hunt/submissions_controller.rb`
- Create: `app/controllers/scavenger_hunt/submission_locks_controller.rb`
- Create: `app/controllers/scavenger_hunt/reveals_controller.rb`
- Create: `app/controllers/scavenger_hunt/awards_controller.rb`
- Create: `app/controllers/scavenger_hunt/completions_controller.rb`

- [ ] **Step 1: Create GameStartsController**

```ruby
# app/controllers/scavenger_hunt/game_starts_controller.rb
module ScavengerHunt
  class GameStartsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::ScavengerHunt.start_from_instructions(game: @game)
      render_hand
    end

    private

    def set_game
      @game = ScavengerHuntGame.find(params[:scavenger_hunt_game_id])
    end
  end
end
```

- [ ] **Step 2: Create SubmissionsController**

```ruby
# app/controllers/scavenger_hunt/submissions_controller.rb
module ScavengerHunt
  class SubmissionsController < ApplicationController
    include RendersHand

    before_action :set_game

    def create
      prompt_instance = @game.hunt_prompt_instances.find(params[:hunt_prompt_instance_id])

      unless current_player
        head :unauthorized
        return
      end

      unless @game.accepts_submissions?
        head :unprocessable_entity
        return
      end

      Games::ScavengerHunt.submit_photo(
        game: @game,
        player: current_player,
        prompt_instance: prompt_instance,
        media: params[:media]
      )

      render_hand
    end

    private

    def set_game
      @game = ScavengerHuntGame.find(params[:scavenger_hunt_game_id])
    end
  end
end
```

- [ ] **Step 3: Create SubmissionLocksController**

```ruby
# app/controllers/scavenger_hunt/submission_locks_controller.rb
module ScavengerHunt
  class SubmissionLocksController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::ScavengerHunt.lock_submissions_manually(game: @game)
      render_hand
    end

    private

    def set_game
      @game = ScavengerHuntGame.find(params[:scavenger_hunt_game_id])
    end
  end
end
```

- [ ] **Step 4: Create RevealsController**

```ruby
# app/controllers/scavenger_hunt/reveals_controller.rb
module ScavengerHunt
  class RevealsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      if params[:submission_id]
        # Show a specific submission on stage
        submission = HuntSubmission.find(params[:submission_id])
        Games::ScavengerHunt.show_submission_on_stage(game: @game, submission: submission)
      else
        # Start the reveal phase
        Games::ScavengerHunt.start_reveal(game: @game)
      end
      render_hand
    end

    private

    def set_game
      @game = ScavengerHuntGame.find(params[:scavenger_hunt_game_id])
    end
  end
end
```

- [ ] **Step 5: Create AwardsController**

```ruby
# app/controllers/scavenger_hunt/awards_controller.rb
module ScavengerHunt
  class AwardsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::ScavengerHunt.start_awards(game: @game)
      render_hand
    end

    def update
      prompt_instance = @game.hunt_prompt_instances.find(params[:id])
      submission = prompt_instance.hunt_submissions.find(params[:winner_submission_id])
      Games::ScavengerHunt.pick_winner(game: @game, prompt_instance: prompt_instance, submission: submission)
      render_hand
    end

    private

    def set_game
      @game = ScavengerHuntGame.find(params[:scavenger_hunt_game_id])
    end
  end
end
```

- [ ] **Step 5b: Create FinishesController**

```ruby
# app/controllers/scavenger_hunt/finishes_controller.rb
module ScavengerHunt
  class FinishesController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::ScavengerHunt.finish_game(game: @game)
      render_hand
    end

    private

    def set_game
      @game = ScavengerHuntGame.find(params[:scavenger_hunt_game_id])
    end
  end
end
```

- [ ] **Step 6: Create CompletionsController**

```ruby
# app/controllers/scavenger_hunt/completions_controller.rb
module ScavengerHunt
  class CompletionsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def update
      submission = HuntSubmission.find(params[:id])

      case params[:action_type]
      when "complete"
        Games::ScavengerHunt.mark_completed(game: @game, submission: submission, completed: params[:value] == "true")
      when "favorite"
        Games::ScavengerHunt.mark_favorite(game: @game, submission: submission, favorite: params[:value] == "true")
      when "notes"
        Games::ScavengerHunt.update_host_notes(game: @game, submission: submission, notes: params[:notes])
      end

      render_hand
    end

    private

    def set_game
      @game = ScavengerHuntGame.find(params[:scavenger_hunt_game_id])
    end
  end
end
```

- [ ] **Step 7: Rubocop and commit**

```bash
rubocop -A app/controllers/scavenger_hunt/
git add -A && git commit -m "feat: add scavenger hunt game controllers"
```

---

## Chunk 4: Views — Stage Partials

All stage views. These are the projected screen that everyone in the room sees. Must use vh units, never scroll.

### Task 10: Create stage partials for all states

**Files:**
- Create: `app/views/games/scavenger_hunt/_stage_instructions.html.erb`
- Create: `app/views/games/scavenger_hunt/_stage_hunting.html.erb`
- Create: `app/views/games/scavenger_hunt/_stage_submissions_locked.html.erb`
- Create: `app/views/games/scavenger_hunt/_stage_revealing.html.erb`
- Create: `app/views/games/scavenger_hunt/_stage_awarding.html.erb`
- Create: `app/views/games/scavenger_hunt/_stage_finished.html.erb`

- [ ] **Step 1: Create stage_instructions**

```erb
<%# app/views/games/scavenger_hunt/_stage_instructions.html.erb %>
<div id="stage_instructions" class="flex flex-col items-center justify-center flex-1 animate-fade-in">
  <div class="text-center">
    <p class="text-[10vh] mb-[2vh]">📸</p>
    <h1 class="text-vh-5xl font-black text-white mb-[2vh]">Photo Scavenger Hunt</h1>
    <p class="text-vh-2xl text-white/70">Waiting for the host to start the hunt...</p>
    <div class="mt-[4vh] bg-white/10 backdrop-blur-md rounded-2xl p-[3vh] border border-white/20">
      <p class="text-vh-xl text-white/80"><%= game.hunt_prompt_instances.count %> prompts to complete</p>
      <p class="text-vh-lg text-white/50 mt-[1vh]"><%= game.room.players.active_players.count %> teams ready</p>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Create stage_hunting**

```erb
<%# app/views/games/scavenger_hunt/_stage_hunting.html.erb %>
<div id="stage_hunting" class="flex flex-col items-center justify-center flex-1 animate-fade-in">
  <div class="text-center">
    <p class="text-[8vh] mb-[2vh]">🏃</p>
    <h1 class="text-vh-4xl font-black text-white mb-[3vh]">The Hunt Is On!</h1>

    <% if game.timer_enabled? && game.round_ends_at %>
      <div class="bg-white/10 backdrop-blur-md rounded-2xl p-[3vh] border border-white/20 mb-[3vh]"
           data-controller="timer"
           data-timer-end-value="<%= game.timer_expires_at_iso8601 %>">
        <p class="text-vh-xs text-white/50 font-bold tracking-widest mb-[1vh]">TIME REMAINING</p>
        <p class="text-vh-5xl font-black text-white font-mono" data-timer-target="output">
          <%= (game.time_remaining / 60).floor %>:<%= "%02d" % (game.time_remaining % 60).floor %>
        </p>
      </div>
    <% end %>

    <% submitted = HuntSubmission.joins(:hunt_prompt_instance).where(hunt_prompt_instances: { scavenger_hunt_game_id: game.id }).count %>
    <% total = game.hunt_prompt_instances.count * game.room.players.active_players.count %>
    <div class="bg-white/10 backdrop-blur-md rounded-2xl p-[3vh] border border-white/20">
      <p class="text-vh-xs text-white/50 font-bold tracking-widest mb-[1vh]">SUBMISSIONS</p>
      <p class="text-vh-3xl font-bold text-white"><%= submitted %> of <%= total %></p>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Create stage_submissions_locked**

```erb
<%# app/views/games/scavenger_hunt/_stage_submissions_locked.html.erb %>
<div id="stage_submissions_locked" class="flex flex-col items-center justify-center flex-1 animate-fade-in">
  <div class="text-center">
    <p class="text-[8vh] mb-[2vh]">🔒</p>
    <h1 class="text-vh-4xl font-black text-white mb-[2vh]">Time's Up!</h1>
    <p class="text-vh-2xl text-white/70 mb-[3vh]">Get back here — the show's about to start.</p>

    <% submitted = HuntSubmission.joins(:hunt_prompt_instance).where(hunt_prompt_instances: { scavenger_hunt_game_id: game.id }).count %>
    <div class="bg-white/10 backdrop-blur-md rounded-2xl p-[3vh] border border-white/20">
      <p class="text-vh-3xl font-bold text-white"><%= submitted %> photos submitted</p>
    </div>
  </div>
</div>
```

- [ ] **Step 4: Create stage_revealing**

```erb
<%# app/views/games/scavenger_hunt/_stage_revealing.html.erb %>
<div id="stage_revealing" class="flex flex-col items-center justify-center flex-1 animate-fade-in">
  <% submission = game.currently_showing_submission_id ? HuntSubmission.find_by(id: game.currently_showing_submission_id) : nil %>

  <% if submission&.media&.attached? %>
    <div class="flex flex-col items-center w-full h-full p-[2vh]">
      <div class="bg-black/40 rounded-xl p-[1.5vh] mb-[1vh] w-full text-center">
        <p class="text-vh-2xl font-bold text-white"><%= submission.hunt_prompt_instance.body %></p>
      </div>

      <div class="flex-1 flex items-center justify-center w-full">
        <%= image_tag rails_blob_path(submission.media.blob),
              class: "max-h-[65vh] max-w-full object-contain rounded-2xl",
              alt: "" %>
      </div>

      <div class="bg-black/40 rounded-xl p-[1.5vh] mt-[1vh] w-full text-center">
        <p class="text-vh-xl font-bold text-white"><%= submission.player.team_name || submission.player.name %></p>
      </div>
    </div>
  <% else %>
    <div class="text-center">
      <p class="text-[8vh] mb-[2vh]">🎬</p>
      <h1 class="text-vh-4xl font-black text-white">Let's see what you've got!</h1>
      <p class="text-vh-xl text-white/70 mt-[2vh]">The host is picking the first photo...</p>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: Create stage_awarding**

```erb
<%# app/views/games/scavenger_hunt/_stage_awarding.html.erb %>
<div id="stage_awarding" class="flex flex-col items-center justify-center flex-1 animate-fade-in">
  <div class="text-center mb-[3vh]">
    <p class="text-[6vh] mb-[1vh]">🏆</p>
    <h1 class="text-vh-4xl font-black text-white">Awards Time!</h1>
  </div>

  <div class="grid grid-cols-2 gap-[2vh] w-full max-w-[80vw]">
    <% game.hunt_prompt_instances.each do |instance| %>
      <div class="bg-white/10 backdrop-blur-md rounded-xl p-[2vh] border border-white/20">
        <p class="text-vh-sm text-white/60 mb-[0.5vh]"><%= instance.body %></p>
        <% if instance.winner_submission %>
          <p class="text-vh-lg font-bold text-yellow-300">
            🥇 <%= instance.winner_submission.player.team_name || instance.winner_submission.player.name %>
          </p>
        <% else %>
          <p class="text-vh-base text-white/40">Awaiting...</p>
        <% end %>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 6: Create stage_finished**

```erb
<%# app/views/games/scavenger_hunt/_stage_finished.html.erb %>
<div id="stage_finished" class="flex flex-col items-center justify-center flex-1 animate-fade-in">
  <div class="text-center mb-[3vh]">
    <p class="text-[6vh] mb-[1vh]">🎉</p>
    <h1 class="text-vh-4xl font-black text-white">Final Scores</h1>
  </div>

  <div class="w-full max-w-[60vw]">
    <% players_ranked = game.room.players.active_players.order(score: :desc) %>
    <% players_ranked.each_with_index do |player, index| %>
      <div class="flex items-center justify-between bg-white/10 backdrop-blur-md rounded-xl p-[2vh] mb-[1vh] border border-white/20 <%= 'ring-2 ring-yellow-400' if index == 0 %>">
        <div class="flex items-center gap-[2vh]">
          <span class="text-vh-2xl font-black text-white/60"><%= (index + 1).ordinalize %></span>
          <span class="text-vh-xl font-bold text-white"><%= player.team_name || player.name %></span>
        </div>
        <span class="text-vh-2xl font-black text-yellow-300"><%= player.score %> pts</span>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 7: Rubocop and commit**

```bash
rubocop -A app/views/games/scavenger_hunt/
git add -A && git commit -m "feat: add scavenger hunt stage partials for all states"
```

---

## Chunk 5: Views — Hand Partials & Host Controls

The player's phone experience and host control buttons.

### Task 11: Create hand partials

**Files:**
- Create: `app/views/games/scavenger_hunt/_hand.html.erb`
- Create: `app/views/games/scavenger_hunt/_prompt_list.html.erb`
- Create: `app/views/games/scavenger_hunt/_spectator.html.erb`
- Create: `app/views/games/scavenger_hunt/_game_over.html.erb`

- [ ] **Step 1: Create hand router partial**

```erb
<%# app/views/games/scavenger_hunt/_hand.html.erb %>
<% game = room.current_game %>

<% if game.instructions? %>
  <%= render "games/shared/hand_instructions",
      emoji: "📸",
      start_game_path: scavenger_hunt_game_game_start_path(game),
      room:, player: %>
<% elsif game.hunting? || game.submissions_locked? %>
  <%= render "games/scavenger_hunt/prompt_list", room:, player:, game: %>
<% elsif game.revealing? || game.awarding? %>
  <%= render "games/scavenger_hunt/spectator", room:, player:, game: %>
<% elsif game.finished? %>
  <%= render "games/scavenger_hunt/game_over", room:, player:, game: %>
<% end %>
```

- [ ] **Step 2: Create prompt list (photographer's main UI during hunting)**

```erb
<%# app/views/games/scavenger_hunt/_prompt_list.html.erb %>
<div class="space-y-3">
  <% if game.timer_enabled? && game.round_ends_at %>
    <div class="bg-white/10 backdrop-blur-md rounded-xl p-3 text-center border border-white/20"
         data-controller="timer"
         data-timer-end-value="<%= game.timer_expires_at_iso8601 %>">
      <p class="text-xs text-white/50 font-bold tracking-widest"><%= game.submissions_locked? ? "LATE SUBMISSIONS" : "TIME REMAINING" %></p>
      <p class="text-2xl font-black text-white font-mono" data-timer-target="output">
        <%= (game.time_remaining / 60).floor %>:<%= "%02d" % (game.time_remaining % 60).floor %>
      </p>
    </div>
  <% end %>

  <% if game.submissions_locked? %>
    <div class="bg-amber-500/20 border border-amber-500/40 rounded-xl p-3 text-center">
      <p class="text-amber-200 font-bold text-sm">Time's up! You can still submit — they'll be marked late.</p>
    </div>
  <% end %>

  <% game.hunt_prompt_instances.includes(:hunt_prompt, :hunt_submissions).each do |instance| %>
    <% submission = instance.hunt_submissions.find_by(player: player) %>
    <div class="bg-white/10 backdrop-blur-md rounded-xl p-4 border border-white/20">
      <div class="flex items-start justify-between gap-3">
        <div class="flex-1">
          <p class="text-white font-bold text-sm"><%= instance.body %></p>
          <p class="text-white/40 text-xs mt-1"><%= instance.weight %> pts</p>
        </div>
        <div class="shrink-0">
          <% if submission&.media&.attached? %>
            <span class="text-green-400 text-lg">✓</span>
            <% if submission.late? %>
              <span class="text-amber-400 text-xs block">late</span>
            <% end %>
          <% end %>
        </div>
      </div>

      <div class="mt-3">
        <%= form_with url: scavenger_hunt_game_submissions_path(game),
              method: :post,
              data: { controller: "games--image-upload", turbo_frame: "hand_screen" } do |f| %>
          <%= hidden_field_tag :hunt_prompt_instance_id, instance.id %>
          <%= hidden_field_tag :code, room.code %>
          <label class="block w-full text-center bg-white/20 hover:bg-white/30 text-white font-bold py-3 px-4 rounded-xl cursor-pointer transition-all text-sm">
            <span data-games--image-upload-target="label"><%= submission&.media&.attached? ? "Replace Photo" : "Take / Upload Photo" %></span>
            <input type="file"
                   name="media"
                   accept="image/*"
                   class="hidden"
                   data-games--image-upload-target="input"
                   data-action="change->games--image-upload#compress">
          </label>
          <div data-games--image-upload-target="progress" class="hidden mt-2">
            <div class="bg-white/20 rounded-full h-2">
              <div data-games--image-upload-target="bar" class="bg-green-400 h-2 rounded-full transition-all" style="width: 0%"></div>
            </div>
            <p data-games--image-upload-target="status" class="text-white/60 text-xs text-center mt-1">Uploading...</p>
          </div>
        <% end %>
      </div>

      <% if submission&.media&.attached? %>
        <div class="mt-2">
          <%= image_tag rails_blob_path(submission.media.blob),
                class: "w-full h-24 object-cover rounded-lg",
                alt: "" %>
        </div>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 3: Create spectator view**

```erb
<%# app/views/games/scavenger_hunt/_spectator.html.erb %>
<div class="flex flex-col items-center justify-center min-h-[60vh] text-center">
  <p class="text-5xl mb-4">🎬</p>
  <h2 class="text-2xl font-black text-white mb-2">
    <%= game.awarding? ? "Awards Time!" : "The host is presenting!" %>
  </h2>
  <p class="text-white/60">Watch the big screen</p>
</div>
```

- [ ] **Step 4: Create game over**

```erb
<%# app/views/games/scavenger_hunt/_game_over.html.erb %>
<div class="text-center py-6">
  <p class="text-5xl mb-4">🎉</p>
  <h2 class="text-2xl font-black text-white mb-4">Game Over!</h2>

  <% players_ranked = room.players.active_players.order(score: :desc) %>
  <div class="space-y-2">
    <% players_ranked.each_with_index do |p, index| %>
      <div class="flex items-center justify-between bg-white/10 rounded-xl p-3 border border-white/20 <%= 'ring-2 ring-yellow-400' if index == 0 %>">
        <span class="text-white font-bold"><%= (index + 1).ordinalize %> — <%= p.team_name || p.name %></span>
        <span class="text-yellow-300 font-black"><%= p.score %> pts</span>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 5: Rubocop and commit**

```bash
rubocop -A app/views/games/scavenger_hunt/
git add -A && git commit -m "feat: add scavenger hunt hand partials"
```

### Task 12: Create host controls partial

**Files:**
- Create: `app/views/games/scavenger_hunt/_host_controls.html.erb`

- [ ] **Step 1: Create host controls**

```erb
<%# app/views/games/scavenger_hunt/_host_controls.html.erb %>
<% game = room.current_game %>

<% if game.instructions? %>
  <p class="text-white/60 text-sm mb-3">Waiting for players to join...</p>

<% elsif game.hunting? %>
  <% submitted = HuntSubmission.joins(:hunt_prompt_instance).where(hunt_prompt_instances: { scavenger_hunt_game_id: game.id }).count %>
  <% total = game.hunt_prompt_instances.count * room.players.active_players.count %>
  <p class="text-white/60 text-sm mb-3">Submissions: <%= submitted %>/<%= total %></p>

  <% if game.timer_enabled? && game.round_ends_at %>
    <div data-controller="timer" data-timer-end-value="<%= game.timer_expires_at_iso8601 %>" class="mb-3">
      <p class="text-white font-mono text-lg" data-timer-target="output"><%= (game.time_remaining / 60).floor %>:<%= "%02d" % (game.time_remaining % 60).floor %></p>
    </div>
  <% end %>

  <%= button_to "Lock Submissions",
      scavenger_hunt_game_submission_lock_path(game),
      method: :post,
      params: { code: room.code },
      class: "w-full bg-amber-600 text-white font-bold py-3 px-4 rounded-xl mb-2" %>
  <%= button_to "Start Presentation",
      scavenger_hunt_game_reveal_path(game),
      method: :post,
      params: { code: room.code },
      data: { turbo_confirm: game.hunting? ? "Start presentation? This will cut off submissions." : nil },
      class: "w-full bg-gradient-to-r from-green-600 to-emerald-600 text-white font-bold py-3 px-4 rounded-xl" %>

<% elsif game.submissions_locked? %>
  <p class="text-white/60 text-sm mb-3">Submissions locked. Late entries still rolling in.</p>
  <%= button_to "Start Presentation",
      scavenger_hunt_game_reveal_path(game),
      method: :post,
      params: { code: room.code },
      class: "w-full bg-gradient-to-r from-green-600 to-emerald-600 text-white font-bold py-3 px-4 rounded-xl" %>

<% elsif game.revealing? %>
  <%= render "games/scavenger_hunt/card_picker", game:, room: %>
  <%= button_to "Start Awards",
      scavenger_hunt_game_awards_path(game),
      method: :post,
      params: { code: room.code },
      class: "w-full bg-gradient-to-r from-yellow-600 to-amber-600 text-white font-bold py-3 px-4 rounded-xl mt-3" %>

<% elsif game.awarding? %>
  <p class="text-white/60 text-sm mb-3">Pick the best submission for each prompt:</p>
  <% game.hunt_prompt_instances.includes(:hunt_submissions, :winner_submission, hunt_submissions: :player).each do |instance| %>
    <div class="bg-white/5 rounded-xl p-3 mb-2 border border-white/10">
      <p class="text-white font-bold text-sm mb-2"><%= instance.body %></p>
      <% instance.hunt_submissions.completed.each do |sub| %>
        <%= button_to (sub.player.team_name || sub.player.name),
            scavenger_hunt_game_award_path(game, instance),
            method: :patch,
            params: { winner_submission_id: sub.id, code: room.code },
            class: "inline-block px-3 py-1 rounded-lg text-sm font-bold mr-1 mb-1 #{instance.winner_submission == sub ? 'bg-yellow-500 text-black' : 'bg-white/20 text-white'}" %>
      <% end %>
    </div>
  <% end %>
  <%= button_to "Finish Game",
      scavenger_hunt_game_finish_path(game),
      method: :post,
      params: { code: room.code },
      class: "w-full bg-gradient-to-r from-green-600 to-emerald-600 text-white font-bold py-3 px-4 rounded-xl mt-3" %>

<% elsif game.finished? %>
  <p class="text-white/60 text-sm">Game complete!</p>
<% end %>
```

- [ ] **Step 2: Create card picker partial (used during revealing)**

```erb
<%# app/views/games/scavenger_hunt/_card_picker.html.erb %>
<div data-controller="games--card-picker" class="space-y-3">
  <% game.hunt_prompt_instances.includes(:hunt_submissions, hunt_submissions: [:player, { media_attachment: :blob }]).each do |instance| %>
    <% completed_subs = instance.hunt_submissions.completed %>
    <% next if completed_subs.empty? %>

    <div class="bg-white/5 rounded-xl p-2 border border-white/10">
      <p class="text-white/60 text-xs font-bold tracking-widest px-1 mb-1"><%= instance.body %></p>
      <div class="flex gap-2 overflow-x-auto pb-1" data-games--card-picker-target="carousel">
        <% completed_subs.each do |sub| %>
          <% shown = game.currently_showing_submission_id == sub.id %>
          <%= button_to scavenger_hunt_game_reveal_path(game),
                method: :post,
                params: { submission_id: sub.id, code: room.code },
                class: "shrink-0 w-20 rounded-lg overflow-hidden border-2 transition-all #{shown ? 'border-yellow-400 opacity-50' : 'border-transparent'}",
                data: { turbo_frame: "hand_screen" } do %>
            <% if sub.media.attached? %>
              <%= image_tag rails_blob_path(sub.media.blob), class: "w-20 h-16 object-cover", alt: "" %>
            <% end %>
            <p class="text-white text-[10px] text-center py-0.5 truncate px-1"><%= sub.player.team_name || sub.player.name %></p>
          <% end %>
        <% end %>
      </div>
    </div>
  <% end %>
</div>
```

- [ ] **Step 3: Rubocop and commit**

```bash
rubocop -A app/views/games/scavenger_hunt/
git add -A && git commit -m "feat: add scavenger hunt host controls and card picker"
```

---

## Chunk 6: Stimulus Controllers & Image Upload

Client-side image compression and the card picker carousel behavior.

### Task 13: Create image upload Stimulus controller

**Files:**
- Create: `app/javascript/controllers/games/image_upload_controller.js`

- [ ] **Step 1: Create the controller**

```javascript
// app/javascript/controllers/games/image_upload_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "label", "progress", "bar", "status"]

  compress(event) {
    const file = event.target.files[0]
    if (!file) return

    // Show progress
    this.progressTarget.classList.remove("hidden")
    this.labelTarget.textContent = "Compressing..."
    this.barTarget.style.width = "10%"

    const maxWidth = 1920
    const quality = 0.8

    const reader = new FileReader()
    reader.onload = (e) => {
      const img = new Image()
      img.onload = () => {
        const canvas = document.createElement("canvas")
        let width = img.width
        let height = img.height

        if (width > maxWidth) {
          height = Math.round((height * maxWidth) / width)
          width = maxWidth
        }

        canvas.width = width
        canvas.height = height
        const ctx = canvas.getContext("2d")
        ctx.drawImage(img, 0, 0, width, height)

        this.barTarget.style.width = "50%"
        this.statusTarget.textContent = "Uploading..."

        canvas.toBlob((blob) => {
          // Replace the file input with the compressed blob
          const compressedFile = new File([blob], file.name, { type: "image/jpeg" })
          const dataTransfer = new DataTransfer()
          dataTransfer.items.add(compressedFile)
          this.inputTarget.files = dataTransfer.files

          this.barTarget.style.width = "70%"

          // Submit the form
          const form = this.element.closest("form") || this.element
          if (form.requestSubmit) {
            form.requestSubmit()
          } else {
            form.submit()
          }

          this.barTarget.style.width = "100%"
          this.statusTarget.textContent = "Done!"

          // Reset after a moment
          setTimeout(() => {
            this.progressTarget.classList.add("hidden")
            this.labelTarget.textContent = "Replace Photo"
            this.barTarget.style.width = "0%"
          }, 1500)
        }, "image/jpeg", quality)
      }
      img.src = e.target.result
    }
    reader.readAsDataURL(file)
  }
}
```

- [ ] **Step 2: Create card picker controller (minimal — just enables horizontal scroll on mobile)**

```javascript
// app/javascript/controllers/games/card_picker_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["carousel"]

  // Horizontal scroll is handled by CSS overflow-x-auto.
  // This controller exists for future enhancements (swipe gestures, snap scrolling).
}
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add image upload and card picker Stimulus controllers"
```

---

## Chunk 7: Hunt Pack CRUD (Studio)

The pack editor so hosts can create and manage prompt lists.

### Task 14: Create HuntPacksController and views

**Files:**
- Create: `app/controllers/hunt_packs_controller.rb`
- Create: `app/views/hunt_packs/index.html.erb`
- Create: `app/views/hunt_packs/new.html.erb`
- Create: `app/views/hunt_packs/edit.html.erb`
- Create: `app/views/hunt_packs/show.html.erb`
- Create: `app/views/hunt_packs/_form.html.erb`
- Create: `app/views/hunt_packs/_card.html.erb`
- Modify: `app/models/user.rb` — add `has_many :hunt_packs`

- [ ] **Step 1: Add association to User model**

In `app/models/user.rb`, add: `has_many :hunt_packs`

- [ ] **Step 2: Create HuntPacksController**

Follow the exact pattern from `app/controllers/category_packs_controller.rb`:

```ruby
# app/controllers/hunt_packs_controller.rb
class HuntPacksController < ApplicationController
  include PackReturnNavigation
  include StudioLayout

  before_action :authenticate_user!
  before_action :set_owned_hunt_pack, only: %i[show edit update destroy]

  def index
    @studio_active_section = :packs
    studio_breadcrumb("Content Packs", customize_path)
    studio_breadcrumb("Hunt Packs")
    @hunt_packs = current_user.hunt_packs.includes(:hunt_prompts).recent
    @system_packs = HuntPack.global.includes(:hunt_prompts).alphabetical
  end

  def show
    @studio_active_section = :packs
    studio_breadcrumb("Content Packs", customize_path)
    studio_breadcrumb("Hunt Packs", hunt_packs_path)
    studio_breadcrumb(@hunt_pack.name)
  end

  def new
    @studio_active_section = :packs
    studio_breadcrumb("Content Packs", customize_path)
    studio_breadcrumb("Hunt Packs", hunt_packs_path)
    studio_breadcrumb("New Pack")
    @hunt_pack = current_user.hunt_packs.new(game_type: "Scavenger Hunt")
    @hunt_pack.hunt_prompts.build
    @return_to = params[:return_to]
  end

  def create
    @hunt_pack = current_user.hunt_packs.new(hunt_pack_params)

    if @hunt_pack.save
      if valid_return_to?(params[:return_to])
        redirect_to append_new_pack_id(params[:return_to], @hunt_pack.id),
                    notice: "Hunt pack created. Returning to your game."
      else
        redirect_to edit_hunt_pack_path(@hunt_pack), notice: "Hunt pack created."
      end
    else
      @return_to = params[:return_to]
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @studio_active_section = :packs
    studio_breadcrumb("Content Packs", customize_path)
    studio_breadcrumb("Hunt Packs", hunt_packs_path)
    studio_breadcrumb(@hunt_pack.name)
    @return_to = params[:return_to]
  end

  def update
    if @hunt_pack.update(hunt_pack_params)
      redirect_to hunt_packs_path, notice: "Hunt pack updated successfully."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @hunt_pack.destroy
    redirect_to hunt_packs_path, notice: "Hunt pack deleted."
  end

  private

  def set_owned_hunt_pack
    @hunt_pack = current_user.hunt_packs.find(params[:id])
  end

  def hunt_pack_params
    params.require(:hunt_pack).permit(
      :name,
      :game_type,
      :status,
      hunt_prompts_attributes: %i[id body weight position _destroy]
    )
  end
end
```

- [ ] **Step 3: Create views**

Follow the patterns from `app/views/category_packs/` — index with cards, form with nested prompt fields, show page. The form should use the same Stimulus `content_editor` pattern (or a simpler one) for adding/removing prompt rows.

Views are extensive — the implementer should reference `app/views/category_packs/` for exact markup patterns and adapt them for hunt packs (replacing "categories" with "prompts", adding weight field).

- [ ] **Step 4: Add game settings fields for Scavenger Hunt**

In `app/views/rooms/_game_settings_fields.html.erb`, add a conditional block for Scavenger Hunt:

```erb
<% if room.game_type == "Scavenger Hunt" %>
  <div>
    <%= label_tag :timer_duration, "Hunt Duration (minutes)", class: "..." %>
    <%= number_field_tag :timer_duration, 30, min: 5, max: 120, class: "..." %>
  </div>
  <%# Pack picker — follow the pattern used by Speed Trivia / Category List %>
<% end %>
```

- [ ] **Step 5: Rubocop and commit**

```bash
rubocop -A app/controllers/hunt_packs_controller.rb app/views/hunt_packs/ app/views/rooms/_game_settings_fields.html.erb
git add -A && git commit -m "feat: add HuntPacks CRUD and game settings for Scavenger Hunt"
```

---

## Chunk 8: Backstage Curation Panel

The laptop-optimized curation UI for the host during hunting.

### Task 15: Create backstage curation panel

**Files:**
- Create: `app/views/games/scavenger_hunt/_curation_panel.html.erb`
- Modify: `app/views/backstages/show.html.erb` — render curation panel for scavenger hunt games

- [ ] **Step 1: Create curation panel partial**

This renders in the backstage view during `hunting` and `submissions_locked` states. Two-panel layout: prompt list sidebar + submission grid.

```erb
<%# app/views/games/scavenger_hunt/_curation_panel.html.erb %>
<div class="grid grid-cols-4 gap-4 mt-4">
  <%# Left: prompt list sidebar %>
  <div class="col-span-1 space-y-2">
    <h3 class="text-white font-bold text-sm tracking-widest mb-2">PROMPTS</h3>
    <% game.hunt_prompt_instances.includes(:hunt_submissions).each do |instance| %>
      <a href="#prompt-<%= instance.id %>"
         class="block bg-white/10 rounded-lg p-2 border border-white/10 hover:border-white/30 transition-all">
        <p class="text-white text-sm font-bold truncate"><%= instance.body %></p>
        <p class="text-white/40 text-xs"><%= instance.hunt_submissions.count %> submissions</p>
      </a>
    <% end %>
  </div>

  <%# Right: submission grid %>
  <div class="col-span-3 space-y-6">
    <% game.hunt_prompt_instances.includes(hunt_submissions: [:player, { media_attachment: :blob }]).each do |instance| %>
      <div id="prompt-<%= instance.id %>">
        <h3 class="text-white font-bold mb-2"><%= instance.body %> <span class="text-white/40 text-sm">(<%= instance.weight %> pts)</span></h3>
        <div class="grid grid-cols-3 gap-3">
          <% instance.hunt_submissions.each do |sub| %>
            <div class="bg-white/10 rounded-xl p-2 border border-white/10 <%= 'border-amber-500/50' if sub.late? %>">
              <% if sub.media.attached? %>
                <%= image_tag rails_blob_path(sub.media.blob), class: "w-full h-32 object-cover rounded-lg mb-2", alt: "" %>
              <% end %>
              <p class="text-white font-bold text-sm"><%= sub.player.team_name || sub.player.name %></p>
              <p class="text-white/40 text-xs"><%= time_ago_in_words(sub.created_at) %> ago</p>
              <% if sub.late? %>
                <span class="text-amber-400 text-xs font-bold">LATE</span>
              <% end %>

              <div class="flex gap-1 mt-2">
                <%= button_to scavenger_hunt_game_completion_path(game, sub),
                      method: :patch,
                      params: { action_type: "complete", value: (!sub.completed?).to_s, code: room.code },
                      class: "px-2 py-1 rounded text-xs font-bold #{sub.completed? ? 'bg-green-600 text-white' : 'bg-white/20 text-white/60'}" do %>
                  ✓
                <% end %>
                <%= button_to scavenger_hunt_game_completion_path(game, sub),
                      method: :patch,
                      params: { action_type: "favorite", value: (!sub.favorite?).to_s, code: room.code },
                      class: "px-2 py-1 rounded text-xs font-bold #{sub.favorite? ? 'bg-yellow-600 text-white' : 'bg-white/20 text-white/60'}" do %>
                  ★
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 2: Wire curation panel into backstage**

In `app/views/backstages/show.html.erb`, add a conditional render for scavenger hunt games:

```erb
<% if @room.current_game.is_a?(ScavengerHuntGame) && (@room.current_game.hunting? || @room.current_game.submissions_locked?) %>
  <%= render "games/scavenger_hunt/curation_panel", game: @room.current_game, room: @room %>
<% end %>
```

- [ ] **Step 3: Rubocop and commit**

```bash
rubocop -A app/views/games/scavenger_hunt/_curation_panel.html.erb app/views/backstages/show.html.erb
git add -A && git commit -m "feat: add backstage curation panel for scavenger hunt"
```

---

## Chunk 9: System Test & Seed Data

End-to-end test and default pack for development.

### Task 16: Create default hunt pack seed data

**Files:**
- Modify: `db/seeds.rb` (or create a separate seed file)

- [ ] **Step 1: Add default hunt pack to seeds**

```ruby
# Add to db/seeds.rb
hunt_pack = HuntPack.find_or_create_by!(name: "Classic Scavenger Hunt", is_default: true, user: nil, game_type: "Scavenger Hunt", status: :live)

prompts = [
  { body: "Take a team photo reenacting a famous painting", weight: 5 },
  { body: "Everyone in an elevator — make it dramatic", weight: 5 },
  { body: "Find a local landmark and pose like tourists", weight: 5 },
  { body: "Take a photo with a stranger (ask nicely!)", weight: 10 },
  { body: "Recreate a movie poster with your team", weight: 10 },
  { body: "Find something that starts with every letter of your team name", weight: 5 },
  { body: "Capture your best 'album cover' photo", weight: 5 },
  { body: "Team doing their best impression of a statue", weight: 5 },
  { body: "The most creative use of a common object", weight: 5 },
  { body: "Take a photo that tells a story in one frame", weight: 10 }
]

prompts.each_with_index do |prompt, index|
  hunt_pack.hunt_prompts.find_or_create_by!(body: prompt[:body]) do |p|
    p.weight = prompt[:weight]
    p.position = index
  end
end
```

- [ ] **Step 2: Run seeds**

```bash
bin/rails db:seed
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add default Classic Scavenger Hunt pack seed data"
```

### Task 17: Create system test

**Files:**
- Create: `spec/system/games/scavenger_hunt_happy_path_spec.rb`

- [ ] **Step 1: Write the happy path system spec**

```ruby
# spec/system/games/scavenger_hunt_happy_path_spec.rb
require "rails_helper"

RSpec.describe "Scavenger Hunt Game Happy Path", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, game_type: "Scavenger Hunt", user: nil) }

  before do
    pack = FactoryBot.create(:hunt_pack, :default)
    3.times do |i|
      FactoryBot.create(:hunt_prompt,
        hunt_pack: pack,
        body: "Test Prompt #{i + 1}",
        weight: 5,
        position: i)
    end
  end

  it "allows teams to submit photos, host curates, and reveals results" do
    # Host joins
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      fill_in "player[team_name]", with: "Team Alpha"
      click_on "Join Game"
      click_on "Claim Host"
      screenshot_checkpoint("lobby")
    end

    # Player 2 joins
    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      fill_in "player[team_name]", with: "Team Beta"
      click_on "Join Game"
    end

    # Host starts game
    Capybara.using_session(:host) do
      expect(page).to have_button("Start Game", wait: 5)
      click_on "Start Game"
      expect(page).to have_content("Get ready!")
      find("#start-from-instructions-btn").click
      expect(page).to have_content("Test Prompt 1", wait: 5)
    end

    game = room.reload.current_game
    expect(game).to be_hunting

    # Simulate photo submissions via service (file upload through Capybara is brittle)
    host_player = room.players.find_by(name: "Host")
    alice = room.players.find_by(name: "Alice")
    instance1 = game.hunt_prompt_instances.first

    fixture = Rails.root.join("spec/fixtures/files/test_photo.jpg")
    Games::ScavengerHunt.submit_photo(
      game: game,
      player: host_player,
      prompt_instance: instance1,
      media: { io: File.open(fixture), filename: "host_photo.jpg", content_type: "image/jpeg" }
    )
    Games::ScavengerHunt.submit_photo(
      game: game,
      player: alice,
      prompt_instance: instance1,
      media: { io: File.open(fixture), filename: "alice_photo.jpg", content_type: "image/jpeg" }
    )

    # Mark submissions as completed
    instance1.hunt_submissions.update_all(completed: true)

    # Host locks submissions and starts reveal
    Games::ScavengerHunt.lock_submissions_manually(game: game)
    expect(game.reload).to be_submissions_locked

    Games::ScavengerHunt.start_reveal(game: game)
    expect(game.reload).to be_revealing

    # Show a submission on stage
    sub = instance1.hunt_submissions.first
    Games::ScavengerHunt.show_submission_on_stage(game: game, submission: sub)

    # Start awards
    Games::ScavengerHunt.start_awards(game: game)
    expect(game.reload).to be_awarding

    # Pick winner
    Games::ScavengerHunt.pick_winner(game: game, prompt_instance: instance1, submission: sub)

    # Finish game
    Games::ScavengerHunt.finish_game(game: game)
    expect(game.reload).to be_finished

    # Verify scores
    expect(host_player.reload.score).to eq(10) # 5 completion + 5 winner bonus
    expect(alice.reload.score).to eq(5) # 5 completion only

    # Verify finished state in browser
    Capybara.using_session(:host) do
      expect(page).to have_content("Game Over!", wait: 10)
      screenshot_checkpoint("finished")
    end
  end
end
```

- [ ] **Step 2: Ensure test fixture exists**

```bash
ls spec/fixtures/files/test_photo.jpg || echo "Create fixture - see Task 6 Step 2"
```

- [ ] **Step 3: Run system test**

```bash
bin/rspec spec/system/games/scavenger_hunt_happy_path_spec.rb
```

- [ ] **Step 4: Fix any failures, then commit**

```bash
rubocop -A spec/system/games/scavenger_hunt_happy_path_spec.rb
git add -A && git commit -m "test: add scavenger hunt happy path system spec"
```

---

## Chunk 10: Final Integration & Cleanup

Wire everything together, verify the full flow, run full test suite.

### Task 18: Integration verification

- [ ] **Step 1: Run full test suite**

```bash
bin/rspec
```

- [ ] **Step 2: Run rubocop on all new files**

```bash
rubocop -A
```

- [ ] **Step 3: Run brakeman security check**

```bash
brakeman -q
```

- [ ] **Step 4: Verify game appears in room creation**

```bash
bin/dev
# Manually verify: create a room, select "Photo Scavenger Hunt", check the join form shows team_name field
```

- [ ] **Step 5: Test playtest flow via dev dashboard**

```bash
# In browser: visit /dev/playtest, select Scavenger Hunt, click through all playtest actions
```

- [ ] **Step 6: Final commit**

```bash
git add -A && git commit -m "feat: complete Scavenger Hunt game type integration"
```

---

## Implementation Notes for the Builder

1. **Read the design spec first** (`docs/superpowers/specs/2026-03-10-scavenger-hunt-design.md`). The Design Principles section explains WHY decisions were made. When you hit ambiguity, the principles should resolve it.

2. **The presentation is the product.** If you have to cut corners somewhere, cut them in the admin/pack editor. Never in the stage views or the card picker host controls.

3. **Test with real images.** The fixture JPEG is for CI. During manual testing, use actual photos to verify compression, display, and thumbnailing work correctly.

4. **The card picker is the hardest UI piece.** It needs to feel snappy on a phone (carousel swipe) and usable on a laptop (grid). Get this right before polishing anything else.

5. **Active Storage direct upload may need CORS.** If uploads from the hand view fail with CORS errors, configure the R2 bucket to allow requests from the app's domain. Check `config/storage.yml` for the R2 endpoint.

6. **`timer_duration` is passed in minutes from the form but stored in seconds.** The conversion (`* 60`) is already in `game_started`. The form field should use minutes (e.g., `30` for 30 minutes).
