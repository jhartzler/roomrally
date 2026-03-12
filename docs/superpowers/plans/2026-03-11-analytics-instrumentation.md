# Analytics Instrumentation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a session feed to the admin dashboard, a GameEvent audit log for timeline reconstruction, session health checks, and fill PostHog tracking gaps.

**Architecture:** New `game_events` table for precise timeline data. `SessionRecap` and `SessionHealth` service objects query existing tables + game_events to build timelines and flag anomalies. New admin controller/views under existing `Admin::` namespace. New PostHog events added to existing controllers/services alongside GameEvent writes.

**Tech Stack:** Rails 8, AASM, PostHog (server-side ruby gem), RSpec, FactoryBot

**Spec:** `docs/superpowers/specs/2026-03-11-analytics-instrumentation-design.md`

---

## Chunk 1: GameEvent Model & Migration

### Task 1: GameEvent Model

**Files:**
- Create: `app/models/game_event.rb`
- Create: `spec/models/game_event_spec.rb`
- Create: `db/migrate/TIMESTAMP_create_game_events.rb`
- Create: `spec/factories/game_events.rb`

- [ ] **Step 1: Generate migration**

Run:
```bash
bin/rails generate migration CreateGameEvents eventable:references{polymorphic} event_name:string metadata:jsonb
```

Then edit the generated migration to:
- Remove `updated_at` (keep only `created_at`)
- Add `null: false` to `event_name`
- Set `default: {}` on `metadata`
- Add compound index on `[:eventable_type, :eventable_id, :created_at]`

The migration should look like:
```ruby
class CreateGameEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :game_events do |t|
      t.references :eventable, polymorphic: true, null: false
      t.string :event_name, null: false
      t.jsonb :metadata, default: {}
      t.datetime :created_at, null: false
    end

    add_index :game_events, [:eventable_type, :eventable_id, :created_at], name: "index_game_events_on_eventable_and_created_at"
  end
end
```

- [ ] **Step 2: Run migration**

Run: `bin/rails db:migrate`
Expected: Migration runs successfully, schema.rb updated

- [ ] **Step 3: Write factory**

Create `spec/factories/game_events.rb`:
```ruby
FactoryBot.define do
  factory :game_event do
    association :eventable, factory: :speed_trivia_game
    event_name { "state_changed" }
    metadata { { from: "waiting", to: "answering" } }
  end
end
```

- [ ] **Step 4: Write model with tests**

Create `app/models/game_event.rb`:
```ruby
class GameEvent < ApplicationRecord
  belongs_to :eventable, polymorphic: true

  validates :event_name, presence: true

  def self.log(eventable, event_name, **metadata)
    create!(eventable:, event_name:, metadata:)
  rescue => e
    Rails.logger.warn("[GameEvent] Failed to log #{event_name}: #{e.message}")
  end
end
```

Create `spec/models/game_event_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe GameEvent do
  describe ".log" do
    it "creates an event record" do
      game = create(:speed_trivia_game)

      expect {
        described_class.log(game, "state_changed", from: "waiting", to: "answering")
      }.to change(described_class, :count).by(1)

      event = described_class.last
      expect(event.eventable).to eq(game)
      expect(event.event_name).to eq("state_changed")
      expect(event.metadata).to eq("from" => "waiting", "to" => "answering")
    end

    it "does not raise on failure" do
      expect {
        described_class.log(nil, "state_changed")
      }.not_to raise_error
    end
  end
end
```

- [ ] **Step 5: Run tests**

Run: `bin/rspec spec/models/game_event_spec.rb`
Expected: 2 examples, 0 failures

- [ ] **Step 6: Add has_many to game models**

Add `has_many :game_events, as: :eventable, dependent: :destroy` to each game model:

In `app/models/speed_trivia_game.rb`, after the existing associations:
```ruby
has_many :game_events, as: :eventable, dependent: :destroy
```

Same line in `app/models/write_and_vote_game.rb` and `app/models/category_list_game.rb`.

- [ ] **Step 7: Commit**

```bash
git add app/models/game_event.rb spec/models/game_event_spec.rb spec/factories/game_events.rb db/migrate/*_create_game_events.rb db/schema.rb app/models/speed_trivia_game.rb app/models/write_and_vote_game.rb app/models/category_list_game.rb
git commit -m "feat: add GameEvent model for session timeline tracking"
```

---

### Task 2: Instrument Game Services with GameEvent

**Files:**
- Modify: `app/services/games/speed_trivia.rb`
- Modify: `app/services/games/write_and_vote.rb`
- Modify: `app/services/games/category_list.rb`
- Create: `spec/services/games/game_event_tracking_spec.rb`

GameEvent.log calls go right next to existing Analytics.track calls in game services. Three event types: `game_created`, `state_changed`, `game_finished`.

- [ ] **Step 1: Write tests for GameEvent tracking across all 3 game types**

Create `spec/services/games/game_event_tracking_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe "GameEvent tracking in game services" do
  describe "SpeedTrivia" do
    let(:room) { create(:room, game_type: "Speed Trivia") }
    let!(:players) { create_list(:player, 3, room: room) }

    before do
      pack = create(:trivia_pack, :default)
      create_list(:trivia_question, 3, trivia_pack: pack)
      room.update!(trivia_pack: pack)
    end

    it "logs game_created on game_started" do
      expect {
        Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: true)
      }.to change(GameEvent, :count).by(1)

      event = GameEvent.last
      expect(event.event_name).to eq("game_created")
      expect(event.metadata["game_type"]).to eq("Speed Trivia")
    end

    it "logs state_changed on start_from_instructions" do
      Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: true)
      game = room.reload.current_game

      expect {
        Games::SpeedTrivia.start_from_instructions(game:)
      }.to change(GameEvent, :count)

      event = GameEvent.where(event_name: "state_changed").last
      expect(event.metadata["to"]).to eq("waiting")
    end

    it "logs state_changed on start_question" do
      Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: false)
      game = room.reload.current_game

      expect {
        Games::SpeedTrivia.start_question(game:)
      }.to change(GameEvent, :count)

      event = GameEvent.where(event_name: "state_changed").last
      expect(event.metadata["to"]).to eq("answering")
    end

    it "logs state_changed on close_round" do
      Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: false)
      game = room.reload.current_game
      Games::SpeedTrivia.start_question(game:)

      expect {
        Games::SpeedTrivia.close_round(game:)
      }.to change(GameEvent, :count)

      event = GameEvent.where(event_name: "state_changed").last
      expect(event.metadata["to"]).to eq("reviewing")
    end

    it "logs game_finished when last question reviewed" do
      Games::SpeedTrivia.game_started(room:, timer_enabled: false, show_instructions: false, question_count: 1)
      game = room.reload.current_game
      Games::SpeedTrivia.start_question(game:)
      Games::SpeedTrivia.close_round(game:)

      expect {
        Games::SpeedTrivia.next_question(game:)
      }.to change { GameEvent.where(event_name: "game_finished").count }.by(1)
    end
  end

  describe "WriteAndVote" do
    let(:room) { create(:room, game_type: "Write And Vote") }
    let!(:players) { create_list(:player, 3, room: room) }

    before do
      pack = create(:prompt_pack, :default)
      create_list(:prompt, 3, prompt_pack: pack)
      room.update!(prompt_pack: pack)
    end

    it "logs game_created on game_started" do
      expect {
        Games::WriteAndVote.game_started(room:, timer_enabled: false, show_instructions: true)
      }.to change(GameEvent, :count).by(1)

      event = GameEvent.last
      expect(event.event_name).to eq("game_created")
    end

    it "logs state_changed on start_from_instructions" do
      Games::WriteAndVote.game_started(room:, timer_enabled: false, show_instructions: true)
      game = room.reload.current_game

      expect {
        Games::WriteAndVote.start_from_instructions(game:)
      }.to change(GameEvent, :count)

      event = GameEvent.where(event_name: "state_changed").last
      expect(event.metadata["to"]).to eq("writing")
    end
  end

  describe "CategoryList" do
    let(:room) { create(:room, game_type: "Category List") }
    let!(:players) { create_list(:player, 3, room: room) }

    before do
      pack = create(:category_pack, :default)
      create_list(:category, 10, category_pack: pack)
      room.update!(category_pack: pack)
    end

    it "logs game_created on game_started" do
      expect {
        Games::CategoryList.game_started(room:, timer_enabled: false, show_instructions: true)
      }.to change(GameEvent, :count).by(1)

      event = GameEvent.last
      expect(event.event_name).to eq("game_created")
    end

    it "logs state_changed on start_from_instructions" do
      Games::CategoryList.game_started(room:, timer_enabled: false, show_instructions: true)
      game = room.reload.current_game

      expect {
        Games::CategoryList.start_from_instructions(game:)
      }.to change(GameEvent, :count)

      event = GameEvent.where(event_name: "state_changed").last
      expect(event.metadata["to"]).to eq("filling")
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rspec spec/services/games/game_event_tracking_spec.rb`
Expected: All tests fail (no GameEvent.log calls in services yet)

- [ ] **Step 3: Add GameEvent.log calls to SpeedTrivia**

**Pattern:** Always capture `previous_status = game.status` before the AASM transition, then log `GameEvent.log(game, "state_changed", from: previous_status, to: game.status)` after. This avoids hardcoded from/to values that can drift from AASM definitions.

In `app/services/games/speed_trivia.rb`:

After game creation (after `assign_questions` call, around line 36), add:
```ruby
GameEvent.log(game, "game_created", game_type: room.game_type, player_count: room.players.active_players.count, timer_enabled:)
```

In `start_from_instructions` (line 44), wrap the transition:
```ruby
previous_status = game.status
game.start_game!
GameEvent.log(game, "state_changed", from: previous_status, to: game.status)
```

In `start_question` method, wrap `game.begin_answering!`:
```ruby
previous_status = game.status
game.begin_answering!
# ... (existing code inside lock)
# After the lock block:
GameEvent.log(game, "state_changed", from: previous_status, to: "answering")
```

In `close_round` method, wrap `game.next_question!`:
```ruby
previous_status = game.status
game.next_question!
GameEvent.log(game, "state_changed", from: previous_status, to: game.status)
```

In `next_question` method, in the finish branch (around line 104), after `game.finish_game!`:
```ruby
GameEvent.log(game, "game_finished", duration_seconds: (Time.current - game.created_at).to_i, player_count: game.room.players.active_players.count)
```

Note: The non-finish branch of `next_question` calls `start_question(game:)` which already logs its own `state_changed` event — no additional logging needed here.

- [ ] **Step 4: Add GameEvent.log calls to WriteAndVote**

Same `previous_status` pattern as SpeedTrivia.

In `app/services/games/write_and_vote.rb`:

After game creation (after `room.update!(current_game: game)`, around line 28), add:
```ruby
GameEvent.log(game, "game_created", game_type: room.game_type, player_count: room.players.active_players.count, timer_enabled:)
```

In `start_from_instructions` (line 42), wrap the transition:
```ruby
previous_status = game.status
game.start_game!
GameEvent.log(game, "state_changed", from: previous_status, to: game.status)
```

In `transition_to_voting` (line 173), wrap the voting transition:
```ruby
previous_status = game.status
# ... existing transition code ...
GameEvent.log(game, "state_changed", from: previous_status, to: game.status)
```

In `advance_game_state!` (line 156), after `game.finish_game!`:
```ruby
GameEvent.log(game, "game_finished", duration_seconds: (Time.current - game.created_at).to_i, player_count: game.room.players.active_players.count)
```

- [ ] **Step 5: Add GameEvent.log calls to CategoryList**

Same `previous_status` pattern.

In `app/services/games/category_list.rb`:

After game creation (after `room.update!(current_game: game)`, around line 32), add:
```ruby
GameEvent.log(game, "game_created", game_type: room.game_type, player_count: room.players.active_players.count, timer_enabled:)
```

In `start_from_instructions` (line 40), wrap the transition:
```ruby
previous_status = game.status
game.start_game!
GameEvent.log(game, "state_changed", from: previous_status, to: game.status)
```

In `finish_review` (line 69), wrap `game.begin_scoring!`:
```ruby
previous_status = game.status
game.begin_scoring!
GameEvent.log(game, "state_changed", from: previous_status, to: game.status)
```

In `next_round` (line 111), in the finish branch after `game.finish_game!`:
```ruby
GameEvent.log(game, "game_finished", duration_seconds: (Time.current - game.created_at).to_i, player_count: game.room.players.active_players.count)
```

In the non-finish branch of `next_round`, wrap the round transition:
```ruby
previous_status = game.status
# ... existing setup_round code ...
GameEvent.log(game, "state_changed", from: previous_status, to: game.status)
```

In `submit_answers`, wrap `game.begin_review!`:
```ruby
previous_status = game.status
game.begin_review!
GameEvent.log(game, "state_changed", from: previous_status, to: game.status)
```

- [ ] **Step 6: Run tests**

Run: `bin/rspec spec/services/games/game_event_tracking_spec.rb`
Expected: All examples pass

- [ ] **Step 7: Run full test suite to check for regressions**

Run: `bin/rspec`
Expected: No new failures

- [ ] **Step 8: Commit**

```bash
git add app/services/games/speed_trivia.rb app/services/games/write_and_vote.rb app/services/games/category_list.rb spec/services/games/game_event_tracking_spec.rb
git commit -m "feat: instrument game services with GameEvent logging"
```

---

## Chunk 2: SessionRecap & SessionHealth Services

### Task 3: SessionRecap Service

**Files:**
- Create: `app/services/session_recap.rb`
- Create: `spec/services/session_recap_spec.rb`

Builds an ordered timeline of events for a room from DB records.

- [ ] **Step 1: Write tests**

Create `spec/services/session_recap_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe SessionRecap do
  describe ".for" do
    it "returns events ordered by timestamp" do
      room = create(:room)
      player1 = create(:player, room: room, name: "Alice", created_at: 1.minute.from_now)
      player2 = create(:player, room: room, name: "Bob", created_at: 2.minutes.from_now)

      events = described_class.for(room)

      expect(events.first.event_type).to eq("room_created")
      types = events.map(&:event_type)
      expect(types).to include("player_joined")
    end

    it "includes game events when present" do
      room = create(:room, game_type: "Speed Trivia")
      game = create(:speed_trivia_game)
      room.update!(current_game: game)
      GameEvent.log(game, "game_created", game_type: "Speed Trivia", player_count: 3)
      GameEvent.log(game, "state_changed", from: "instructions", to: "waiting")

      events = described_class.for(room)
      types = events.map(&:event_type)

      expect(types).to include("game_created", "state_changed")
    end

    it "includes answer submissions for speed trivia" do
      room = create(:room, game_type: "Speed Trivia")
      game = create(:speed_trivia_game)
      room.update!(current_game: game)
      question = create(:trivia_question_instance, speed_trivia_game: game)
      player = create(:player, room: room)
      create(:trivia_answer, trivia_question_instance: question, player: player, submitted_at: Time.current)

      events = described_class.for(room)
      types = events.map(&:event_type)

      expect(types).to include("answer_submitted")
    end

    it "includes votes for write and vote" do
      room = create(:room, game_type: "Write And Vote")
      game = create(:write_and_vote_game)
      room.update!(current_game: game)
      prompt = create(:prompt_instance, write_and_vote_game: game)
      player = create(:player, room: room)
      response = create(:response, prompt_instance: prompt, player: player)
      voter = create(:player, room: room, name: "Voter")
      create(:vote, response: response, player: voter)

      events = described_class.for(room)
      types = events.map(&:event_type)

      expect(types).to include("vote_cast")
    end

    it "returns an empty array for a room with no activity" do
      room = create(:room)
      events = described_class.for(room)

      expect(events.length).to eq(1) # just room_created
      expect(events.first.event_type).to eq("room_created")
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rspec spec/services/session_recap_spec.rb`
Expected: FAIL — `SessionRecap` not defined

- [ ] **Step 3: Implement SessionRecap**

Create `app/services/session_recap.rb`:
```ruby
class SessionRecap
  Event = Struct.new(:timestamp, :event_type, :description, :metadata, keyword_init: true)

  def self.for(room)
    new(room).build
  end

  def initialize(room)
    @room = room
    @game = room.current_game
  end

  def build
    events = []
    events << room_created_event
    events.concat(player_events)
    events.concat(game_event_records)
    events.concat(answer_events)
    events.concat(vote_events)
    events.sort_by(&:timestamp)
  end

  private

  def room_created_event
    Event.new(
      timestamp: @room.created_at,
      event_type: "room_created",
      description: "Room created#{@room.user ? " by #{@room.user.email}" : ""}",
      metadata: { room_code: @room.code, game_type: @room.game_type }
    )
  end

  def player_events
    @room.players.order(:created_at).map do |player|
      Event.new(
        timestamp: player.created_at,
        event_type: "player_joined",
        description: "Player joined: #{player.name}",
        metadata: { player_id: player.id, player_name: player.name }
      )
    end
  end

  def game_event_records
    return [] unless @game

    @game.game_events.order(:created_at).map do |ge|
      Event.new(
        timestamp: ge.created_at,
        event_type: ge.event_name,
        description: format_game_event(ge),
        metadata: ge.metadata
      )
    end
  end

  def answer_events
    return [] unless @game

    case @game
    when SpeedTriviaGame
      trivia_answer_events
    when WriteAndVoteGame
      response_events
    when CategoryListGame
      category_answer_events
    else
      []
    end
  end

  def trivia_answer_events
    @game.trivia_answers
      .includes(:player, :trivia_question_instance)
      .where.not(submitted_at: nil)
      .order(:submitted_at)
      .map do |answer|
        Event.new(
          timestamp: answer.submitted_at,
          event_type: "answer_submitted",
          description: "#{answer.player.name} answered Q#{answer.trivia_question_instance.position}#{answer.correct? ? " (correct)" : ""}",
          metadata: { player_name: answer.player.name, correct: answer.correct?, points: answer.points_awarded }
        )
      end
  end

  def response_events
    @game.responses
      .includes(:player)
      .order(:created_at)
      .map do |response|
        Event.new(
          timestamp: response.created_at,
          event_type: "response_submitted",
          description: "#{response.player.name} submitted a response",
          metadata: { player_name: response.player.name, status: response.status }
        )
      end
  end

  def category_answer_events
    @game.category_answers
      .includes(:player, :category_instance)
      .order(:created_at)
      .map do |answer|
        Event.new(
          timestamp: answer.created_at,
          event_type: "answer_submitted",
          description: "#{answer.player.name} answered in #{answer.category_instance.name}",
          metadata: { player_name: answer.player.name, category: answer.category_instance.name }
        )
      end
  end

  def vote_events
    return [] unless @game.is_a?(WriteAndVoteGame)

    Vote.joins(response: :prompt_instance)
      .where(prompt_instances: { write_and_vote_game_id: @game.id })
      .includes(:player)
      .order(:created_at)
      .map do |vote|
        Event.new(
          timestamp: vote.created_at,
          event_type: "vote_cast",
          description: "#{vote.player.name} cast a vote",
          metadata: { player_name: vote.player.name }
        )
      end
  end

  def format_game_event(ge)
    case ge.event_name
    when "state_changed"
      "State: #{ge.metadata["from"]} → #{ge.metadata["to"]}"
    when "game_created"
      "Game started (#{ge.metadata["game_type"]})"
    when "game_finished"
      "Game finished (#{ge.metadata["duration_seconds"]}s)"
    else
      ge.event_name.humanize
    end
  end
end
```

- [ ] **Step 4: Run tests**

Run: `bin/rspec spec/services/session_recap_spec.rb`
Expected: All examples pass. Some tests may need factory adjustments — fix associations as needed (e.g., `trivia_answers` through `trivia_question_instances`).

- [ ] **Step 5: Commit**

```bash
git add app/services/session_recap.rb spec/services/session_recap_spec.rb
git commit -m "feat: add SessionRecap service for timeline reconstruction"
```

---

### Task 4: SessionHealth Service

**Files:**
- Create: `app/services/session_health.rb`
- Create: `spec/services/session_health_spec.rb`

Returns health flags for a room session.

- [ ] **Step 1: Write tests**

Create `spec/services/session_health_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe SessionHealth do
  describe ".check" do
    it "returns empty array for healthy finished game" do
      room = create(:room, status: :finished, game_type: "Speed Trivia")
      game = create(:speed_trivia_game, status: :finished)
      room.update!(current_game: game)
      player = create(:player, room: room)
      question = create(:trivia_question_instance, speed_trivia_game: game)
      create(:trivia_answer, trivia_question_instance: question, player: player, submitted_at: Time.current)

      flags = described_class.check(room)
      expect(flags).to be_empty
    end

    it "flags game stuck in non-terminal state" do
      room = create(:room, status: :playing, game_type: "Speed Trivia")
      game = create(:speed_trivia_game, status: :answering, updated_at: 45.minutes.ago)
      room.update!(current_game: game)

      flags = described_class.check(room)
      expect(flags.any? { |f| f.description.include?("stuck") }).to be true
      expect(flags.first.severity).to eq(:error)
    end

    it "flags room that never started a game" do
      room = create(:room, status: :lobby)
      create(:player, room: room)

      flags = described_class.check(room)
      expect(flags.any? { |f| f.description.include?("never started") }).to be true
    end

    it "flags player with zero submissions" do
      room = create(:room, status: :finished, game_type: "Speed Trivia")
      game = create(:speed_trivia_game, status: :finished)
      room.update!(current_game: game)
      create(:player, room: room, name: "Ghost")
      question = create(:trivia_question_instance, speed_trivia_game: game)
      # Ghost has no answers

      flags = described_class.check(room)
      expect(flags.any? { |f| f.description.include?("Ghost") && f.description.include?("0 submissions") }).to be true
    end

    it "flags abandoned mid-game" do
      room = create(:room, status: :finished, game_type: "Speed Trivia")
      game = create(:speed_trivia_game, status: :answering)
      room.update!(current_game: game)

      flags = described_class.check(room)
      expect(flags.any? { |f| f.severity == :error && f.description.include?("abandoned") }).to be true
    end

    it "returns no flags for room with no players and no game" do
      room = create(:room, status: :lobby)
      # No players, no game — just a fresh room
      flags = described_class.check(room)
      expect(flags).to be_empty
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rspec spec/services/session_health_spec.rb`
Expected: FAIL — `SessionHealth` not defined

- [ ] **Step 3: Implement SessionHealth**

Create `app/services/session_health.rb`:
```ruby
class SessionHealth
  STUCK_THRESHOLD = 30.minutes

  Flag = Struct.new(:severity, :description, keyword_init: true)

  def self.check(room)
    new(room).flags
  end

  def initialize(room)
    @room = room
    @game = room.current_game
  end

  def flags
    checks = []
    checks << check_stuck_state
    checks << check_never_started
    checks << check_abandoned_mid_game
    checks.concat(check_zero_submissions)
    checks.compact
  end

  private

  def check_stuck_state
    return unless @game
    return if @game.status.to_s == "finished"
    return if @game.updated_at > STUCK_THRESHOLD.ago

    Flag.new(
      severity: :error,
      description: "Game stuck in \"#{@game.status}\" for >30 min"
    )
  end

  def check_never_started
    return unless @room.players.any?
    return if @game

    Flag.new(
      severity: :warning,
      description: "Room has #{@room.players.count} player(s) but game never started"
    )
  end

  def check_abandoned_mid_game
    return unless @game
    return unless @room.status.to_s == "finished"
    return if @game.status.to_s == "finished"

    Flag.new(
      severity: :error,
      description: "Room closed but game abandoned in \"#{@game.status}\""
    )
  end

  def check_zero_submissions
    return [] unless @game
    return [] unless @game.status.to_s == "finished"

    @room.players.filter_map do |player|
      count = submission_count(player)
      next if count > 0

      Flag.new(
        severity: :warning,
        description: "#{player.name} had 0 submissions"
      )
    end
  end

  def submission_count(player)
    case @game
    when SpeedTriviaGame
      player.trivia_answers.where(trivia_question_instance: @game.trivia_question_instances).count
    when WriteAndVoteGame
      player.responses.where(prompt_instance: @game.prompt_instances).count
    when CategoryListGame
      CategoryAnswer.where(player: player, category_instance: @game.category_instances).count
    else
      0
    end
  end
end
```

- [ ] **Step 4: Run tests**

Run: `bin/rspec spec/services/session_health_spec.rb`
Expected: All examples pass

- [ ] **Step 5: Commit**

```bash
git add app/services/session_health.rb spec/services/session_health_spec.rb
git commit -m "feat: add SessionHealth service for anomaly detection"
```

---

## Chunk 3: Admin Sessions Dashboard

### Task 5: Admin Sessions Controller & Routes

**Files:**
- Create: `app/controllers/admin/sessions_controller.rb`
- Modify: `config/routes.rb`
- Create: `spec/requests/admin/sessions_spec.rb`

- [ ] **Step 1: Write request specs**

Create `spec/requests/admin/sessions_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe "Admin::Sessions" do
  let(:admin) { create(:user, :admin) }
  let(:non_admin) { create(:user) }

  describe "GET /admin/sessions" do
    it "requires admin access" do
      sign_in(non_admin)
      get admin_sessions_path
      expect(response).to redirect_to(root_path)
    end

    it "renders for admin users" do
      sign_in(admin)
      get admin_sessions_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /admin/sessions/:code" do
    let(:room) { create(:room) }

    it "requires admin access" do
      sign_in(non_admin)
      get admin_session_path(room.code)
      expect(response).to redirect_to(root_path)
    end

    it "renders for admin users" do
      sign_in(admin)
      get admin_session_path(room.code)
      expect(response).to have_http_status(:ok)
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rspec spec/requests/admin/sessions_spec.rb`
Expected: FAIL — route/controller not defined

- [ ] **Step 3: Add route**

In `config/routes.rb`, inside the `namespace :admin` block, add:
```ruby
resources :sessions, only: %i[index show], param: :code
```

- [ ] **Step 4: Create controller**

Create `app/controllers/admin/sessions_controller.rb`:
```ruby
module Admin
  class SessionsController < BaseController
    def index
      @rooms = Room.includes(:players, :current_game, :user)
        .order(created_at: :desc)
      @health_flags = @rooms.each_with_object({}) do |room, hash|
        hash[room.id] = SessionHealth.check(room)
      end
    end

    def show
      @room = Room.includes(:players, :current_game, :user).find_by!(code: params[:code])
      @health_flags = SessionHealth.check(@room)
      @timeline = SessionRecap.for(@room)
    end
  end
end
```

- [ ] **Step 5: Run tests**

Run: `bin/rspec spec/requests/admin/sessions_spec.rb`
Expected: Tests pass (may fail on missing template — that's OK, we'll create views next)

- [ ] **Step 6: Commit**

```bash
git add app/controllers/admin/sessions_controller.rb config/routes.rb spec/requests/admin/sessions_spec.rb
git commit -m "feat: add admin sessions controller with auth gating"
```

---

### Task 6: Admin Sessions Views

**Files:**
- Create: `app/views/admin/sessions/index.html.erb`
- Create: `app/views/admin/sessions/show.html.erb`
- Create: `app/views/admin/sessions/_session_row.html.erb`
- Create: `app/views/admin/sessions/_timeline.html.erb`
- Modify: `app/views/layouts/admin.html.erb` (add Sessions nav tab)

- [ ] **Step 1: Add nav links to admin layout**

In `app/views/layouts/admin.html.erb`, replace the header's left-side `<div>` (lines 24-31) with nav links:
```erb
<div class="flex items-center gap-4">
  <%= link_to admin_root_path, class: "text-lg font-bold text-indigo-700" do %>
    RoomRally Admin
  <% end %>
  <nav class="flex items-center gap-3 ml-4">
    <%= link_to "Users", admin_users_path, class: "text-sm font-medium #{request.path.start_with?('/admin/users') || request.path == '/admin' ? 'text-indigo-700' : 'text-gray-500 hover:text-gray-700'}" %>
    <%= link_to "Sessions", admin_sessions_path, class: "text-sm font-medium #{request.path.start_with?('/admin/sessions') ? 'text-indigo-700' : 'text-gray-500 hover:text-gray-700'}" %>
  </nav>
  <% if content_for?(:breadcrumb) %>
    <span class="text-gray-400">/</span>
    <%= yield :breadcrumb %>
  <% end %>
</div>
```

- [ ] **Step 2: Create session row partial**

Create `app/views/admin/sessions/_session_row.html.erb`:
```erb
<%
  flags = health_flags[room.id] || []
  dot_color = if room.current_game.nil? && room.players.any?
    "bg-gray-400"
  elsif flags.any? { |f| f.severity == :error }
    "bg-red-500"
  elsif flags.any? { |f| f.severity == :warning }
    "bg-amber-500"
  else
    "bg-green-500"
  end

  game = room.current_game
  game_type_name = Room::GAME_DISPLAY_NAMES[room.game_type] || room.game_type
  duration = if game
    seconds = ((game.updated_at - game.created_at)).to_i
    if game.status.to_s != "finished" && seconds > 1800
      "#{seconds / 60}m+"
    else
      "#{seconds / 60}m #{seconds % 60}s"
    end
  end
%>

<div class="bg-white border border-gray-200 rounded-lg overflow-hidden" data-controller="session-row" data-session-row-code-value="<%= room.code %>">
  <div class="px-4 py-3 flex justify-between items-center cursor-pointer" data-action="click->session-row#toggle">
    <div class="flex items-center gap-3">
      <div class="w-2.5 h-2.5 rounded-full shrink-0 <%= dot_color %>"></div>
      <div>
        <div class="font-semibold text-sm text-gray-900">
          <%= link_to room.code, admin_session_path(room.code), class: "hover:underline", data: { action: "click->session-row#navigate" } %>
          <span class="font-normal text-gray-500 text-xs ml-2"><%= game_type_name %></span>
        </div>
        <div class="text-xs text-gray-400 mt-0.5">
          <%= room.created_at.strftime("%-b %-d, %-I:%M %p") %>
          &middot; <%= pluralize(room.players.size, "player") %>
          <% if duration %>&middot; <%= duration %><% end %>
          &middot;
          <% if game&.status.to_s == "finished" %>
            Finished
          <% elsif game %>
            <span class="text-red-600 font-semibold"><%= game.status.humanize %></span>
          <% else %>
            Lobby
          <% end %>
        </div>
      </div>
    </div>

    <div class="flex items-center gap-2">
      <% flags.each do |flag| %>
        <span class="<%= flag.severity == :error ? 'bg-red-100 text-red-800' : 'bg-amber-100 text-amber-800' %> text-xs px-2 py-0.5 rounded font-medium">
          <%= flag.description %>
        </span>
      <% end %>
      <span class="text-gray-400 text-lg" data-session-row-target="arrow">&#9656;</span>
    </div>
  </div>

  <div class="border-t border-gray-100 px-4 py-3 bg-gray-50 hidden" data-session-row-target="timeline">
    <% timeline = SessionRecap.for(room) %>
    <%= render "admin/sessions/timeline", events: timeline %>
  </div>
</div>
```

- [ ] **Step 3: Create timeline partial**

Create `app/views/admin/sessions/_timeline.html.erb`:
```erb
<div class="text-xs text-gray-600 flex flex-col gap-1 font-mono">
  <% events.each do |event| %>
    <div>
      <span class="text-gray-400"><%= event.timestamp.strftime("%-I:%M:%S %p") %></span>
      <%= event.description %>
    </div>
  <% end %>
  <% if events.empty? %>
    <div class="text-gray-400 italic">No activity recorded</div>
  <% end %>
</div>
```

- [ ] **Step 4: Create index view**

Create `app/views/admin/sessions/index.html.erb`:
```erb
<h1 class="text-2xl font-bold text-gray-900 mb-6">Sessions</h1>

<div data-controller="hidden-sessions" data-hidden-sessions-key-value="roomrally-hidden-sessions">
  <div class="mb-4 flex items-center gap-3">
    <label class="flex items-center gap-2 text-sm text-gray-600 cursor-pointer">
      <input type="checkbox" data-hidden-sessions-target="toggle" data-action="hidden-sessions#toggle" class="rounded">
      Show hidden
    </label>
  </div>

  <div class="flex flex-col gap-3">
    <% @rooms.each do |room| %>
      <div data-hidden-sessions-target="row" data-room-code="<%= room.code %>">
        <%= render "admin/sessions/session_row", room: room, health_flags: @health_flags %>
      </div>
    <% end %>

    <% if @rooms.empty? %>
      <p class="text-gray-500 text-center py-12">No sessions yet</p>
    <% end %>
  </div>
</div>
```

- [ ] **Step 5: Create show view**

Create `app/views/admin/sessions/show.html.erb`:
```erb
<%
  game = @room.current_game
  game_type_name = Room::GAME_DISPLAY_NAMES[@room.game_type] || @room.game_type
%>

<div class="mb-4">
  <%= link_to "← Sessions", admin_sessions_path, class: "text-sm text-blue-600 hover:underline" %>
</div>

<div class="bg-white border border-gray-200 rounded-lg p-6 mb-6">
  <div class="flex items-center gap-3 mb-4">
    <h1 class="text-2xl font-bold text-gray-900"><%= @room.code %></h1>
    <span class="text-gray-500"><%= game_type_name %></span>
    <% if game&.status.to_s == "finished" %>
      <span class="bg-green-100 text-green-800 text-xs px-2 py-0.5 rounded font-medium">Finished</span>
    <% elsif game %>
      <span class="bg-red-100 text-red-800 text-xs px-2 py-0.5 rounded font-medium"><%= game.status.humanize %></span>
    <% else %>
      <span class="bg-gray-100 text-gray-600 text-xs px-2 py-0.5 rounded font-medium">Lobby</span>
    <% end %>
  </div>

  <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm text-gray-600 mb-4">
    <div><span class="font-medium text-gray-900">Created:</span> <%= @room.created_at.strftime("%-b %-d, %-I:%M %p") %></div>
    <div><span class="font-medium text-gray-900">Players:</span> <%= @room.players.size %></div>
    <% if @room.user %><div><span class="font-medium text-gray-900">Host:</span> <%= @room.user.email %></div><% end %>
    <% if game %>
      <div><span class="font-medium text-gray-900">Duration:</span> <%= ((game.updated_at - game.created_at) / 60).round(1) %> min</div>
    <% end %>
  </div>

  <% if @health_flags.any? %>
    <div class="flex flex-wrap gap-2 mb-4">
      <% @health_flags.each do |flag| %>
        <span class="<%= flag.severity == :error ? 'bg-red-100 text-red-800' : 'bg-amber-100 text-amber-800' %> text-xs px-2 py-0.5 rounded font-medium">
          <%= flag.description %>
        </span>
      <% end %>
    </div>
  <% end %>
</div>

<div class="bg-white border border-gray-200 rounded-lg p-6">
  <h2 class="text-lg font-semibold text-gray-900 mb-4">Timeline</h2>
  <%= render "admin/sessions/timeline", events: @timeline %>
</div>

<div class="mt-4 text-right" data-controller="hidden-sessions" data-hidden-sessions-key-value="roomrally-hidden-sessions">
  <button data-action="click->hidden-sessions#hideOne" data-room-code="<%= @room.code %>"
    class="text-xs text-gray-400 hover:text-gray-600">
    Hide this session
  </button>
</div>
```

- [ ] **Step 6: Run request specs again to verify views render**

Run: `bin/rspec spec/requests/admin/sessions_spec.rb`
Expected: All pass

- [ ] **Step 7: Commit**

```bash
git add app/views/admin/sessions/ app/views/layouts/admin.html.erb
git commit -m "feat: add admin sessions index and show views"
```

---

### Task 7: Stimulus Controllers for Session Feed

**Files:**
- Create: `app/javascript/controllers/session_row_controller.js`
- Create: `app/javascript/controllers/hidden_sessions_controller.js`

- [ ] **Step 1: Create session-row controller**

Create `app/javascript/controllers/session_row_controller.js`:
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["timeline", "arrow"]
  static values = { code: String }

  toggle(event) {
    // Don't toggle if clicking the room code link
    if (event.target.closest("a")) return

    this.timelineTarget.classList.toggle("hidden")
    this.arrowTarget.innerHTML = this.timelineTarget.classList.contains("hidden") ? "&#9656;" : "&#9662;"
  }

  navigate(event) {
    event.stopPropagation()
  }
}
```

- [ ] **Step 2: Create hidden-sessions controller**

Create `app/javascript/controllers/hidden_sessions_controller.js`:
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "row"]
  static values = { key: String }

  connect() {
    this.applyFilter()
  }

  toggle() {
    this.applyFilter()
  }

  hideOne(event) {
    const code = event.currentTarget.dataset.roomCode
    const hidden = this.hiddenCodes()
    if (!hidden.includes(code)) {
      hidden.push(code)
      localStorage.setItem(this.keyValue, JSON.stringify(hidden))
      event.currentTarget.textContent = "Hidden"
      event.currentTarget.disabled = true
      this.applyFilter()
    }
  }

  applyFilter() {
    const showHidden = this.toggleTarget.checked
    const hidden = this.hiddenCodes()

    this.rowTargets.forEach(row => {
      const code = row.dataset.roomCode
      if (hidden.includes(code) && !showHidden) {
        row.classList.add("hidden")
      } else {
        row.classList.remove("hidden")
      }
    })
  }

  hiddenCodes() {
    try {
      return JSON.parse(localStorage.getItem(this.keyValue) || "[]")
    } catch {
      return []
    }
  }
}
```

- [ ] **Step 3: Verify Stimulus auto-registration**

Stimulus controllers in `app/javascript/controllers/` are auto-registered in this project. No manual import needed.

Run: `bin/rspec spec/requests/admin/sessions_spec.rb`
Expected: All pass (Stimulus is client-side, won't affect server rendering)

- [ ] **Step 4: Commit**

```bash
git add app/javascript/controllers/session_row_controller.js app/javascript/controllers/hidden_sessions_controller.js
git commit -m "feat: add Stimulus controllers for session feed interactivity"
```

---

## Chunk 4: PostHog Events & Cleanup

### Task 8: Add New PostHog Events

**Files:**
- Modify: `app/controllers/game_templates_controller.rb` (template_edited, template_deleted)
- Modify: `app/controllers/players_controller.rb` (join_page_viewed)
- Modify: `app/services/games/speed_trivia.rb` (instructions_skipped)
- Modify: `app/services/games/write_and_vote.rb` (instructions_skipped)
- Modify: `app/services/games/category_list.rb` (instructions_skipped)

- [ ] **Step 1: Add template_edited event**

In `app/controllers/game_templates_controller.rb`, in the `update` method, inside the `if @game_template.update` branch, add before the redirect:
```ruby
Analytics.track(
  distinct_id: "user_#{current_user.id}",
  event: "template_edited",
  properties: { game_type: @game_template.game_type, template_id: @game_template.id }
)
```

- [ ] **Step 2: Add template_deleted event**

In the `destroy` method, add before `redirect_to`:
```ruby
Analytics.track(
  distinct_id: "user_#{current_user.id}",
  event: "template_deleted",
  properties: { game_type: @game_template.game_type, template_id: @game_template.id }
)
```

- [ ] **Step 3: Add join_page_viewed event**

In `app/controllers/players_controller.rb`, in the `new` method, add:
```ruby
Analytics.track(
  distinct_id: "session_#{session.id}",
  event: "join_page_viewed",
  properties: { room_code: @room.code }
)
```

Note: `@room` should already be set by a before_action. Verify this is the case. If `new` doesn't set `@room`, check the controller's before_actions to find how the room is resolved and use that.

- [ ] **Step 4: Add instructions_skipped events**

In all three game services, the `game_started` method has a branch where `show_instructions` is false and `game.start_game!` is called immediately. Add after that `start_game!` call:

For `app/services/games/speed_trivia.rb`, after `game.start_game! unless show_instructions` (around line 39), wrap it:
```ruby
unless show_instructions
  game.start_game!
  Analytics.track(
    distinct_id: room.user_id ? "user_#{room.user_id}" : "room_#{room.code}",
    event: "instructions_skipped",
    properties: { game_type: room.game_type, room_code: room.code }
  )
end
```

Apply the same pattern in `write_and_vote.rb` (in the `unless show_instructions` / `else` branch around line 33) and `category_list.rb` (after the `game.start_game! unless show_instructions` around line 36).

- [ ] **Step 5: Run existing test suite to check for regressions**

Run: `bin/rspec`
Expected: No new failures

- [ ] **Step 6: Commit**

```bash
git add app/controllers/game_templates_controller.rb app/controllers/players_controller.rb app/services/games/speed_trivia.rb app/services/games/write_and_vote.rb app/services/games/category_list.rb
git commit -m "feat: add new PostHog events for template editing, join page, and instructions skip"
```

---

### Task 9: Clean Up Existing PostHog Events

**Files:**
- Modify: `app/controllers/sessions_controller.rb`

**Note on distinct_id audit:** The spec mentions standardizing distinct_id patterns. After review, the existing game service calls already consistently use `room.user_id ? "user_#{room.user_id}" : "room_#{room.code}"`. The player-scoped events (`player_joined`, `vote_*`) intentionally use `"player_#{session_id}"` because they represent anonymous player actions. No changes needed — the divergence is by design, not a bug.

- [ ] **Step 1: Add provider property to auth events**

In `app/controllers/sessions_controller.rb`, change the `Analytics.track` call (around line 14) from:
```ruby
properties: {}
```
to:
```ruby
properties: { provider: "google" }
```

- [ ] **Step 2: Run tests**

Run: `bin/rspec spec/`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add app/controllers/sessions_controller.rb
git commit -m "fix: add provider property to auth PostHog events"
```

---

### Task 10: Final Verification

- [ ] **Step 1: Run full test suite**

Run: `bin/rspec`
Expected: All pass

- [ ] **Step 2: Run rubocop**

Run: `rubocop`
If failures: `rubocop -A` to auto-fix, then re-run

- [ ] **Step 3: Run brakeman**

Run: `brakeman -q`
Expected: No new warnings

- [ ] **Step 4: Migrate test database**

Run: `RAILS_ENV=test bin/rails db:test:prepare`
Then: `RAILS_ENV=test bin/rails tailwindcss:build` (needed for system tests in worktree per CLAUDE.md)

- [ ] **Step 5: Run system tests specifically**

Run: `bin/rspec spec/system/`
Expected: All pass

- [ ] **Step 6: Final commit if any rubocop fixes**

```bash
git add -A
git commit -m "chore: rubocop auto-fixes"
```
