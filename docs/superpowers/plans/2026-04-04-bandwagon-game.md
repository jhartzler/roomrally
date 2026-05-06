# Bandwagon Game Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build "Bandwagon" — a polling game where players score by being in the majority, minority, or matching the host's chosen answer, with speed-based bonus points.

**Architecture:** New standalone game type following the exact Speed Trivia pattern — `PollGame` model with AASM, `Games::Poll` service module with nested `Playtest`, four controllers under `PollGames::`, and stage/hand view partials. Prerequisite: extract shared `question_list_editor_controller.js` from `trivia_editor_controller.js` before building the pack editor. Internal name `PollGame`; display name "Bandwagon".

**Tech Stack:** Ruby on Rails 8+, AASM, Hotwire (Turbo Streams + Stimulus), Tailwind CSS, RSpec + Capybara/Playwright

---

## File Map

### New Files
- `app/models/poll_game.rb` — AASM state machine, scoring helpers
- `app/models/poll_pack.rb` — belongs_to user, has_many poll_questions
- `app/models/poll_question.rb` — body + options jsonb, no correct_answer
- `app/models/poll_answer.rb` — selected_option, submitted_at, points_awarded
- `db/migrate/..._create_poll_packs.rb`
- `db/migrate/..._create_poll_questions.rb`
- `db/migrate/..._create_poll_games.rb`
- `db/migrate/..._create_poll_answers.rb`
- `app/services/games/poll.rb` — service module + nested Playtest module
- `app/controllers/poll_games/game_starts_controller.rb`
- `app/controllers/poll_games/questions_controller.rb`
- `app/controllers/poll_games/round_closures_controller.rb`
- `app/controllers/poll_games/advancements_controller.rb`
- `app/controllers/poll_games/host_answers_controller.rb`
- `app/controllers/poll_answers_controller.rb`
- `app/views/games/poll/_hand.html.erb`
- `app/views/games/poll/_answer_form.html.erb`
- `app/views/games/poll/_waiting.html.erb`
- `app/views/games/poll/_game_over.html.erb`
- `app/views/games/poll/_host_controls.html.erb`
- `app/views/games/poll/_stage_instructions.html.erb`
- `app/views/games/poll/_stage_waiting.html.erb`
- `app/views/games/poll/_stage_answering.html.erb`
- `app/views/games/poll/_stage_reviewing.html.erb`
- `app/views/games/poll/_stage_finished.html.erb`
- `app/views/games/poll/_vote_summary.html.erb`
- `app/views/poll_packs/index.html.erb`
- `app/views/poll_packs/new.html.erb`
- `app/views/poll_packs/edit.html.erb`
- `app/views/poll_packs/show.html.erb`
- `app/views/poll_packs/_form.html.erb`
- `app/views/poll_packs/_card.html.erb`
- `app/javascript/controllers/question_list_editor_controller.js` — shared base (extracted)
- `app/javascript/controllers/poll_editor_controller.js` — thin wrapper
- `spec/models/poll_game_spec.rb`
- `spec/models/poll_answer_spec.rb`
- `spec/services/games/poll_spec.rb`
- `spec/system/games/bandwagon_happy_path_spec.rb`
- `spec/system/games/bandwagon_host_choose_spec.rb`

### Modified Files
- `app/javascript/controllers/trivia_editor_controller.js` — slim to trivia-only after extraction
- `config/routes.rb` — add poll_games routes, poll_answers, poll_packs
- `config/initializers/game_registry.rb` — register PollGame
- `app/models/room.rb` — add POLL_GAME constant + GAME_TYPES + GAME_DISPLAY_NAMES
- `app/controllers/rooms_controller.rb` — no changes needed (handles polymorphic current_game)

---

## Task 1: Extract Shared Question List Editor

**Files:**
- Create: `app/javascript/controllers/question_list_editor_controller.js`
- Modify: `app/javascript/controllers/trivia_editor_controller.js`

The `trivia_editor_controller.js` has 700+ lines. The shared base covers: drag/drop, template lifecycle, position tracking, collapse/expand, count display, option add/remove, option re-lettering. Trivia-specific: correct answer sync, image management.

- [ ] **Step 1: Read the full trivia_editor_controller.js to identify the shared boundary**

```bash
wc -l app/javascript/controllers/trivia_editor_controller.js
cat app/javascript/controllers/trivia_editor_controller.js
```

Identify which methods are purely structural (drag/drop, positions, collapse, add/remove option) vs trivia-specific (correct answer buttons, image upload/preview/remove).

- [ ] **Step 2: Create the shared base controller**

Create `app/javascript/controllers/question_list_editor_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Shared base for question list editors (trivia, poll, etc.)
// Handles: drag/drop reorder, template lifecycle, position tracking,
// collapse/expand, count display, option add/remove, option re-lettering.
// Subclasses use a different controller name and may override hooks.
export default class extends Controller {
  static targets = [
    "questionList", "questionTemplate", "countDisplay",
    "questionField", "optionField", "positionField", "positionBadge",
    "optionRow", "optionLetter", "optionsContainer", "addOptionButton",
    "collapsibleContent", "collapseAllButton"
  ]

  connect() {
    this.draggedElement = null
    this.dragFromHandle = false
    this.updatePositions()
    this.updateCount()
    this.onConnect()

    this.element.addEventListener("mousedown", (e) => {
      this.dragFromHandle = !!e.target.closest(".drag-handle")
    })
  }

  // Hook for subclasses to run additional connect logic
  onConnect() {}

  // --- Drag and Drop ---
  // (copy dragStart, dragEnd, dragOver, dragEnter, dragLeave, drop from trivia_editor_controller.js)

  // --- Collapse / Expand ---
  // (copy toggleCollapse, toggleCollapseAll, collapseCards, expandCards from trivia_editor_controller.js)

  // --- Questions ---
  addQuestion() {
    const template = this.questionTemplateTarget
    const content = template.content.cloneNode(true)
    const wrapper = content.querySelector(".question-field-wrapper")
    const timestamp = Date.now()
    wrapper.innerHTML = wrapper.innerHTML.replaceAll("NEW_RECORD", timestamp)
    this.questionListTarget.appendChild(content)
    this.updatePositions()
    this.updateCount()
    this.onQuestionAdded(wrapper)
  }

  // Hook: called after a new question wrapper is added to the DOM
  onQuestionAdded(wrapper) {}

  insertQuestionBelow(event) {
    const template = this.questionTemplateTarget
    const content = template.content.cloneNode(true)
    const wrapper = content.querySelector(".question-field-wrapper")
    const timestamp = Date.now()
    wrapper.innerHTML = wrapper.innerHTML.replaceAll("NEW_RECORD", timestamp)
    const currentWrapper = event.target.closest(".question-field-wrapper")
    currentWrapper.after(content.querySelector(".question-field-wrapper") || wrapper)
    this.updatePositions()
    this.updateCount()
  }

  removeQuestion(event) {
    const wrapper = event.target.closest(".question-field-wrapper")
    if (!wrapper) return
    const destroyField = wrapper.querySelector("input[name*='[_destroy]']")
    if (destroyField) {
      destroyField.value = "1"
      wrapper.style.display = "none"
    } else {
      wrapper.remove()
    }
    this.updatePositions()
    this.updateCount()
  }

  moveUp(event) {
    const wrapper = event.target.closest(".question-field-wrapper")
    const prev = this.previousVisibleWrapper(wrapper)
    if (prev) { this.questionListTarget.insertBefore(wrapper, prev) }
    this.updatePositions()
  }

  moveDown(event) {
    const wrapper = event.target.closest(".question-field-wrapper")
    const next = this.nextVisibleWrapper(wrapper)
    if (next) { next.after(wrapper) }
    this.updatePositions()
  }

  // --- Options ---
  addOption(event) {
    const wrapper = event.target.closest(".question-field-wrapper")
    const container = wrapper.querySelector("[data-" + this.identifier.replace(/-/g, "_") + "-target='optionsContainer']") ||
                      wrapper.querySelector("[data-question-list-editor-target='optionsContainer']")
    const rows = container.querySelectorAll("[data-question-list-editor-target='optionRow'], [data-trivia-editor-target='optionRow'], [data-poll-editor-target='optionRow']")
    if (rows.length >= 4) return
    const index = rows.length
    const letter = String.fromCharCode(65 + index)
    const newRow = this.buildOptionRow(wrapper, index, letter)
    const addBtn = container.querySelector("[data-question-list-editor-target='addOptionButton'], [data-trivia-editor-target='addOptionButton'], [data-poll-editor-target='addOptionButton']")
    container.insertBefore(newRow, addBtn)
    if (rows.length + 1 >= 4) { addBtn && (addBtn.style.display = "none") }
    this.onOptionAdded(wrapper, index)
  }

  removeOption(event) {
    const row = event.target.closest("[data-question-list-editor-target='optionRow'], [data-trivia-editor-target='optionRow'], [data-poll-editor-target='optionRow']")
    if (!row) return
    row.remove()
    this.relabelOptions(event.target.closest(".question-field-wrapper"))
    this.onOptionRemoved(event.target.closest(".question-field-wrapper"))
  }

  // Hook: called after an option is added, for subclass sync (e.g. correct-answer buttons)
  onOptionAdded(wrapper, index) {}
  onOptionRemoved(wrapper) {}

  relabelOptions(wrapper) {
    if (!wrapper) return
    const rows = wrapper.querySelectorAll("[data-question-list-editor-target='optionRow'], [data-trivia-editor-target='optionRow'], [data-poll-editor-target='optionRow']")
    rows.forEach((row, i) => {
      const letter = row.querySelector("[data-question-list-editor-target='optionLetter'], [data-trivia-editor-target='optionLetter'], [data-poll-editor-target='optionLetter']")
      if (letter) letter.textContent = String.fromCharCode(65 + i)
    })
    const addBtn = wrapper.querySelector("[data-question-list-editor-target='addOptionButton'], [data-trivia-editor-target='addOptionButton'], [data-poll-editor-target='addOptionButton']")
    if (addBtn) addBtn.style.display = rows.length < 4 ? "" : "none"
  }

  buildOptionRow(wrapper, index, letter) {
    // Subclasses may override for custom row markup.
    // Default: infer field name from existing rows.
    const rows = wrapper.querySelectorAll("[data-question-list-editor-target='optionRow'], [data-trivia-editor-target='optionRow'], [data-poll-editor-target='optionRow']")
    const existingInput = rows[0]?.querySelector("input[type='text']")
    const existingName = existingInput?.name || ""
    const newName = existingName.replace(/\[\d+\]$/, `[${index}]`).replace(/\[\]$/, "[]")
    const div = document.createElement("div")
    div.setAttribute("data-question-list-editor-target", "optionRow")
    div.className = "flex items-center gap-2"
    div.innerHTML = `
      <span class="inline-flex items-center justify-center w-6 h-6 bg-blue-500/20 text-blue-300 font-bold text-xs rounded flex-shrink-0" data-question-list-editor-target="optionLetter">${letter}</span>
      <input type="text" name="${newName}" placeholder="Option ${letter}"
             data-question-list-editor-target="optionField"
             class="flex-1 rounded-lg bg-white/10 border border-white/10 focus:border-orange-500 focus:ring focus:ring-orange-500/20 text-sm font-medium text-white placeholder-white/30 transition-all px-3 py-2">
      <button type="button" data-action="question-list-editor#removeOption"
              class="text-white/20 hover:text-red-400 p-1 rounded hover:bg-red-500/10 transition-colors" aria-label="Remove option">
        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
      </button>
    `
    return div
  }

  // --- Positions & Count ---
  updatePositions() {
    const wrappers = this.visibleWrappers()
    wrappers.forEach((wrapper, index) => {
      const posField = wrapper.querySelector("[data-question-list-editor-target='positionField'], [data-trivia-editor-target='positionField'], [data-poll-editor-target='positionField']")
      if (posField) posField.value = index
      const badge = wrapper.querySelector("[data-question-list-editor-target='positionBadge'], [data-trivia-editor-target='positionBadge'], [data-poll-editor-target='positionBadge']")
      if (badge) badge.textContent = index + 1
    })
  }

  updateCount() {
    const count = this.visibleWrappers().length
    if (this.hasCountDisplayTarget) {
      this.countDisplayTargets.forEach(el => { el.textContent = count })
    }
  }

  // --- Helpers ---
  visibleWrappers() {
    return Array.from(
      this.questionListTarget.querySelectorAll(".question-field-wrapper")
    ).filter(el => el.style.display !== "none")
  }

  previousVisibleWrapper(el) {
    let prev = el.previousElementSibling
    while (prev) {
      if (prev.classList.contains("question-field-wrapper") && prev.style.display !== "none") return prev
      prev = prev.previousElementSibling
    }
    return null
  }

  nextVisibleWrapper(el) {
    let next = el.nextElementSibling
    while (next) {
      if (next.classList.contains("question-field-wrapper") && next.style.display !== "none") return next
      next = next.nextElementSibling
    }
    return null
  }

  escapeHtml(str) {
    return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
  }
}
```

**Note:** The drag/drop methods (dragStart, dragEnd, dragOver, dragEnter, dragLeave, drop), and collapse methods (toggleCollapse, toggleCollapseAll, collapseCards, expandCards) should be copied verbatim from `trivia_editor_controller.js` — they are structurally identical and belong in the shared base.

- [ ] **Step 3: Slim trivia_editor_controller.js to trivia-only concerns**

Replace `trivia_editor_controller.js` with a subclass that imports the shared base and adds only trivia-specific functionality: correct answer sync, image management.

```javascript
import QuestionListEditorController from "./question_list_editor_controller"

export default class extends QuestionListEditorController {
  static targets = [
    // Inherit all base targets via the superclass static definition (copy them here too
    // since Stimulus merges static targets per class, not via inheritance)
    "questionList", "questionTemplate", "countDisplay",
    "questionField", "optionField", "positionField", "positionBadge",
    "optionRow", "optionLetter", "optionsContainer", "addOptionButton",
    "collapsibleContent", "collapseAllButton",
    // Trivia-only
    "correctAnswersContainer", "correctAnswerButtons",
    "imagePreview", "imageInput", "existingImageContainer",
    "imageCountDisplay", "imageCountWarning"
  ]
  static values = {
    ratio: { type: Number, default: 1 },
    imageLimit: { type: Number, default: 20 }
  }

  onConnect() {
    this.updateImageCount()
  }

  onOptionAdded(wrapper, index) {
    this.syncCorrectAnswerButtons(wrapper)
  }

  onOptionRemoved(wrapper) {
    this.syncCorrectAnswerButtons(wrapper)
  }

  // --- Correct Answers ---
  updateCorrectAnswers(event) {
    // (copy verbatim from existing trivia_editor_controller.js#updateCorrectAnswers)
  }

  syncCorrectAnswerButtons(wrapper) {
    // (copy verbatim from existing trivia_editor_controller.js#syncCorrectAnswerButtons)
  }

  optionChanged(event) {
    // (copy verbatim from existing trivia_editor_controller.js#optionChanged)
  }

  // --- Images ---
  previewImage(event) {
    // (copy verbatim from existing trivia_editor_controller.js#previewImage)
  }

  removeImage(event) {
    // (copy verbatim from existing trivia_editor_controller.js#removeImage)
  }

  updateImageCount() {
    // (copy verbatim from existing trivia_editor_controller.js#updateImageCount)
  }
}
```

- [ ] **Step 4: Verify trivia pack editor still works**

```bash
TEST_ENV_NUMBER=2 bin/rspec spec/system/trivia_packs_spec.rb --format documentation
```

If no system spec exists for the trivia pack editor, manually smoke test: open the app, create/edit a trivia pack, add/remove questions, reorder, set correct answers. Confirm no JS errors.

- [ ] **Step 5: Commit**

```bash
git add app/javascript/controllers/question_list_editor_controller.js \
        app/javascript/controllers/trivia_editor_controller.js
git commit -m "refactor: extract shared question_list_editor_controller from trivia_editor"
```

---

## Task 2: Migrations — Pack & Questions

**Files:**
- Create: `db/migrate/..._create_poll_packs.rb`
- Create: `db/migrate/..._create_poll_questions.rb`

- [ ] **Step 1: Generate the migrations**

```bash
bin/rails generate migration CreatePollPacks name:string status:integer user:references
bin/rails generate migration CreatePollQuestions body:text options:jsonb position:integer poll_pack:references
```

- [ ] **Step 2: Edit the poll_packs migration to add defaults**

Open the generated `db/migrate/..._create_poll_packs.rb` and ensure it looks like:

```ruby
class CreatePollPacks < ActiveRecord::Migration[8.1]
  def change
    create_table :poll_packs do |t|
      t.string :name
      t.integer :status, default: 0
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
```

- [ ] **Step 3: Edit the poll_questions migration**

```ruby
class CreatePollQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :poll_questions do |t|
      t.text :body
      t.jsonb :options
      t.integer :position
      t.references :poll_pack, null: false, foreign_key: true

      t.timestamps
    end
  end
end
```

- [ ] **Step 4: Run migrations**

```bash
bin/rails db:migrate
TEST_ENV_NUMBER=2 bin/rails db:test:prepare
```

Expected: migrations run, `poll_packs` and `poll_questions` tables created.

- [ ] **Step 5: Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "feat: add poll_packs and poll_questions migrations"
```

---

## Task 3: PollPack and PollQuestion Models

**Files:**
- Create: `app/models/poll_pack.rb`
- Create: `app/models/poll_question.rb`
- Create: `spec/models/poll_pack_spec.rb` (basic)

- [ ] **Step 1: Write the failing model spec**

Create `spec/models/poll_pack_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe PollPack, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:poll_questions).dependent(:destroy) }
    it { is_expected.to belong_to(:user).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".default" do
    it "returns a default pack when none exists" do
      pack = PollPack.default
      expect(pack).to be_a(PollPack)
    end
  end
end
```

- [ ] **Step 2: Run to confirm failure**

```bash
TEST_ENV_NUMBER=2 bin/rspec spec/models/poll_pack_spec.rb --format documentation
```

Expected: fails with `uninitialized constant PollPack`.

- [ ] **Step 3: Create PollPack model**

Create `app/models/poll_pack.rb`:

```ruby
class PollPack < ApplicationRecord
  belongs_to :user, optional: true
  has_many :poll_questions, dependent: :destroy
  accepts_nested_attributes_for :poll_questions, allow_destroy: true

  enum :status, { draft: 0, live: 1 }, default: :live

  validates :name, presence: true

  def self.default
    find_by(name: "Default Poll Pack") ||
      create!(name: "Default Poll Pack", status: :live)
  end
end
```

- [ ] **Step 4: Create PollQuestion model**

Create `app/models/poll_question.rb`:

```ruby
class PollQuestion < ApplicationRecord
  belongs_to :poll_pack

  validates :body, presence: true
  validates :options, presence: true

  def vote_counts(poll_answers)
    options.each_with_object({}) do |option, counts|
      counts[option] = poll_answers.where(selected_option: option).count
    end
  end

  def vote_percentage(option, poll_answers)
    total = poll_answers.count
    return 0 if total.zero?

    count = poll_answers.where(selected_option: option).count
    ((count.to_f / total) * 100).round
  end
end
```

- [ ] **Step 5: Run specs**

```bash
TEST_ENV_NUMBER=2 bin/rspec spec/models/poll_pack_spec.rb --format documentation
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add app/models/poll_pack.rb app/models/poll_question.rb spec/models/poll_pack_spec.rb
git commit -m "feat: add PollPack and PollQuestion models"
```

---

## Task 4: PollGame Migration and Model

**Files:**
- Create: `db/migrate/..._create_poll_games.rb`
- Create: `db/migrate/..._create_poll_answers.rb`
- Create: `app/models/poll_game.rb`
- Create: `app/models/poll_answer.rb`
- Create: `spec/models/poll_game_spec.rb`
- Create: `spec/models/poll_answer_spec.rb`

- [ ] **Step 1: Generate migrations**

```bash
bin/rails generate migration CreatePollGames \
  status:string \
  scoring_mode:string \
  current_question_index:integer \
  question_count:integer \
  time_limit:integer \
  timer_enabled:boolean \
  timer_increment:integer \
  host_chosen_answer:string \
  round_started_at:datetime \
  round_closed_at:datetime \
  poll_pack:references

bin/rails generate migration CreatePollAnswers \
  selected_option:string \
  points_awarded:integer \
  submitted_at:datetime \
  player:references \
  poll_game:references \
  poll_question:references
```

- [ ] **Step 2: Edit poll_games migration**

```ruby
class CreatePollGames < ActiveRecord::Migration[8.1]
  def change
    create_table :poll_games do |t|
      t.string :status
      t.string :scoring_mode, null: false, default: "majority"
      t.integer :current_question_index, default: 0
      t.integer :question_count, default: 5
      t.integer :time_limit, default: 20
      t.boolean :timer_enabled, default: false
      t.integer :timer_increment
      t.string :host_chosen_answer
      t.datetime :round_started_at
      t.datetime :round_closed_at
      t.references :poll_pack, foreign_key: true

      t.timestamps
    end
  end
end
```

- [ ] **Step 3: Edit poll_answers migration**

```ruby
class CreatePollAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :poll_answers do |t|
      t.string :selected_option
      t.integer :points_awarded, default: 0
      t.datetime :submitted_at
      t.references :player, null: false, foreign_key: true
      t.references :poll_game, null: false, foreign_key: true
      t.references :poll_question, null: false, foreign_key: true

      t.timestamps
    end

    add_index :poll_answers, [ :player_id, :poll_question_id ], unique: true
  end
end
```

- [ ] **Step 4: Run migrations**

```bash
bin/rails db:migrate
TEST_ENV_NUMBER=2 bin/rails db:test:prepare
```

- [ ] **Step 5: Write model specs**

Create `spec/models/poll_game_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe PollGame, type: :model do
  let(:room) { create(:room, game_type: "Poll Game") }
  let(:pack) { create(:poll_pack) }
  let(:game) { create(:poll_game, poll_pack: pack) }

  describe "AASM states" do
    it "starts in instructions" do
      expect(game.status).to eq("instructions")
    end

    it "transitions instructions -> waiting via start_game!" do
      game.start_game!
      expect(game).to be_waiting
    end

    it "transitions waiting -> answering via start_question!" do
      game.start_game!
      game.start_question!
      expect(game).to be_answering
    end

    it "transitions answering -> reviewing via close_round!" do
      game.start_game!
      game.start_question!
      game.close_round!
      expect(game).to be_reviewing
    end

    it "transitions reviewing -> finished via finish_game!" do
      game.start_game!
      game.start_question!
      game.close_round!
      game.finish_game!
      expect(game).to be_finished
    end
  end

  describe "#questions_remaining?" do
    it "returns true when more questions follow current index" do
      create(:poll_question, poll_pack: pack)
      create(:poll_question, poll_pack: pack)
      game.update!(question_count: 2)
      expect(game.questions_remaining?).to be true
    end
  end

  describe "#majority_option" do
    let(:question) { create(:poll_question, poll_pack: pack, options: ["dogs", "cats", "neither"]) }
    let(:players) { create_list(:player, 3, room: room) }

    it "returns the option with the most votes" do
      create(:poll_answer, poll_game: game, poll_question: question, player: players[0], selected_option: "dogs")
      create(:poll_answer, poll_game: game, poll_question: question, player: players[1], selected_option: "dogs")
      create(:poll_answer, poll_game: game, poll_question: question, player: players[2], selected_option: "cats")
      expect(game.majority_option(question)).to eq("dogs")
    end

    it "returns nil on a perfect tie" do
      create(:poll_answer, poll_game: game, poll_question: question, player: players[0], selected_option: "dogs")
      create(:poll_answer, poll_game: game, poll_question: question, player: players[1], selected_option: "cats")
      expect(game.majority_option(question)).to be_nil
    end
  end
end
```

Create `spec/models/poll_answer_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe PollAnswer, type: :model do
  describe "#calculate_points" do
    let(:game) { create(:poll_game) }
    let(:question) { create(:poll_question, poll_pack: game.poll_pack, options: ["a", "b"]) }
    let(:player) { create(:player) }

    it "returns MAXIMUM_POINTS for an instant answer" do
      answer = build(:poll_answer, poll_game: game, poll_question: question, player: player)
      round_started_at = 10.seconds.ago
      round_closed_at = Time.current
      answer.submitted_at = round_started_at + 0.1.seconds
      expect(answer.calculate_points(round_started_at:, round_closed_at:)).to eq(PollGame::MAXIMUM_POINTS)
    end

    it "returns MINIMUM_POINTS for a late answer" do
      answer = build(:poll_answer, poll_game: game, poll_question: question, player: player)
      round_started_at = 20.seconds.ago
      round_closed_at = Time.current
      answer.submitted_at = round_closed_at - 0.1.seconds
      points = answer.calculate_points(round_started_at:, round_closed_at:)
      expect(points).to be >= PollGame::MINIMUM_POINTS
      expect(points).to be <= PollGame::MAXIMUM_POINTS
    end
  end
end
```

- [ ] **Step 6: Run specs to confirm failure**

```bash
TEST_ENV_NUMBER=2 bin/rspec spec/models/poll_game_spec.rb spec/models/poll_answer_spec.rb --format documentation
```

Expected: fails with `uninitialized constant PollGame`.

- [ ] **Step 7: Create PollGame model**

Create `app/models/poll_game.rb`:

```ruby
class PollGame < ApplicationRecord
  include AASM
  include HasRoundTimer

  MAXIMUM_POINTS = 1000
  MINIMUM_POINTS = 100
  DECAY_FACTOR = 0.9
  GRACE_PERIOD = 0.5.seconds

  attr_accessor :previous_top_player_ids

  has_one :room, as: :current_game
  belongs_to :poll_pack, optional: true
  has_many :poll_answers, dependent: :destroy
  has_many :game_events, as: :eventable, dependent: :destroy

  enum :scoring_mode, { majority: "majority", minority: "minority", host_choose: "host_choose" }

  def self.supports_response_moderation?
    false
  end

  aasm column: :status, whiny_transitions: false do
    state :instructions, initial: true
    state :waiting
    state :answering
    state :reviewing
    state :finished

    event :start_game do
      transitions from: :instructions, to: :waiting
    end

    event :start_question do
      transitions from: [ :waiting, :reviewing ], to: :answering, after: :record_round_start
    end

    event :close_round do
      transitions from: :answering, to: :reviewing, after: :record_round_close
    end

    event :next_question do
      transitions from: :reviewing, to: :reviewing, after: :increment_question_index
    end

    event :finish_game do
      transitions from: [ :instructions, :waiting, :answering, :reviewing ], to: :finished
    end
  end

  def current_question
    questions_for_game.find_by(position: current_question_index)
  end

  def questions_remaining?
    current_question_index < questions_for_game.count - 1
  end

  def all_answers_submitted?
    return false if current_question.nil?

    submitted_count = poll_answers.where(poll_question: current_question).count
    players_count = room&.players&.active_players&.count || 0
    submitted_count >= players_count && players_count > 0
  end

  # Returns the winning option for the current question based on scoring_mode.
  # Returns nil if no clear winner (perfect tie in majority/minority).
  def majority_option(question)
    answers = poll_answers.where(poll_question: question)
    counts = question.options.index_with { |opt| answers.where(selected_option: opt).count }
    max = counts.values.max
    return nil if max.zero?

    winners = counts.select { |_opt, count| count == max }.keys
    winners.length == 1 ? winners.first : nil
  end

  def calculate_scores!
    room.players.active_players.each do |player|
      score = poll_answers.where(player:).sum(:points_awarded)
      player.update!(score:)
    end
  end

  def total_points_for(player)
    poll_answers.where(player:).sum(:points_awarded)
  end

  def score_reveal_for(player:)
    question = current_question
    answer = question ? poll_answers.find_by(player:, poll_question: question) : nil
    round_points = answer&.points_awarded.to_i
    total = total_points_for(player)

    players = room.players.active_players.to_a
    points_by_player = poll_answers.where(poll_question: question)
      .each_with_object({}) { |a, h| h[a.player_id] = a.points_awarded.to_i }

    ranked_now  = players.sort_by { |p| -p.score }
    ranked_prev = players.sort_by { |p| -(p.score - points_by_player.fetch(p.id, 0)) }
    rank      = ranked_now.index  { |p| p.id == player.id }.to_i + 1
    prev_rank = ranked_prev.index { |p| p.id == player.id }.to_i + 1

    winner = majority_option(question) if question
    winner = host_chosen_answer if host_choose? && host_chosen_answer.present?

    did_win = if winner.nil?
      false
    elsif host_choose?
      answer&.selected_option == winner
    elsif majority?
      answer&.selected_option == winner
    else # minority
      answer.present? && answer.selected_option != winner
    end

    {
      answer:,
      winner:,
      did_win:,
      round_points:,
      score_from: total - round_points,
      score_to: total,
      rank:,
      rank_improved: rank <= prev_rank
    }
  end

  def round
    current_question_index
  end

  def process_timeout(job_question_index, _step_number)
    return unless current_question_index == job_question_index
    return unless answering?

    Games::Poll.handle_timeout(game: self)
  end

  private

  def questions_for_game
    poll_pack&.poll_questions&.order(:position) || PollQuestion.none
  end

  def record_round_start
    update!(round_started_at: Time.current, round_closed_at: nil, host_chosen_answer: nil)
  end

  def record_round_close
    update!(round_closed_at: Time.current)
  end

  def increment_question_index
    increment!(:current_question_index)
  end
end
```

- [ ] **Step 8: Create PollAnswer model**

Create `app/models/poll_answer.rb`:

```ruby
class PollAnswer < ApplicationRecord
  belongs_to :player
  belongs_to :poll_game
  belongs_to :poll_question

  validates :selected_option, presence: true

  def calculate_points(round_started_at:, round_closed_at:)
    deadline = round_closed_at + PollGame::GRACE_PERIOD
    return 0 if submitted_at > deadline

    duration = round_closed_at - round_started_at
    return PollGame::MAXIMUM_POINTS if duration <= 0

    elapsed = [ submitted_at - round_started_at, 0 ].max
    raw = PollGame::MAXIMUM_POINTS * (1 - (elapsed / duration.to_f) * PollGame::DECAY_FACTOR)
    [ raw.floor, PollGame::MINIMUM_POINTS ].max
  end
end
```

- [ ] **Step 9: Run specs**

```bash
TEST_ENV_NUMBER=2 bin/rspec spec/models/poll_game_spec.rb spec/models/poll_answer_spec.rb --format documentation
```

Expected: all pass.

- [ ] **Step 10: Commit**

```bash
git add app/models/poll_game.rb app/models/poll_answer.rb \
        spec/models/poll_game_spec.rb spec/models/poll_answer_spec.rb \
        db/migrate/ db/schema.rb
git commit -m "feat: add PollGame and PollAnswer models with AASM state machine"
```

---

## Task 5: Games::Poll Service Module

**Files:**
- Create: `app/services/games/poll.rb`
- Create: `spec/services/games/poll_spec.rb`

- [ ] **Step 1: Write failing service specs**

Create `spec/services/games/poll_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Games::Poll do
  let(:room) { create(:room, game_type: "Poll Game") }
  let(:pack) { create(:poll_pack) }
  let!(:q1) { create(:poll_question, poll_pack: pack, options: ["dogs", "cats"]) }
  let!(:q2) { create(:poll_question, poll_pack: pack, options: ["pizza", "tacos"]) }
  let(:players) { create_list(:player, 3, room:) }
  let(:game) { room.current_game.reload }

  before do
    room.update!(poll_pack: pack)
    players # create players
    Games::Poll.game_started(room:, question_count: 2, scoring_mode: "majority",
                             timer_enabled: false, show_instructions: false)
  end

  describe ".game_started" do
    it "creates a PollGame and sets it as current game" do
      expect(room.current_game).to be_a(PollGame)
    end

    it "skips instructions when show_instructions is false" do
      expect(game).to be_waiting
    end
  end

  describe ".start_question" do
    it "transitions game to answering" do
      Games::Poll.start_question(game:)
      expect(game.reload).to be_answering
    end
  end

  describe ".submit_answer" do
    before { Games::Poll.start_question(game:) }

    it "creates a PollAnswer" do
      expect {
        Games::Poll.submit_answer(game:, player: players[0], selected_option: "dogs")
      }.to change(PollAnswer, :count).by(1)
    end

    it "is idempotent — second submission returns existing answer" do
      Games::Poll.submit_answer(game:, player: players[0], selected_option: "dogs")
      expect {
        Games::Poll.submit_answer(game:, player: players[0], selected_option: "cats")
      }.not_to change(PollAnswer, :count)
    end
  end

  describe ".close_round — majority mode" do
    before do
      Games::Poll.start_question(game:)
      Games::Poll.submit_answer(game:, player: players[0], selected_option: "dogs")
      Games::Poll.submit_answer(game:, player: players[1], selected_option: "dogs")
      Games::Poll.submit_answer(game:, player: players[2], selected_option: "cats")
    end

    it "transitions to reviewing" do
      Games::Poll.close_round(game:)
      expect(game.reload).to be_reviewing
    end

    it "awards points to majority players only" do
      Games::Poll.close_round(game:)
      dogs_answers = PollAnswer.where(player: players[0..1], poll_question: q1)
      cats_answer  = PollAnswer.find_by(player: players[2], poll_question: q1)
      expect(dogs_answers.map(&:points_awarded)).to all(be > 0)
      expect(cats_answer.points_awarded).to eq(0)
    end

    it "awards no points on perfect tie" do
      game2 = create(:poll_game, poll_pack: pack, scoring_mode: "majority")
      room.update!(current_game: game2)
      Games::Poll.start_question(game: game2)
      p1, p2 = players[0..1]
      Games::Poll.submit_answer(game: game2, player: p1, selected_option: "dogs")
      Games::Poll.submit_answer(game: game2, player: p2, selected_option: "cats")
      Games::Poll.close_round(game: game2)
      answers = PollAnswer.where(poll_game: game2, poll_question: q1)
      expect(answers.map(&:points_awarded)).to all(eq(0))
    end
  end

  describe ".close_round — minority mode" do
    before do
      game.update!(scoring_mode: "minority")
      Games::Poll.start_question(game:)
      Games::Poll.submit_answer(game:, player: players[0], selected_option: "dogs")
      Games::Poll.submit_answer(game:, player: players[1], selected_option: "dogs")
      Games::Poll.submit_answer(game:, player: players[2], selected_option: "cats")
    end

    it "awards points to the minority player only" do
      Games::Poll.close_round(game:)
      cats_answer  = PollAnswer.find_by(player: players[2], poll_question: q1)
      dogs_answers = PollAnswer.where(player: players[0..1], poll_question: q1)
      expect(cats_answer.points_awarded).to be > 0
      expect(dogs_answers.map(&:points_awarded)).to all(eq(0))
    end
  end

  describe ".set_host_answer — host_choose mode" do
    before do
      game.update!(scoring_mode: "host_choose")
      Games::Poll.start_question(game:)
      Games::Poll.submit_answer(game:, player: players[0], selected_option: "dogs")
      Games::Poll.submit_answer(game:, player: players[1], selected_option: "cats")
      Games::Poll.submit_answer(game:, player: players[2], selected_option: "cats")
      Games::Poll.close_round(game:)
    end

    it "sets host_chosen_answer and scores accordingly" do
      Games::Poll.set_host_answer(game:, answer: "cats")
      game.reload
      expect(game.host_chosen_answer).to eq("cats")
      cats_answers = PollAnswer.where(player: players[1..2], poll_question: q1)
      dogs_answer  = PollAnswer.find_by(player: players[0], poll_question: q1)
      expect(cats_answers.map(&:points_awarded)).to all(be > 0)
      expect(dogs_answer.points_awarded).to eq(0)
    end
  end
end
```

- [ ] **Step 2: Run to confirm failure**

```bash
TEST_ENV_NUMBER=2 bin/rspec spec/services/games/poll_spec.rb --format documentation
```

Expected: fails with `uninitialized constant Games::Poll`.

- [ ] **Step 3: Create the service module**

Create `app/services/games/poll.rb`:

```ruby
module Games
  module Poll
    DEFAULT_QUESTION_COUNT = 5
    DEFAULT_TIME_LIMIT = 20

    def self.requires_capacity_check? = false

    def self.game_started(room:, question_count: DEFAULT_QUESTION_COUNT, time_limit: DEFAULT_TIME_LIMIT,
                          scoring_mode: "majority", timer_enabled: false, timer_increment: nil,
                          show_instructions: true, **_extra)
      return if room.current_game.present?

      effective_time_limit = timer_increment.presence || time_limit
      pack = room.poll_pack || PollPack.default

      game = PollGame.create!(
        poll_pack: pack,
        scoring_mode:,
        question_count:,
        time_limit: effective_time_limit,
        timer_enabled:
      )
      room.update!(current_game: game)

      assign_questions(game:, question_count:)
      GameEvent.log(game, "game_created", game_type: room.game_type,
                    player_count: room.players.active_players.count,
                    scoring_mode:, timer_enabled:)

      unless show_instructions
        game.start_game!
      end

      GameBroadcaster.broadcast_game_start(room:)
      GameBroadcaster.broadcast_stage(room:)
      GameBroadcaster.broadcast_hand(room:)
    end

    def self.start_from_instructions(game:)
      game.with_lock { game.start_game! }
      GameEvent.log(game, "state_changed", from: "instructions", to: game.status)
      broadcast_all(game)
    end

    def self.start_question(game:)
      game.start_question!
      GameEvent.log(game, "state_changed", from: "waiting", to: "answering")
      start_timer_if_enabled(game)
      broadcast_all(game)
    end

    def self.submit_answer(game:, player:, selected_option:)
      question = game.current_question
      return if question.nil?

      existing = PollAnswer.find_by(player:, poll_question: question, poll_game: game)
      return existing if existing.present?

      answer = PollAnswer.new(
        player:,
        poll_game: game,
        poll_question: question,
        selected_option:,
        submitted_at: Time.current
      )

      begin
        answer.save!
      rescue ActiveRecord::RecordNotUnique
        return PollAnswer.find_by!(player:, poll_question: question, poll_game: game)
      end

      broadcast_all(game)
      answer
    end

    def self.close_round(game:)
      game.with_lock do
        return unless game.answering?

        game.previous_top_player_ids = game.room.players.active_players
          .order(score: :desc).limit(4).pluck(:id)
        game.close_round!

        # For majority and minority: score immediately.
        # For host_choose: defer scoring until host calls set_host_answer.
        score_current_round(game) unless game.host_choose?
        game.calculate_scores! unless game.host_choose?
      end
      GameEvent.log(game, "state_changed", from: "answering", to: "reviewing")
      broadcast_all(game)
    end

    def self.set_host_answer(game:, answer:)
      game.with_lock do
        return unless game.reviewing?
        return unless game.host_choose?

        game.update!(host_chosen_answer: answer)
        score_current_round(game)
        game.calculate_scores!
      end
      broadcast_all(game)
    end

    def self.next_question(game:)
      game.with_lock do
        if game.questions_remaining?
          game.next_question!
          start_question(game:)
        else
          game.previous_top_player_ids = game.room.players.active_players
            .order(score: :desc).limit(4).pluck(:id)
          game.calculate_scores!
          game.finish_game!
          GameEvent.log(game, "game_finished",
            duration_seconds: (Time.current - game.created_at).to_i,
            player_count: game.room.players.active_players.count)
          game.room.finish!
          broadcast_all(game)
        end
      end
    end

    def self.handle_timeout(game:)
      return unless game.answering?

      close_round(game:)
    end

    # --- Private ---

    def self.assign_questions(game:, question_count:)
      pack = game.poll_pack || PollPack.default
      questions = pack.poll_questions.order(:position).limit(question_count).to_a

      raise "Not enough poll questions to start game." if questions.size < question_count

      questions.each_with_index do |question, index|
        # Questions are referenced directly (no snapshot instance needed for polls)
        # We track position via current_question_index
        question.update!(position: index) if question.position != index
      end
    end

    def self.score_current_round(game)
      question = game.current_question
      return unless question

      answers = game.poll_answers.where(poll_question: question)
      winner = determine_winner(game, question, answers)

      answers.find_each do |answer|
        # winner.nil? means a perfect tie — no points for anyone, regardless of mode
        won = if winner.nil?
          false
        elsif game.host_choose?
          answer.selected_option == winner
        elsif game.majority?
          answer.selected_option == winner
        else # minority — score if NOT the majority option; nil guard already handled above
          answer.selected_option != winner
        end

        points = if won
          answer.calculate_points(
            round_started_at: game.round_started_at,
            round_closed_at: game.round_closed_at
          )
        else
          0
        end

        answer.update!(points_awarded: points)
      end
    end

    def self.determine_winner(game, question, answers)
      if game.host_choose?
        game.host_chosen_answer
      else
        game.majority_option(question)
      end
    end

    def self.start_timer_if_enabled(game)
      return unless game.timer_enabled?

      game.start_timer!(game.time_limit)
    end

    def self.broadcast_all(game)
      room = game.room
      GameBroadcaster.broadcast_stage(room:, game:)
      GameBroadcaster.broadcast_hand(room:)
      GameBroadcaster.broadcast_host_controls(room:)
    end

    private_class_method :assign_questions, :score_current_round, :determine_winner,
                         :start_timer_if_enabled, :broadcast_all

    module Playtest
      def self.start(room:)
        Games::Poll.game_started(room:, show_instructions: true, timer_enabled: false)
      end

      def self.advance(game:)
        case game.status
        when "instructions" then Games::Poll.start_from_instructions(game:)
        when "waiting"      then Games::Poll.start_question(game:)
        when "answering"    then Games::Poll.close_round(game:)
        when "reviewing"
          if game.host_choose? && game.host_chosen_answer.blank?
            # Auto-pick first option for playtest
            question = game.current_question
            Games::Poll.set_host_answer(game:, answer: question&.options&.first)
          else
            Games::Poll.next_question(game:)
          end
        end
      end

      def self.bot_act(game:, exclude_player:)
        return unless game.answering?

        question = game.current_question
        return unless question

        bots = game.room.players
        bots = bots.where.not(id: exclude_player.id) if exclude_player

        bots.each do |bot|
          next if PollAnswer.exists?(player: bot, poll_question: question, poll_game: game)

          option = question.options.sample
          Games::Poll.submit_answer(game:, player: bot, selected_option: option)
        end
      end

      def self.auto_play_step(game:)
        case game.status
        when "instructions" then Games::Poll.start_from_instructions(game:)
        when "waiting"      then Games::Poll.start_question(game:)
        when "answering"
          bot_act(game:, exclude_player: nil)
          game.reload
          Games::Poll.close_round(game:) if game.answering?
        when "reviewing"
          advance(game:)
        end
      end

      def self.progress_label(game:)
        total = game.poll_pack&.poll_questions&.count || 0
        "Question #{game.current_question_index + 1} of #{total}"
      end

      def self.dashboard_actions(status)
        case status
        when "lobby"        then [ { label: "Start Game", action: :start, style: :primary } ]
        when "instructions" then [ { label: "Skip Instructions", action: :advance, style: :primary } ]
        when "waiting"      then [ { label: "Start Question", action: :advance, style: :primary } ]
        when "answering"
          [
            { label: "Bots: Answer", action: :bot_act, style: :bot },
            { label: "Close Voting", action: :advance, style: :primary }
          ]
        when "reviewing"    then [ { label: "Next Question", action: :advance, style: :primary } ]
        when "finished"     then []
        else                     []
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run service specs**

```bash
TEST_ENV_NUMBER=2 bin/rspec spec/services/games/poll_spec.rb --format documentation
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/games/poll.rb spec/services/games/poll_spec.rb
git commit -m "feat: add Games::Poll service with majority/minority/host_choose scoring"
```

---

## Task 6: Controllers, Routes, Registry, Room Constants

**Files:**
- Create: `app/controllers/poll_games/game_starts_controller.rb`
- Create: `app/controllers/poll_games/questions_controller.rb`
- Create: `app/controllers/poll_games/round_closures_controller.rb`
- Create: `app/controllers/poll_games/advancements_controller.rb`
- Create: `app/controllers/poll_games/host_answers_controller.rb`
- Create: `app/controllers/poll_answers_controller.rb`
- Modify: `config/routes.rb`
- Modify: `config/initializers/game_registry.rb`
- Modify: `app/models/room.rb`

- [ ] **Step 1: Create game_starts_controller.rb**

```ruby
# app/controllers/poll_games/game_starts_controller.rb
module PollGames
  class GameStartsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::Poll.start_from_instructions(game: @game)
      render_hand
    end

    private

    def set_game
      @game = PollGame.find(params[:poll_game_id])
    end
  end
end
```

- [ ] **Step 2: Create questions_controller.rb**

```ruby
# app/controllers/poll_games/questions_controller.rb
module PollGames
  class QuestionsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::Poll.start_question(game: @game)
      render_hand
    end

    private

    def set_game
      @game = PollGame.find(params[:poll_game_id])
    end
  end
end
```

- [ ] **Step 3: Create round_closures_controller.rb**

```ruby
# app/controllers/poll_games/round_closures_controller.rb
module PollGames
  class RoundClosuresController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::Poll.close_round(game: @game)
      render_hand
    end

    private

    def set_game
      @game = PollGame.find(params[:poll_game_id])
    end
  end
end
```

- [ ] **Step 4: Create advancements_controller.rb**

```ruby
# app/controllers/poll_games/advancements_controller.rb
module PollGames
  class AdvancementsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::Poll.next_question(game: @game)
      render_hand
    end

    private

    def set_game
      @game = PollGame.find(params[:poll_game_id])
    end
  end
end
```

- [ ] **Step 5: Create host_answers_controller.rb**

```ruby
# app/controllers/poll_games/host_answers_controller.rb
module PollGames
  class HostAnswersController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::Poll.set_host_answer(game: @game, answer: params[:answer])
      render_hand
    end

    private

    def set_game
      @game = PollGame.find(params[:poll_game_id])
    end
  end
end
```

- [ ] **Step 6: Create poll_answers_controller.rb**

```ruby
# app/controllers/poll_answers_controller.rb
class PollAnswersController < ApplicationController
  include RendersHand

  before_action :set_game

  def create
    Games::Poll.submit_answer(
      game: @game,
      player: current_player,
      selected_option: params[:poll_answer][:selected_option]
    )
    render_hand
  end

  private

  def set_game
    @game = PollGame.find(params[:poll_game_id])
  end
end
```

- [ ] **Step 7: Add routes**

In `config/routes.rb`, add after the `category_list_games` block:

```ruby
resources :poll_games, only: [] do
  scope module: :poll_games do
    resource :game_start, only: :create
    resource :question, only: :create
    resource :round_closure, only: :create
    resource :advancement, only: :create
    resources :host_answers, only: :create
  end
  resources :poll_answers, only: :create
end
```

- [ ] **Step 8: Update game registry**

In `config/initializers/game_registry.rb`, add:

```ruby
GameEventRouter.register_game("Poll Game", Games::Poll)
DevPlaytest::Registry.register(PollGame, Games::Poll::Playtest)
```

- [ ] **Step 9: Update Room constants**

In `app/models/room.rb`, update:

```ruby
POLL_GAME = "Poll Game".freeze

GAME_TYPES = [ WRITE_AND_VOTE, SPEED_TRIVIA, CATEGORY_LIST, POLL_GAME ].freeze

GAME_DISPLAY_NAMES = {
  WRITE_AND_VOTE => "Comedy Clash",
  SPEED_TRIVIA   => "Think Fast",
  CATEGORY_LIST  => "A-List",
  POLL_GAME      => "Bandwagon"
}.freeze
```

Also add to `room.rb` associations:

```ruby
belongs_to :poll_pack, optional: true
```

And add a migration for the poll_pack foreign key on rooms:

```bash
bin/rails generate migration AddPollPackToRooms poll_pack:references
```

Edit the migration to make it nullable:

```ruby
class AddPollPackToRooms < ActiveRecord::Migration[8.1]
  def change
    add_reference :rooms, :poll_pack, foreign_key: true, null: true
  end
end
```

```bash
bin/rails db:migrate
TEST_ENV_NUMBER=2 bin/rails db:test:prepare
```

- [ ] **Step 10: Verify routes load**

```bash
bin/rails routes | grep poll
```

Expected output includes: `poll_game_game_start`, `poll_game_question`, `poll_game_round_closure`, `poll_game_advancement`, `poll_game_host_answers`, `poll_game_poll_answers`.

- [ ] **Step 11: Commit**

```bash
git add app/controllers/poll_games/ app/controllers/poll_answers_controller.rb \
        config/routes.rb config/initializers/game_registry.rb \
        app/models/room.rb db/migrate/ db/schema.rb
git commit -m "feat: add PollGames controllers, routes, registry, and Room constants"
```

---

## Task 7: Stage Partials [CHECKPOINT]

**Files:**
- Create: `app/views/games/poll/_stage_instructions.html.erb`
- Create: `app/views/games/poll/_stage_waiting.html.erb`
- Create: `app/views/games/poll/_stage_answering.html.erb`
- Create: `app/views/games/poll/_stage_reviewing.html.erb`
- Create: `app/views/games/poll/_vote_summary.html.erb`
- Create: `app/views/games/poll/_stage_finished.html.erb`

All stage partials must follow `/stage-view` constraints: first child is `<div id="stage_<status>">`, all sizing in `text-vh-*`/`[Xvh]`, no inline `animate-*`, no scroll on stage root.

- [ ] **Step 1: Create _stage_instructions.html.erb**

```bash
mkdir -p app/views/games/poll
```

Create `app/views/games/poll/_stage_instructions.html.erb`:

```erb
<div id="stage_instructions" class="flex flex-col items-center justify-center flex-1">
  <div class="shrink-0 mb-[3vh] text-center">
    <h1 class="text-vh-5xl font-black text-white tracking-tight">Bandwagon</h1>
    <p class="text-vh-lg text-blue-200 mt-[1vh]">
      <%= case game.scoring_mode
          when "majority"   then "Go with the crowd. Score if you pick the most popular answer."
          when "minority"   then "Be the odd one out. Score if you pick the least popular answer."
          when "host_choose" then "Match the right answer. The host will reveal it after you vote."
          end %>
    </p>
  </div>

  <div class="bg-white/10 backdrop-blur-xl border border-white/20 rounded-3xl p-[3vh] max-w-2xl w-full text-center">
    <p class="text-vh-2xl text-white font-bold mb-[2vh]">How to play</p>
    <ul class="text-vh-lg text-blue-200 space-y-[1vh] text-left">
      <li>✦ Each round shows a question with multiple answers</li>
      <li>✦ Answer on your phone before time runs out</li>
      <li>✦ Faster answers earn bigger bonuses</li>
      <% if game.majority? %>
        <li>✦ Only players who picked the <span class="text-white font-bold">most popular</span> answer score</li>
      <% elsif game.minority? %>
        <li>✦ Only players who picked a <span class="text-white font-bold">less popular</span> answer score</li>
      <% else %>
        <li>✦ The host will reveal the <span class="text-white font-bold">correct answer</span> after voting</li>
      <% end %>
    </ul>
  </div>

  <div class="mt-[3vh] shrink-0">
    <p class="text-vh-xl text-blue-200 font-semibold">
      <%= room.players.active_players.count %> players ready
    </p>
  </div>
</div>
```

- [ ] **Step 2: Create _stage_waiting.html.erb**

Create `app/views/games/poll/_stage_waiting.html.erb`:

```erb
<div id="stage_waiting" class="flex flex-col items-center justify-center flex-1">
  <div class="shrink-0 mb-[2vh]">
    <span class="text-vh-2xl text-blue-200 font-bold uppercase tracking-widest">
      Question <%= game.current_question_index + 1 %> of <%= game.poll_pack&.poll_questions&.count %>
    </span>
  </div>

  <div class="bg-white/10 backdrop-blur-xl border border-white/20 rounded-3xl p-[4vh] max-w-xl w-full text-center">
    <div class="text-[8vh] mb-[2vh]">🗳️</div>
    <p class="text-vh-4xl font-black text-white mb-[1vh]">Get Ready!</p>
    <p class="text-vh-lg text-blue-200">
      <%= room.players.active_players.count %> players in the room
    </p>
  </div>
</div>
```

- [ ] **Step 3: Create _stage_answering.html.erb**

Create `app/views/games/poll/_stage_answering.html.erb`:

```erb
<div id="stage_answering" class="flex flex-col items-center justify-center flex-1">
  <% current_question = game.current_question %>

  <div class="mb-[2vh] shrink-0">
    <span class="text-vh-2xl text-blue-200 font-bold uppercase tracking-widest">
      Question <%= game.current_question_index + 1 %> of <%= game.poll_pack&.poll_questions&.count %>
    </span>
  </div>

  <div class="relative bg-white/10 backdrop-blur-xl border border-white/20 rounded-3xl p-[3vh] shadow-2xl text-center max-w-6xl w-full mb-[3vh]">
    <h2 class="text-vh-4xl font-black text-white leading-tight">
      <%= current_question&.body || "Loading question..." %>
    </h2>
  </div>

  <% grid_class = case current_question&.options&.size
                  when 1 then "grid-cols-1 max-w-md mx-auto"
                  when 3 then "grid-cols-3"
                  else "grid-cols-1 md:grid-cols-2"
                  end %>
  <div class="grid <%= grid_class %> gap-[2vh] w-full max-w-[120vh] px-[2vh]">
    <% current_question&.options&.each_with_index do |option, index| %>
      <div class="bg-gray-800/80 backdrop-blur-md border-2 border-gray-600 rounded-2xl p-[2vh] flex items-center shadow-lg">
        <div class="bg-white text-black font-black text-vh-3xl h-[6vh] w-[6vh] rounded-full flex items-center justify-center mr-[2vh] shrink-0 shadow-md">
          <%= (index + 65).chr %>
        </div>
        <p class="text-vh-xl text-white font-bold"><%= option %></p>
      </div>
    <% end %>
  </div>

  <div class="mt-[3vh] shrink-0 flex items-center gap-[3vh]">
    <p class="text-vh-xl text-blue-200 font-semibold">Answer on your device!</p>
    <% answers_count = game.poll_answers.where(poll_question: game.current_question).count %>
    <% players_count = room.players.active_players.count %>
    <p class="text-vh-lg text-blue-300">
      <%= answers_count %>/<%= players_count %> answered
    </p>
  </div>
</div>
```

- [ ] **Step 4: Create _vote_summary.html.erb**

Create `app/views/games/poll/_vote_summary.html.erb`:

```erb
<%# locals: question, poll_answers, winner %>
<% total = poll_answers.count %>
<% option_count = question.options.size %>

<% if option_count <= 2 %>
  <% colors = [
    { bg: "bg-blue-500/20", border: "border-blue-500", text: "text-blue-400" },
    { bg: "bg-purple-500/20", border: "border-purple-500", text: "text-purple-400" }
  ] %>
  <div class="flex gap-[2vh] max-w-4xl w-full shrink-0 justify-center">
    <% question.options.each_with_index do |option, index| %>
      <% votes = poll_answers.where(selected_option: option).count %>
      <% pct   = total > 0 ? ((votes.to_f / total) * 100).round : 0 %>
      <% is_winner = option == winner %>
      <% color = colors[index] || colors[0] %>

      <div class="<%= color[:bg] %> backdrop-blur-md border-2 <%= is_winner ? 'border-green-500 bg-green-500/10' : color[:border] %> rounded-2xl p-[2vh] flex flex-col items-center text-center gap-[1vh] flex-1 max-w-sm">
        <div class="bg-white text-black font-black text-vh-2xl h-[5vh] w-[5vh] rounded-full flex items-center justify-center shrink-0">
          <%= (index + 65).chr %>
        </div>
        <p class="text-vh-lg text-white font-bold"><%= option %></p>
        <div class="text-vh-4xl font-black <%= is_winner ? 'text-green-400' : color[:text] %> font-mono">
          <%= total > 0 ? "#{pct}%" : "—" %>
        </div>
        <div class="text-vh-sm text-gray-400"><%= votes %> <%= votes == 1 ? "vote" : "votes" %></div>
      </div>
    <% end %>
  </div>
<% else %>
  <div class="grid grid-cols-<%= option_count %> gap-[1.5vh] max-w-6xl w-full shrink-0">
    <% question.options.each_with_index do |option, index| %>
      <% votes = poll_answers.where(selected_option: option).count %>
      <% pct   = total > 0 ? ((votes.to_f / total) * 100).round : 0 %>
      <% is_winner = option == winner %>

      <div class="bg-black/40 backdrop-blur-md border-2 <%= is_winner ? 'border-green-500 bg-green-500/10' : 'border-gray-600' %> rounded-xl p-[1.5vh] flex flex-col items-center text-center gap-[0.5vh]">
        <div class="bg-white text-black font-black text-vh-lg h-[4vh] w-[4vh] rounded-full flex items-center justify-center shrink-0">
          <%= (index + 65).chr %>
        </div>
        <p class="text-vh-sm text-white font-bold line-clamp-2 flex-grow"><%= option %></p>
        <div class="text-vh-2xl font-black <%= is_winner ? 'text-green-400' : 'text-blue-300' %> font-mono">
          <%= total > 0 ? "#{pct}%" : "—" %>
        </div>
        <div class="text-vh-xs text-gray-400"><%= votes %> <%= votes == 1 ? "vote" : "votes" %></div>
      </div>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 5: Create _stage_reviewing.html.erb**

Create `app/views/games/poll/_stage_reviewing.html.erb`:

```erb
<div id="stage_reviewing" class="flex flex-col items-center flex-1 min-h-0 gap-[2vh]">
  <% current_question = game.current_question %>
  <% poll_answers = game.poll_answers.where(poll_question: current_question) %>
  <% winner = game.majority_option(current_question) if current_question %>
  <% winner = game.host_chosen_answer if game.host_choose? && game.host_chosen_answer.present? %>
  <% scores_ready = !game.host_choose? || game.host_chosen_answer.present? %>

  <div class="shrink-0">
    <span class="text-vh-base text-blue-200 font-bold uppercase tracking-widest">
      Question <%= game.current_question_index + 1 %> Results
    </span>
  </div>

  <div class="bg-white/10 backdrop-blur-xl border border-white/20 rounded-2xl p-[1.5vh] text-center max-w-6xl w-full shrink-0">
    <p class="text-vh-lg text-blue-200 mb-[0.5vh]"><%= current_question&.body %></p>
    <% if scores_ready && winner.present? %>
      <p class="text-vh-xl font-black text-green-400">✓ <%= winner %></p>
    <% elsif game.host_choose? && game.host_chosen_answer.blank? %>
      <p class="text-vh-lg text-yellow-300 font-bold">Waiting for host to reveal the answer…</p>
    <% else %>
      <p class="text-vh-lg text-yellow-300 font-bold">It's a tie — no points this round!</p>
    <% end %>
  </div>

  <%= render "games/poll/vote_summary", question: current_question, poll_answers:, winner: %>

  <% if scores_ready %>
    <%= render "games/speed_trivia/score_podium",
          game:, room:,
          previous_top_player_ids: local_assigns[:previous_top_player_ids] || [] %>
  <% end %>
</div>
```

- [ ] **Step 6: Create _stage_finished.html.erb**

Create `app/views/games/poll/_stage_finished.html.erb`:

```erb
<div id="stage_finished" class="flex flex-col items-center justify-center flex-1 gap-[2vh]">
  <div class="shrink-0 text-center">
    <h2 class="text-vh-4xl font-black text-white mb-[1vh]">Final Results</h2>
    <p class="text-vh-lg text-blue-200">Thanks for playing Bandwagon!</p>
  </div>

  <%= render "games/speed_trivia/score_podium",
        game:, room:,
        previous_top_player_ids: local_assigns[:previous_top_player_ids] || [] %>
</div>
```

- [ ] **Step 7: Run rubocop and specs checkpoint**

```bash
rubocop -A app/views/games/poll/
TEST_ENV_NUMBER=2 bin/rspec spec/ --format documentation 2>&1 | tail -20
```

Expected: no new failures introduced.

- [ ] **Step 8: Commit**

```bash
git add app/views/games/poll/
git commit -m "feat: add Bandwagon stage partials"
```

---

## Task 8: Hand Partials [CHECKPOINT]

**Files:**
- Create: `app/views/games/poll/_hand.html.erb`
- Create: `app/views/games/poll/_answer_form.html.erb`
- Create: `app/views/games/poll/_waiting.html.erb`
- Create: `app/views/games/poll/_game_over.html.erb`
- Create: `app/views/games/poll/_host_controls.html.erb`

- [ ] **Step 1: Create _hand.html.erb (router)**

Create `app/views/games/poll/_hand.html.erb`:

```erb
<%# app/views/games/poll/_hand.html.erb %>
<% game = room.current_game %>

<% if game.finished? %>
  <%= render "games/poll/game_over", room:, player:, game: %>
<% elsif game.answering? %>
  <%= render "games/poll/answer_form", room:, player:, game: %>
<% elsif game.instructions? %>
  <%= render "games/shared/hand_instructions",
      emoji: "🗳️",
      start_game_path: poll_game_game_start_path(game),
      room:,
      player: %>
<% else %>
  <%# waiting or reviewing %>
  <%= render "games/poll/waiting", room:, player:, game: %>
<% end %>
```

- [ ] **Step 2: Create _answer_form.html.erb**

Create `app/views/games/poll/_answer_form.html.erb`:

```erb
<%# app/views/games/poll/_answer_form.html.erb %>
<% current_question = game.current_question %>
<% existing_answer = current_question ? game.poll_answers.find_by(player:, poll_question: current_question) : nil %>
<% options = current_question&.options || [] %>
<% selected = existing_answer&.selected_option %>

<header class="max-w-md mx-auto flex justify-between items-center mb-4 px-2">
  <div class="flex flex-col">
    <span class="text-blue-100/80 text-xs font-bold tracking-widest uppercase">Question <%= game.current_question_index + 1 %></span>
  </div>
  <div class="bg-white/10 backdrop-blur-md border border-white/20 rounded-xl px-4 py-2 text-center shadow-sm">
    <p class="text-[10px] text-blue-200 font-bold uppercase tracking-wider">Code</p>
    <p class="text-xl font-black text-white font-mono leading-none"><%= room.code %></p>
  </div>
</header>

<div class="max-w-md mx-auto flex flex-col flex-1">
  <% if existing_answer %>
    <div class="grid <%= options.size == 1 ? 'grid-cols-1 max-w-[50%] mx-auto' : 'grid-cols-2' %> gap-3 flex-1 mb-4">
      <% options.each_with_index do |option, index| %>
        <% is_selected = option == selected %>
        <div class="<%= 'col-span-2 max-w-[50%] mx-auto' if options.size == 3 && index == 2 %>">
          <div class="rounded-2xl flex flex-col items-center justify-center h-full min-h-[20vh] shadow-lg px-3
            <%= is_selected ? 'bg-blue-600 border-4 border-blue-300 text-white ring-4 ring-blue-400/50' : 'bg-gray-800/40 border-2 border-gray-700 text-gray-600' %>">
            <span class="text-6xl font-black leading-none"><%= (index + 65).chr %></span>
            <span class="text-xs font-semibold mt-1 text-center leading-tight <%= is_selected ? 'text-blue-100' : 'text-gray-500' %>"><%= option %></span>
          </div>
        </div>
      <% end %>
    </div>
    <p class="text-center text-xl text-white font-bold">Locked in!</p>

  <% elsif current_question %>
    <div class="grid <%= options.size == 1 ? 'grid-cols-1 max-w-[50%] mx-auto' : 'grid-cols-2' %> gap-3 flex-1" data-controller="games--poll">
      <% options.each_with_index do |option, index| %>
        <div class="<%= 'col-span-2 max-w-[50%] mx-auto w-full' if options.size == 3 && index == 2 %>">
          <%= button_to poll_game_poll_answers_path(game),
              method: :post,
              params: { poll_answer: { selected_option: option }, code: room.code },
              class: "w-full h-full min-h-[20vh] rounded-2xl flex flex-col items-center justify-center gap-1 px-3 text-white shadow-lg transition-all active:scale-95 bg-gray-800/80 hover:bg-gray-700/80 backdrop-blur-md border-2 border-gray-600 hover:border-blue-400",
              data: {
                turbo_frame: "hand_screen",
                test_id: "answer-option-#{index}",
                action: "click->games--poll#disableOptions",
                games__poll_target: "option"
              } do %>
            <span class="text-6xl font-black leading-none"><%= (index + 65).chr %></span>
            <span class="text-xs font-semibold text-center leading-tight text-gray-300"><%= option %></span>
          <% end %>
        </div>
      <% end %>
    </div>

  <% else %>
    <div class="bg-white/10 backdrop-blur-md rounded-3xl p-8 text-center flex-1 flex items-center justify-center">
      <p class="text-xl text-white">Loading question...</p>
    </div>
  <% end %>
</div>

<% if player == room.host %>
  <div id="host-controls" class="max-w-md mx-auto mt-4 border-t-2 border-white/10 pt-6">
    <%= render "rooms/host_controls", room: room %>
  </div>
<% end %>
```

- [ ] **Step 3: Create the games--poll Stimulus controller**

Create `app/javascript/controllers/games/poll_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option"]

  disableOptions() {
    // Defer disable to after form activation (avoids killing form submission)
    setTimeout(() => {
      this.optionTargets.forEach(btn => { btn.disabled = true })
    }, 0)
  }
}
```

- [ ] **Step 4: Create _waiting.html.erb**

Create `app/views/games/poll/_waiting.html.erb`:

```erb
<%# app/views/games/poll/_waiting.html.erb %>
<%# Handles both 'waiting' (get ready) and 'reviewing' (here's how you did) states %>

<header class="max-w-md mx-auto flex justify-between items-center mb-6 px-2">
  <div class="flex flex-col">
    <span class="text-blue-100/80 text-xs font-bold tracking-widest uppercase">
      <%= game.waiting? ? "Get Ready" : "Results" %>
    </span>
  </div>
  <div class="bg-white/10 backdrop-blur-md border border-white/20 rounded-xl px-4 py-2 text-center shadow-sm">
    <p class="text-[10px] text-blue-200 font-bold uppercase tracking-wider">Code</p>
    <p class="text-xl font-black text-white font-mono leading-none"><%= room.code %></p>
  </div>
</header>

<div class="max-w-md mx-auto">
  <div class="bg-white/10 backdrop-blur-md rounded-3xl p-8 border border-white/20 text-center">
    <% if game.waiting? %>
      <div class="text-6xl mb-6 animate-bounce">🗳️</div>
      <p class="text-2xl text-white font-bold mb-4">Get Ready!</p>
      <p class="text-lg text-blue-200">
        <%= game.poll_pack&.poll_questions&.count %> questions ahead
      </p>
      <p class="text-blue-300 mt-4">
        <% if game.majority? %>
          Go with the crowd for points!
        <% elsif game.minority? %>
          Be the odd one out for points!
        <% else %>
          Match the host's answer for points!
        <% end %>
      </p>

    <% elsif game.reviewing? %>
      <% reveal = game.score_reveal_for(player:) %>

      <% if game.host_choose? && game.host_chosen_answer.blank? %>
        <div class="text-5xl mb-3">⏳</div>
        <p class="text-2xl text-white font-bold mb-1">Waiting…</p>
        <p class="text-sm text-blue-200">Host is picking the answer.</p>
      <% elsif reveal[:did_win] %>
        <div class="text-5xl mb-3">🎉</div>
        <p class="text-2xl text-green-400 font-bold mb-1">
          <%= game.majority? ? "With the crowd!" : game.minority? ? "Against the crowd!" : "That's the one!" %>
        </p>
      <% elsif reveal[:answer] %>
        <div class="text-5xl mb-3">😅</div>
        <p class="text-2xl text-red-400 font-bold mb-1">
          <%= game.majority? ? "Not the popular choice." : game.minority? ? "Too mainstream." : "Not quite." %>
        </p>
        <% if reveal[:winner].present? %>
          <p class="text-sm text-white mb-1">
            The answer was: <span class="font-bold text-green-400"><%= reveal[:winner] %></span>
          </p>
        <% else %>
          <p class="text-sm text-white mb-1">It was a tie — no points this round.</p>
        <% end %>
      <% else %>
        <div class="text-5xl mb-3">⏱</div>
        <p class="text-2xl text-gray-400 font-bold mb-1">And... time.</p>
      <% end %>

      <% if reveal[:answer].present? && !(game.host_choose? && game.host_chosen_answer.blank?) %>
        <hr class="border-white/20 my-4">

        <% if reveal[:round_points] == 0 %>
          <div class="text-xl font-black text-white mb-4"><%= ["Oof.", "Next one's yours."].sample %></div>
        <% elsif reveal[:rank_improved] %>
          <div class="text-xl font-black text-white mb-4"><%= ["Nice one!", "That's how you do it."].sample %></div>
        <% else %>
          <div class="text-xl font-black text-white mb-4"><%= ["Still in it!", "Hold tight."].sample %></div>
        <% end %>

        <div data-controller="score-tally"
             data-score-tally-from-value="<%= reveal[:score_from] %>"
             data-score-tally-to-value="<%= reveal[:score_to] %>">
          <p class="text-blue-200 text-sm font-bold uppercase tracking-widest mb-1">
            <%= reveal[:rank].ordinalize %> Place
          </p>
          <p class="text-5xl font-black text-white font-mono mb-2"
             data-score-tally-target="display">
            <%= reveal[:score_from] %>
          </p>
          <% if reveal[:round_points] > 0 %>
            <p class="text-green-400 font-bold text-lg">+<%= reveal[:round_points] %> this round</p>
          <% else %>
            <p class="text-gray-400 font-bold text-lg">+0 this round</p>
          <% end %>
        </div>
      <% end %>
    <% end %>
  </div>
</div>

<% if player == room.host %>
  <div id="host-controls" class="max-w-md mx-auto mt-4 border-t-2 border-white/10 pt-6">
    <%= render "rooms/host_controls", room: room %>
  </div>
<% end %>
```

- [ ] **Step 5: Create _game_over.html.erb**

Create `app/views/games/poll/_game_over.html.erb`:

```erb
<%# app/views/games/poll/_game_over.html.erb %>
<header class="max-w-md mx-auto flex justify-between items-center mb-6 px-2">
  <span class="text-blue-100/80 text-xs font-bold tracking-widest uppercase">Game Over</span>
  <div class="bg-white/10 backdrop-blur-md border border-white/20 rounded-xl px-4 py-2 text-center shadow-sm">
    <p class="text-[10px] text-blue-200 font-bold uppercase tracking-wider">Code</p>
    <p class="text-xl font-black text-white font-mono leading-none"><%= room.code %></p>
  </div>
</header>

<div class="max-w-md mx-auto">
  <div class="bg-white/10 backdrop-blur-md rounded-3xl p-8 border border-white/20 text-center">
    <div class="text-6xl mb-4">🏁</div>
    <p class="text-2xl text-white font-bold mb-2">That's a wrap!</p>

    <% rank = room.players.active_players.order(score: :desc).index { |p| p.id == player.id }.to_i + 1 %>
    <% total_points = game.total_points_for(player) %>

    <p class="text-blue-200 text-lg mb-4">
      You finished <span class="font-black text-white"><%= rank.ordinalize %></span>
      with <span class="font-black text-yellow-400"><%= total_points %> pts</span>
    </p>

    <% unless player == room.host || current_user %>
      <%= link_to "Sign up free", host_path,
            class: "inline-block mt-2 text-blue-300 hover:text-white underline font-semibold text-sm transition",
            data: { turbo: false } %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 6: Create _host_controls.html.erb**

Create `app/views/games/poll/_host_controls.html.erb`:

```erb
<%# app/views/games/poll/_host_controls.html.erb %>
<% game = room.current_game %>

<div class="space-y-4">
  <% unless game.instructions? %>
    <div class="flex items-center justify-between mb-4">
      <span class="text-blue-200 font-medium">
        Question <%= game.current_question_index + 1 %> of <%= game.poll_pack&.poll_questions&.count %>
      </span>
      <span class="px-3 py-1 rounded-full text-sm font-bold
        <%= case game.status
            when 'waiting'   then 'bg-yellow-500/20 text-yellow-300'
            when 'answering' then 'bg-green-500/20 text-green-300'
            when 'reviewing' then 'bg-blue-500/20 text-blue-300'
            else 'bg-gray-500/20 text-gray-300'
            end %>">
        <%= game.status.titleize %>
      </span>
    </div>
  <% end %>

  <% if game.instructions? %>
    <p class="text-blue-200 text-sm mb-4">Players are viewing the instructions.</p>
    <%= button_to "Start Game",
        poll_game_game_start_path(game),
        method: :post,
        params: { code: room.code },
        data: { turbo_submits_with: "Starting…" },
        class: "w-full bg-gradient-to-r from-green-600 to-emerald-600 hover:from-green-500 hover:to-emerald-500 text-white font-bold py-3 px-6 rounded-xl transition duration-200 shadow-lg cursor-pointer border border-white/10" %>

  <% elsif game.waiting? %>
    <p class="text-blue-200 text-sm mb-4">Players are waiting for the next question.</p>
    <%= button_to "Start Question",
        poll_game_question_path(game),
        method: :post,
        params: { code: room.code },
        data: { turbo_submits_with: "Loading…" },
        class: "w-full bg-gradient-to-r from-green-600 to-emerald-600 hover:from-green-500 hover:to-emerald-500 text-white font-bold py-3 px-6 rounded-xl transition duration-200 shadow-lg cursor-pointer border border-white/10" %>

  <% elsif game.answering? %>
    <% answers_count = game.poll_answers.where(poll_question: game.current_question).count %>
    <% players_count = room.players.active_players.count %>
    <p class="text-blue-200 text-sm mb-4">
      Answers: <%= answers_count %>/<%= players_count %> players
      <% if game.timer_enabled? && game.round_ends_at %>
        <span class="ml-2" data-controller="timer" data-timer-end-value="<%= game.timer_expires_at_iso8601 %>">
          (Timer: <span data-timer-target="output"><%= game.time_remaining.ceil %>s</span>)
        </span>
      <% end %>
    </p>
    <%= button_to "Close Voting",
        poll_game_round_closure_path(game),
        method: :post,
        params: { code: room.code },
        data: { turbo_submits_with: "Closing…" },
        class: "w-full bg-gradient-to-r from-orange-600 to-red-600 hover:from-orange-500 hover:to-red-500 text-white font-bold py-3 px-6 rounded-xl transition duration-200 shadow-lg cursor-pointer border border-white/10" %>

  <% elsif game.reviewing? %>
    <% if game.host_choose? && game.host_chosen_answer.blank? %>
      <%# host_choose mode: host picks the answer before scores show %>
      <% current_q = game.current_question %>
      <p class="text-blue-200 text-sm mb-3">Pick the correct answer:</p>
      <div class="grid grid-cols-2 gap-2 mb-4">
        <% current_q&.options&.each do |option| %>
          <%= button_to "✓ #{option}",
              poll_game_host_answers_path(game),
              method: :post,
              params: { answer: option, code: room.code },
              data: { turbo_submits_with: "Setting…" },
              class: "bg-white/10 hover:bg-green-600/40 border border-white/20 hover:border-green-500 text-white font-bold py-2 px-3 rounded-xl transition text-sm cursor-pointer" %>
        <% end %>
      </div>
    <% else %>
      <% current_q = game.current_question %>
      <% if game.host_chosen_answer.present? %>
        <p class="text-green-400 text-sm font-bold mb-3">Answer: <%= game.host_chosen_answer %></p>
      <% end %>

      <% if game.questions_remaining? %>
        <%= button_to "Next Question",
            poll_game_advancement_path(game),
            method: :post,
            params: { code: room.code },
            data: { turbo_submits_with: "Loading…" },
            class: "w-full bg-gradient-to-r from-indigo-600 to-blue-600 hover:from-indigo-500 hover:to-blue-500 text-white font-bold py-3 px-6 rounded-xl transition duration-200 shadow-lg cursor-pointer border border-white/10" %>
      <% else %>
        <%= button_to "Finish Game",
            poll_game_advancement_path(game),
            method: :post,
            params: { code: room.code },
            data: { turbo_submits_with: "Finishing…" },
            class: "w-full bg-gradient-to-r from-yellow-600 to-orange-600 hover:from-yellow-500 hover:to-orange-500 text-white font-bold py-3 px-6 rounded-xl transition duration-200 shadow-lg cursor-pointer border border-white/10" %>
      <% end %>
    <% end %>

  <% elsif game.finished? %>
    <div class="bg-green-500/20 rounded-xl p-4 text-center">
      <p class="text-green-300 font-bold text-lg">Game Complete!</p>
      <p class="text-green-200 text-sm mt-2">Final scores are displayed on screen.</p>
      <%= link_to "Start a new game?", host_path, class: "inline-block mt-3 text-blue-300 hover:text-blue-100 underline text-sm font-medium transition" %>
    </div>
  <% end %>

  <% unless game.finished? %>
    <%= render "games/end_game_button", game: game, room: room %>
  <% end %>
</div>
```

- [ ] **Step 7: Run specs checkpoint**

```bash
TEST_ENV_NUMBER=2 bin/rspec spec/ --format documentation 2>&1 | tail -20
rubocop -A app/views/games/poll/ app/javascript/controllers/games/poll_controller.js
```

Expected: no failures.

- [ ] **Step 8: Commit**

```bash
git add app/views/games/poll/ app/javascript/controllers/games/poll_controller.js
git commit -m "feat: add Bandwagon hand partials and host controls"
```

---

## Task 9: PollPack Backstage Editor

**Files:**
- Create: `app/views/poll_packs/index.html.erb`
- Create: `app/views/poll_packs/new.html.erb`
- Create: `app/views/poll_packs/edit.html.erb`
- Create: `app/views/poll_packs/show.html.erb`
- Create: `app/views/poll_packs/_form.html.erb`
- Create: `app/views/poll_packs/_card.html.erb`
- Create: `app/controllers/poll_packs_controller.rb`
- Create: `app/javascript/controllers/poll_editor_controller.js`
- Modify: `config/routes.rb`

- [ ] **Step 1: Add poll_packs route**

In `config/routes.rb`, add with the other pack resources:

```ruby
resources :poll_packs
```

- [ ] **Step 2: Create poll_packs_controller.rb**

Model after `TriviaPacks::TriviaPack` controller. Create `app/controllers/poll_packs_controller.rb`:

```ruby
class PollPacksController < ApplicationController
  before_action :require_login
  before_action :set_poll_pack, only: %i[show edit update destroy]

  def index
    @poll_packs = current_user.poll_packs.order(created_at: :desc)
  end

  def new
    @poll_pack = current_user.poll_packs.build
    @poll_pack.poll_questions.build
  end

  def create
    @poll_pack = current_user.poll_packs.build(poll_pack_params)
    if @poll_pack.save
      redirect_to @poll_pack, notice: "Pack created!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show; end

  def edit; end

  def update
    if @poll_pack.update(poll_pack_params)
      redirect_to @poll_pack, notice: "Pack updated!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @poll_pack.destroy
    redirect_to poll_packs_path, notice: "Pack deleted."
  end

  private

  def set_poll_pack
    @poll_pack = current_user.poll_packs.find(params[:id])
  end

  def poll_pack_params
    params.require(:poll_pack).permit(
      :name, :status,
      poll_questions_attributes: [ :id, :body, :position, :_destroy, options: [] ]
    )
  end
end
```

- [ ] **Step 3: Create poll_editor_controller.js**

Create `app/javascript/controllers/poll_editor_controller.js`:

```javascript
import QuestionListEditorController from "./question_list_editor_controller"

// Thin wrapper for the poll question editor.
// All structural logic (drag/drop, collapse, options) lives in the shared base.
// Poll-specific: no correct answer UI. Future hook: free-response toggle.
export default class extends QuestionListEditorController {
  static targets = [
    // All base targets (Stimulus requires listing them per-class)
    "questionList", "questionTemplate", "countDisplay",
    "questionField", "optionField", "positionField", "positionBadge",
    "optionRow", "optionLetter", "optionsContainer", "addOptionButton",
    "collapsibleContent", "collapseAllButton"
    // Future: "freeResponseToggle"
  ]

  // onConnect, onQuestionAdded, etc. can be overridden here when needed.
}
```

- [ ] **Step 4: Create _form.html.erb**

Create `app/views/poll_packs/_form.html.erb` — modelled on `trivia_packs/_form.html.erb` but using `poll-editor` controller and omitting the correct answer and image sections:

```erb
<%= form_with(model: poll_pack, class: "contents", data: { controller: "poll-editor" }) do |form| %>
  <%= hidden_field_tag :return_to, @return_to if @return_to.present? %>
  <% if poll_pack.errors.any? %>
    <div class="bg-red-500/20 text-red-200 px-6 py-4 font-medium rounded-2xl mb-8 border border-red-500/30 backdrop-blur-md">
      <h2 class="font-bold mb-2"><%= pluralize(poll_pack.errors.count, "error") %> prohibited this pack from being saved:</h2>
      <ul class="list-disc list-inside text-sm">
        <% poll_pack.errors.each do |error| %>
          <li><%= error.full_message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
    <!-- Left Column: Settings -->
    <div class="space-y-6">
      <div class="bg-white/10 backdrop-blur-md rounded-3xl p-8 shadow-xl border border-white/20">
        <h3 class="text-xl font-black text-white mb-6 flex items-center gap-2 tracking-wide">
          <%= lucide_icon('settings', class: "w-5 h-5 text-blue-200", "aria-hidden": true) %>
          Pack Settings
        </h3>
        <div class="space-y-5">
          <div>
            <%= form.label :name, class: "block text-sm font-bold text-blue-200 mb-2 uppercase tracking-widest" %>
            <%= form.text_field :name, class: "block w-full rounded-xl bg-white/5 border-2 border-white/10 shadow-sm focus:border-orange-500 focus:ring focus:ring-orange-500/20 transition-all font-medium py-3 px-4 text-white placeholder-white/30" %>
          </div>
          <div>
            <%= form.label :status, class: "block text-sm font-bold text-blue-200 mb-2 uppercase tracking-widest" %>
            <%= form.select :status, PollPack.statuses.keys.map { |k| [k.humanize, k] }, {},
                class: "block w-full rounded-xl bg-white/5 border-2 border-white/10 shadow-sm focus:border-orange-500 focus:ring focus:ring-orange-500/20 transition-all font-medium py-3 px-4 text-white [&>option]:text-gray-900" %>
          </div>
        </div>
      </div>
      <div class="pt-2">
        <%= form.submit "Save Pack", class: "w-full rounded-xl py-4 px-6 bg-orange-500 hover:bg-orange-600 text-white block font-black text-lg shadow-lg shadow-orange-900/20 transition-all cursor-pointer transform hover:scale-[1.02] active:scale-95" %>
        <%= link_to "Cancel", poll_packs_path, class: "block w-full text-center mt-4 text-blue-200/50 hover:text-white font-bold text-sm transition-colors" %>
      </div>
    </div>

    <!-- Right Column: Questions -->
    <div class="bg-white/10 backdrop-blur-md rounded-3xl p-8 shadow-xl border border-white/20 h-fit relative">
      <div class="flex justify-between items-center mb-4 sticky top-0 z-10 bg-white/10 backdrop-blur-md -mx-8 -mt-8 px-8 pt-8 pb-4 rounded-t-3xl border-b border-white/10">
        <h3 class="text-xl font-black text-white tracking-wide">
          Questions <span class="text-blue-300 font-bold text-base ml-1" data-poll-editor-target="countDisplay">0</span>
        </h3>
        <div class="flex items-center gap-2">
          <button type="button" data-action="poll-editor#toggleCollapseAll" data-poll-editor-target="collapseAllButton"
                  class="text-sm text-white/60 hover:text-white font-bold bg-white/5 hover:bg-white/10 px-3 py-1.5 rounded-lg transition-colors border border-white/10">
            Collapse All
          </button>
          <button type="button" data-action="poll-editor#addQuestion"
                  class="text-sm text-white font-bold bg-white/10 hover:bg-white/20 px-3 py-1.5 rounded-lg transition-colors flex items-center gap-1.5 border border-white/10">
            <%= lucide_icon('plus', class: "w-4 h-4", "aria-hidden": true) %>
            Add Question
          </button>
        </div>
      </div>

      <div data-poll-editor-target="questionList" class="space-y-6">
        <%= form.fields_for :poll_questions do |q| %>
          <div class="question-field-wrapper bg-white/5 rounded-xl p-4 border border-white/10 group"
               data-new-record="<%= q.object.new_record? %>"
               draggable="true"
               data-action="dragstart->poll-editor#dragStart dragend->poll-editor#dragEnd dragover->poll-editor#dragOver dragenter->poll-editor#dragEnter dragleave->poll-editor#dragLeave drop->poll-editor#drop">
            <%= q.hidden_field :position, data: { "poll-editor-target": "positionField" } %>
            <div class="flex items-center gap-2 mb-3">
              <div class="drag-handle cursor-grab active:cursor-grabbing text-white/30 hover:text-white/60 transition-colors">
                <%= lucide_icon('grip-vertical', class: "w-4 h-4", "aria-hidden": true) %>
              </div>
              <button type="button" data-action="poll-editor#toggleCollapse" class="text-white/30 hover:text-white/70 p-0.5 rounded transition-colors">
                <%= lucide_icon('chevron-down', class: "w-4 h-4 collapse-icon transition-transform", "aria-hidden": true) %>
              </button>
              <span class="inline-flex items-center justify-center w-6 h-6 bg-blue-500/20 text-blue-300 font-bold text-xs rounded-full" data-poll-editor-target="positionBadge"><%= q.index + 1 %></span>
              <span class="text-sm text-white/50 truncate max-w-[200px]"><%= q.object.body.presence&.truncate(40) %></span>
              <div class="flex gap-0.5 ml-auto">
                <button type="button" data-action="poll-editor#moveUp" class="text-white/30 hover:text-white/70 p-1 rounded hover:bg-white/10 transition-colors">
                  <%= lucide_icon('chevron-up', class: "w-4 h-4", "aria-hidden": true) %>
                </button>
                <button type="button" data-action="poll-editor#moveDown" class="text-white/30 hover:text-white/70 p-1 rounded hover:bg-white/10 transition-colors">
                  <%= lucide_icon('chevron-down', class: "w-4 h-4", "aria-hidden": true) %>
                </button>
              </div>
            </div>
            <div data-poll-editor-target="collapsibleContent">
              <div class="mb-4">
                <%= q.text_area :body, rows: 2,
                      class: "block w-full rounded-lg bg-white/10 border-2 border-white/10 focus:border-orange-500 focus:ring focus:ring-orange-500/20 text-sm font-medium text-white placeholder-white/30 resize-none transition-all px-3 py-2",
                      data: { "poll-editor-target": "questionField", action: "input->poll-editor#updateCount" },
                      placeholder: "Enter your question..." %>
              </div>
              <div class="grid grid-cols-1 gap-2 mb-3" data-poll-editor-target="optionsContainer">
                <% (q.object.options || ["", "", "", ""]).each_with_index do |option_value, i| %>
                  <div class="flex items-center gap-2" data-poll-editor-target="optionRow">
                    <span class="inline-flex items-center justify-center w-6 h-6 bg-blue-500/20 text-blue-300 font-bold text-xs rounded flex-shrink-0" data-poll-editor-target="optionLetter">
                      <%= ('A'.ord + i).chr %>
                    </span>
                    <input type="text"
                           name="<%= q.object_name %>[options][]"
                           value="<%= option_value %>"
                           placeholder="Option <%= ('A'.ord + i).chr %>"
                           data-poll-editor-target="optionField"
                           class="flex-1 rounded-lg bg-white/10 border border-white/10 focus:border-orange-500 focus:ring focus:ring-orange-500/20 text-sm font-medium text-white placeholder-white/30 transition-all px-3 py-2">
                    <button type="button" data-action="poll-editor#removeOption"
                            class="text-white/20 hover:text-red-400 p-1 rounded hover:bg-red-500/10 transition-colors">
                      <%= lucide_icon('x', class: "w-4 h-4", "aria-hidden": true) %>
                    </button>
                  </div>
                <% end %>
                <button type="button"
                        data-action="poll-editor#addOption"
                        data-poll-editor-target="addOptionButton"
                        class="<%= (q.object.options || ["", "", "", ""]).size >= 4 ? 'hidden' : '' %> text-xs text-blue-300 hover:text-white font-bold flex items-center gap-1 mt-1 px-2 py-1 rounded hover:bg-white/10 transition-colors">
                  <%= lucide_icon('plus', class: "w-3 h-3", "aria-hidden": true) %>
                  Add Option
                </button>
              </div>
              <%= q.hidden_field :_destroy %>
              <div class="flex justify-end">
                <button type="button" data-action="poll-editor#removeQuestion"
                        class="text-white/40 hover:text-red-400 font-bold text-xs flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-all px-2 py-1 rounded hover:bg-red-500/10">
                  <%= lucide_icon('trash-2', class: "w-4 h-4", "aria-hidden": true) %>
                  Remove
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
  </div>

  <template data-poll-editor-target="questionTemplate">
    <div class="question-field-wrapper bg-white/5 rounded-xl p-4 border border-white/10 group"
         data-new-record="true" draggable="true"
         data-action="dragstart->poll-editor#dragStart dragend->poll-editor#dragEnd dragover->poll-editor#dragOver dragenter->poll-editor#dragEnter dragleave->poll-editor#dragLeave drop->poll-editor#drop">
      <input type="hidden" name="poll_pack[poll_questions_attributes][NEW_RECORD][position]" data-poll-editor-target="positionField" />
      <div class="flex items-center gap-2 mb-3">
        <div class="drag-handle cursor-grab active:cursor-grabbing text-white/30 hover:text-white/60 transition-colors">
          <%= lucide_icon('grip-vertical', class: "w-4 h-4", "aria-hidden": true) %>
        </div>
        <button type="button" data-action="poll-editor#toggleCollapse" class="text-white/30 hover:text-white/70 p-0.5 rounded transition-colors">
          <%= lucide_icon('chevron-down', class: "w-4 h-4 collapse-icon transition-transform", "aria-hidden": true) %>
        </button>
        <span class="inline-flex items-center justify-center w-6 h-6 bg-blue-500/20 text-blue-300 font-bold text-xs rounded-full" data-poll-editor-target="positionBadge"></span>
        <span class="text-sm text-white/50 truncate max-w-[200px]"></span>
        <div class="flex gap-0.5 ml-auto">
          <button type="button" data-action="poll-editor#moveUp" class="text-white/30 hover:text-white/70 p-1 rounded hover:bg-white/10 transition-colors">
            <%= lucide_icon('chevron-up', class: "w-4 h-4", "aria-hidden": true) %>
          </button>
          <button type="button" data-action="poll-editor#moveDown" class="text-white/30 hover:text-white/70 p-1 rounded hover:bg-white/10 transition-colors">
            <%= lucide_icon('chevron-down', class: "w-4 h-4", "aria-hidden": true) %>
          </button>
        </div>
      </div>
      <div data-poll-editor-target="collapsibleContent">
        <div class="mb-4">
          <textarea name="poll_pack[poll_questions_attributes][NEW_RECORD][body]" rows="2"
                    class="block w-full rounded-lg bg-white/10 border-2 border-white/10 focus:border-orange-500 focus:ring focus:ring-orange-500/20 text-sm font-medium text-white placeholder-white/30 resize-none transition-all px-3 py-2"
                    data-poll-editor-target="questionField"
                    data-action="input->poll-editor#updateCount"
                    placeholder="Enter your question..."></textarea>
        </div>
        <div class="grid grid-cols-1 gap-2 mb-3" data-poll-editor-target="optionsContainer">
          <% 4.times do |i| %>
            <div class="flex items-center gap-2" data-poll-editor-target="optionRow">
              <span class="inline-flex items-center justify-center w-6 h-6 bg-blue-500/20 text-blue-300 font-bold text-xs rounded flex-shrink-0" data-poll-editor-target="optionLetter">
                <%= ('A'.ord + i).chr %>
              </span>
              <input type="text"
                     name="poll_pack[poll_questions_attributes][NEW_RECORD][options][]"
                     placeholder="Option <%= ('A'.ord + i).chr %>"
                     data-poll-editor-target="optionField"
                     class="flex-1 rounded-lg bg-white/10 border border-white/10 focus:border-orange-500 focus:ring focus:ring-orange-500/20 text-sm font-medium text-white placeholder-white/30 transition-all px-3 py-2">
              <button type="button" data-action="poll-editor#removeOption"
                      class="text-white/20 hover:text-red-400 p-1 rounded hover:bg-red-500/10 transition-colors">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
              </button>
            </div>
          <% end %>
          <button type="button"
                  data-action="poll-editor#addOption"
                  data-poll-editor-target="addOptionButton"
                  class="hidden text-xs text-blue-300 hover:text-white font-bold flex items-center gap-1 mt-1 px-2 py-1 rounded hover:bg-white/10 transition-colors">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
            Add Option
          </button>
        </div>
        <input type="hidden" name="poll_pack[poll_questions_attributes][NEW_RECORD][_destroy]" value="false" />
        <div class="flex justify-end">
          <button type="button" data-action="poll-editor#removeQuestion"
                  class="text-white/40 hover:text-red-400 font-bold text-xs flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-all px-2 py-1 rounded hover:bg-red-500/10">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/></svg>
            Remove
          </button>
        </div>
      </div>
    </div>
  </template>
<% end %>
```

- [ ] **Step 5: Create index, new, edit, show views** (follow `trivia_packs/` patterns)

Create `app/views/poll_packs/index.html.erb`:

```erb
<div class="max-w-4xl mx-auto px-4 py-8">
  <div class="flex items-center justify-between mb-8">
    <h1 class="text-3xl font-black text-white">My Poll Packs</h1>
    <%= link_to "New Pack", new_poll_pack_path, class: "bg-orange-500 hover:bg-orange-600 text-white font-bold py-2 px-4 rounded-xl transition" %>
  </div>
  <% if @poll_packs.empty? %>
    <div class="bg-white/10 rounded-3xl p-12 text-center">
      <p class="text-blue-200 text-lg">No packs yet.</p>
      <%= link_to "Create your first pack", new_poll_pack_path, class: "mt-4 inline-block text-orange-400 hover:text-orange-200 underline font-bold" %>
    </div>
  <% else %>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <% @poll_packs.each do |pack| %>
        <%= render "poll_packs/card", poll_pack: pack %>
      <% end %>
    </div>
  <% end %>
</div>
```

Create `app/views/poll_packs/_card.html.erb`:

```erb
<div class="bg-white/10 backdrop-blur-md rounded-2xl p-6 border border-white/20">
  <div class="flex items-start justify-between">
    <div>
      <h3 class="text-white font-black text-lg"><%= poll_pack.name %></h3>
      <p class="text-blue-200 text-sm mt-1"><%= pluralize(poll_pack.poll_questions.count, "question") %></p>
    </div>
    <span class="px-2 py-1 rounded-full text-xs font-bold <%= poll_pack.live? ? 'bg-green-500/20 text-green-300' : 'bg-gray-500/20 text-gray-300' %>">
      <%= poll_pack.status.titleize %>
    </span>
  </div>
  <div class="flex gap-2 mt-4">
    <%= link_to "Edit", edit_poll_pack_path(poll_pack), class: "text-sm text-blue-300 hover:text-white font-bold underline" %>
    <%= button_to "Delete", poll_pack_path(poll_pack), method: :delete, data: { confirm: "Delete this pack?" }, class: "text-sm text-red-400 hover:text-red-200 font-bold underline cursor-pointer bg-transparent border-0 p-0" %>
  </div>
</div>
```

Create `app/views/poll_packs/new.html.erb`:

```erb
<div class="max-w-6xl mx-auto px-4 py-8">
  <h1 class="text-3xl font-black text-white mb-8">New Poll Pack</h1>
  <%= render "form", poll_pack: @poll_pack %>
</div>
```

Create `app/views/poll_packs/edit.html.erb`:

```erb
<div class="max-w-6xl mx-auto px-4 py-8">
  <h1 class="text-3xl font-black text-white mb-8">Edit Poll Pack</h1>
  <%= render "form", poll_pack: @poll_pack %>
</div>
```

Create `app/views/poll_packs/show.html.erb`:

```erb
<div class="max-w-4xl mx-auto px-4 py-8">
  <div class="flex items-center justify-between mb-8">
    <h1 class="text-3xl font-black text-white"><%= @poll_pack.name %></h1>
    <%= link_to "Edit", edit_poll_pack_path(@poll_pack), class: "bg-orange-500 hover:bg-orange-600 text-white font-bold py-2 px-4 rounded-xl transition" %>
  </div>
  <% @poll_pack.poll_questions.order(:position).each_with_index do |q, i| %>
    <div class="bg-white/10 rounded-xl p-4 mb-3 border border-white/10">
      <p class="text-blue-200 text-xs font-bold uppercase tracking-widest mb-1">Q<%= i + 1 %></p>
      <p class="text-white font-bold mb-2"><%= q.body %></p>
      <div class="flex gap-2 flex-wrap">
        <% q.options&.each_with_index do |opt, oi| %>
          <span class="px-2 py-1 bg-white/5 rounded text-sm text-blue-200"><%= ('A'.ord + oi).chr %>: <%= opt %></span>
        <% end %>
      </div>
    </div>
  <% end %>
</div>
```

- [ ] **Step 6: Run rubocop**

```bash
rubocop -A app/controllers/poll_packs_controller.rb app/views/poll_packs/
```

- [ ] **Step 7: Commit**

```bash
git add app/controllers/poll_packs_controller.rb \
        app/views/poll_packs/ \
        app/javascript/controllers/poll_editor_controller.js \
        config/routes.rb
git commit -m "feat: add PollPack backstage editor with poll_editor_controller"
```

---

## Task 10: System Specs [CHECKPOINT]

**Files:**
- Create: `spec/system/games/bandwagon_happy_path_spec.rb`
- Create: `spec/system/games/bandwagon_host_choose_spec.rb`

- [ ] **Step 1: Create majority mode happy path spec**

Create `spec/system/games/bandwagon_happy_path_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Bandwagon happy path — majority mode", type: :system, js: true do
  let!(:pack) do
    pack = PollPack.create!(name: "Test Pack", status: :live)
    pack.poll_questions.create!(body: "Dogs or cats?", options: ["Dogs", "Cats"], position: 0)
    pack.poll_questions.create!(body: "Pizza or tacos?", options: ["Pizza", "Tacos"], position: 1)
    pack
  end

  it "plays through a full majority-mode game and awards points to majority players" do
    # Setup
    room = nil
    host_player = nil
    p1 = nil
    p2 = nil

    using_session(:host) do
      visit play_path
      fill_in "Your name", with: "Host"
      click_button "Join"
      host_player = Player.last
      room = host_player.room
      room.update!(poll_pack: pack, game_type: "Poll Game")
    end

    using_session(:player1) do
      visit join_room_path(room.code)
      fill_in "Your name", with: "Player1"
      click_button "Join"
      p1 = Player.last
    end

    using_session(:player2) do
      visit join_room_path(room.code)
      fill_in "Your name", with: "Player2"
      click_button "Join"
      p2 = Player.last
    end

    # Host starts game
    using_session(:host) do
      room.update!(host: host_player)
      Games::Poll.game_started(room: room.reload, question_count: 2,
                               scoring_mode: "majority", timer_enabled: false,
                               show_instructions: true)
      visit room_hand_path(room.code)
      expect(page).to have_content("Bandwagon")
      click_button "Start Game"
      expect(page).to have_content("Get Ready")
    end

    # Host starts first question
    using_session(:host) do
      click_button "Start Question"
      expect(page).to have_content("Question 1")
    end

    # Players answer
    using_session(:player1) do
      visit room_hand_path(room.code)
      expect(page).to have_content("Dogs or cats?")
      find("[data-test-id='answer-option-0']").click  # Dogs
      expect(page).to have_content("Locked in!")
    end

    using_session(:player2) do
      visit room_hand_path(room.code)
      expect(page).to have_content("Dogs or cats?")
      find("[data-test-id='answer-option-0']").click  # Dogs
      expect(page).to have_content("Locked in!")
    end

    # Host also answers (answers too)
    using_session(:host) do
      find("[data-test-id='answer-option-1']").click  # Cats (minority)
    end

    # Host closes voting
    using_session(:host) do
      click_button "Close Voting"
      expect(page).to have_content("Results")
    end

    # Verify majority players (Dogs) received points
    using_session(:player1) do
      expect(page).to have_content("With the crowd!")
      expect(page).to have_content("+")
    end

    using_session(:host) do
      expect(page).to have_content("Not the popular choice.")
    end

    # Verify DB
    q1 = pack.poll_questions.find_by(position: 0)
    p1_answer = PollAnswer.find_by(player: p1, poll_question: q1)
    host_answer = PollAnswer.find_by(player: host_player, poll_question: q1)
    expect(p1_answer.points_awarded).to be > 0
    expect(host_answer.points_awarded).to eq(0)

    # Host advances to next question and finishes
    using_session(:host) do
      click_button "Next Question"
      expect(page).to have_content("Question 2")
      click_button "Start Question"
    end

    using_session(:player1) do
      expect(page).to have_content("Pizza or tacos?")
      find("[data-test-id='answer-option-0']").click
    end
    using_session(:player2) do
      expect(page).to have_content("Pizza or tacos?")
      find("[data-test-id='answer-option-0']").click
    end

    using_session(:host) do
      find("[data-test-id='answer-option-0']").click
      click_button "Close Voting"
      expect(page).to have_content("Results")
      click_button "Finish Game"
      expect(page).to have_content("Game Complete!")
    end

    using_session(:player1) do
      expect(page).to have_content("That's a wrap!")
    end
  end

  it "awards no points on a perfect tie" do
    room = nil
    host_player = nil
    p1 = nil
    p2 = nil

    using_session(:host) do
      visit play_path
      fill_in "Your name", with: "Host"
      click_button "Join"
      host_player = Player.last
      room = host_player.room
      room.update!(poll_pack: pack, game_type: "Poll Game", host: host_player)
      Games::Poll.game_started(room: room.reload, question_count: 1,
                               scoring_mode: "majority", timer_enabled: false,
                               show_instructions: false)
      visit room_hand_path(room.code)
      expect(page).to have_content("Get Ready")
    end

    using_session(:player1) do
      visit join_room_path(room.code)
      fill_in "Your name", with: "Player1"
      click_button "Join"
      p1 = Player.last
    end

    using_session(:host) do
      click_button "Start Question"
      expect(page).to have_content("Question 1")
    end

    using_session(:host) do
      find("[data-test-id='answer-option-0']").click  # Dogs
    end
    using_session(:player1) do
      visit room_hand_path(room.code)
      find("[data-test-id='answer-option-1']").click  # Cats
    end

    using_session(:host) do
      click_button "Close Voting"
      expect(page).to have_content("Results")
    end

    q1 = pack.poll_questions.find_by(position: 0)
    expect(PollAnswer.where(poll_question: q1).sum(:points_awarded)).to eq(0)
  end
end
```

- [ ] **Step 2: Create host_choose spec**

Create `spec/system/games/bandwagon_host_choose_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Bandwagon host_choose mode", type: :system, js: true do
  let!(:pack) do
    pack = PollPack.create!(name: "Wedding Pack", status: :live)
    pack.poll_questions.create!(
      body: "Who takes longer to get ready?",
      options: ["Alex", "Jordan"],
      position: 0
    )
    pack
  end

  it "host reveals the answer after voting and only matching players score" do
    room = nil
    host_player = nil
    p1 = nil
    p2 = nil

    using_session(:host) do
      visit play_path
      fill_in "Your name", with: "Host"
      click_button "Join"
      host_player = Player.last
      room = host_player.room
      room.update!(poll_pack: pack, game_type: "Poll Game", host: host_player)
      Games::Poll.game_started(room: room.reload, question_count: 1,
                               scoring_mode: "host_choose", timer_enabled: false,
                               show_instructions: false)
      visit room_hand_path(room.code)
      expect(page).to have_content("Get Ready")
    end

    using_session(:player1) do
      visit join_room_path(room.code)
      fill_in "Your name", with: "Player1"
      click_button "Join"
      p1 = Player.last
    end

    using_session(:player2) do
      visit join_room_path(room.code)
      fill_in "Your name", with: "Player2"
      click_button "Join"
      p2 = Player.last
    end

    using_session(:host) do
      click_button "Start Question"
      expect(page).to have_content("Question 1")
    end

    # Players answer — p1 picks Alex, p2 picks Jordan
    using_session(:player1) do
      visit room_hand_path(room.code)
      find("[data-test-id='answer-option-0']").click  # Alex
      expect(page).to have_content("Locked in!")
    end
    using_session(:player2) do
      visit room_hand_path(room.code)
      find("[data-test-id='answer-option-1']").click  # Jordan
      expect(page).to have_content("Locked in!")
    end

    using_session(:host) do
      find("[data-test-id='answer-option-0']").click  # Alex
      click_button "Close Voting"
      expect(page).to have_content("Results")
      # Scores not shown yet — waiting for host to pick
      expect(page).to have_content("Pick the correct answer")
    end

    # Players see "waiting for host"
    using_session(:player1) do
      expect(page).to have_content("Waiting")
    end

    # Host picks Jordan as the answer
    using_session(:host) do
      click_button "✓ Jordan"
      expect(page).to have_content("Answer: Jordan")
    end

    # Only player2 (picked Jordan) should have scored
    q = pack.poll_questions.first
    p1_answer = PollAnswer.find_by(player: p1, poll_question: q)
    p2_answer = PollAnswer.find_by(player: p2, poll_question: q)
    expect(p1_answer.points_awarded).to eq(0)
    expect(p2_answer.points_awarded).to be > 0

    using_session(:player2) do
      expect(page).to have_content("That's the one!")
    end
  end
end
```

- [ ] **Step 3: Run both specs**

```bash
TEST_ENV_NUMBER=2 bin/rspec spec/system/games/bandwagon_happy_path_spec.rb \
                            spec/system/games/bandwagon_host_choose_spec.rb \
                            --format documentation
```

Expected: all examples pass. Fix any failures before continuing.

- [ ] **Step 4: Run full suite**

```bash
TEST_ENV_NUMBER=2 bin/rspec spec/ 2>&1 | tail -30
```

Expected: no regressions.

- [ ] **Step 5: Commit**

```bash
git add spec/system/games/bandwagon_happy_path_spec.rb \
        spec/system/games/bandwagon_host_choose_spec.rb
git commit -m "test: add Bandwagon system specs for majority and host_choose modes"
```

---

## Task 11: Final Verification

- [ ] **Step 1: Run full test suite**

```bash
TEST_ENV_NUMBER=2 bin/rspec spec/ --format progress
```

Expected: green, no failures.

- [ ] **Step 2: Run rubocop auto-fix**

```bash
rubocop -A
```

Expected: clean, or only offenses in files you haven't touched.

- [ ] **Step 3: Run brakeman security scan**

```bash
brakeman -q
```

Expected: no new warnings.

- [ ] **Step 4: Verify the new-game checklist**

From the `/new-game` skill — confirm each item:

- [ ] Model with AASM states (instructions → waiting → answering → reviewing → finished)
- [ ] `HasRoundTimer` included, `process_timeout` implemented
- [ ] Service module: `requires_capacity_check?`, `game_started`, `start_from_instructions`, `handle_timeout`
- [ ] Playtest module nested inside service file
- [ ] `broadcast_all` is single exit point, called outside `with_lock`
- [ ] All stage partials: first child `<div id="stage_*">`, no `px`/`rem`, no inline animations
- [ ] Hand router switches on game state, uses `games/shared/hand_instructions`
- [ ] All host-action forms pass `code: room.code`
- [ ] All controllers include `GameHostAuthorization` and `RendersHand`
- [ ] Routes added for all controllers
- [ ] Registry: `GameEventRouter` + `DevPlaytest::Registry` both registered
- [ ] Room constants: `POLL_GAME`, `GAME_TYPES`, `GAME_DISPLAY_NAMES`

- [ ] **Step 5: Create PR**

```bash
git push origin fix/democracy
gh pr create \
  --title "feat: add Bandwagon polling game mode" \
  --body "$(cat <<'EOF'
## Summary
- New game type: Bandwagon (internal: PollGame) — players score based on majority/minority/host-chosen answers
- Prerequisite: extracted shared `question_list_editor_controller.js` from the 700-line `trivia_editor_controller.js`
- Three scoring modes: majority (popular answer wins), minority (unpopular answer wins), host_choose (host reveals correct answer live — designed for wedding/shower games)
- Speed bonus applies: committing early earns more points, but you don't know which answer is "correct" until voting closes
- Perfect tie in majority/minority mode: no points for anyone

## Decisions
- Internal name `PollGame`, display name "Bandwagon" — keeps routing/model names stable while giving the game product personality
- `host_chosen_answer` stored on `PollGame` (not per-question history) — matches how Speed Trivia handles `correct_answers` at review time; historical question display doesn't need it
- `score_reveal_for` returns `did_win: false` while host_choose answer is pending — hand view shows "Waiting…" until host picks
- Shared `_score_podium` partial reused from Speed Trivia for the reviewing and finished stage views

## Reviewer notes
- The Stimulus extraction (Task 1) is the riskiest piece — verify trivia pack editor still works after the refactor
- The `assign_questions` method in `Games::Poll` directly uses `PollQuestion` records (no snapshot instance like `TriviaQuestionInstance`) — simpler for v1, revisit if question editing mid-game becomes a concern
- `minority` mode with 3+ options: all non-majority answers score (2nd/3rd/4th place all win)

Co-authored with Claude
EOF
)"
```
