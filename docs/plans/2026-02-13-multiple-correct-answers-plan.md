# Multiple Correct Answers Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow speed trivia questions to have multiple correct answers, where players still pick one option and score if it matches any correct answer.

**Architecture:** Replace `correct_answer` (string) with `correct_answers` (jsonb array) on both `trivia_questions` and `trivia_question_instances`. Update correctness check to `correct_answers.include?(selected_option)`. Update all views to display/highlight multiple correct answers. Update CRUD form to use checkboxes instead of radio buttons for correct answer selection.

**Tech Stack:** Rails 8, PostgreSQL (jsonb), Hotwire/Stimulus, RSpec

---

### Task 1: Database Migration

**Files:**
- Create: `db/migrate/TIMESTAMP_replace_correct_answer_with_correct_answers.rb`

**Step 1: Generate the migration**

Run: `bin/rails generate migration ReplaceCorrectAnswerWithCorrectAnswers`

**Step 2: Write the migration**

```ruby
class ReplaceCorrectAnswerWithCorrectAnswers < ActiveRecord::Migration[8.1]
  def up
    # Add new jsonb column to trivia_questions
    add_column :trivia_questions, :correct_answers, :jsonb

    # Migrate existing data: wrap single string in array
    execute <<-SQL
      UPDATE trivia_questions
      SET correct_answers = jsonb_build_array(correct_answer)
      WHERE correct_answer IS NOT NULL
    SQL

    # Remove old column
    remove_column :trivia_questions, :correct_answer

    # Same for trivia_question_instances
    add_column :trivia_question_instances, :correct_answers, :jsonb

    execute <<-SQL
      UPDATE trivia_question_instances
      SET correct_answers = jsonb_build_array(correct_answer)
      WHERE correct_answer IS NOT NULL
    SQL

    remove_column :trivia_question_instances, :correct_answer
  end

  def down
    # Add back old column to trivia_questions
    add_column :trivia_questions, :correct_answer, :string

    execute <<-SQL
      UPDATE trivia_questions
      SET correct_answer = correct_answers->>0
      WHERE correct_answers IS NOT NULL
    SQL

    remove_column :trivia_questions, :correct_answers

    # Same for trivia_question_instances
    add_column :trivia_question_instances, :correct_answer, :string

    execute <<-SQL
      UPDATE trivia_question_instances
      SET correct_answer = correct_answers->>0
      WHERE correct_answers IS NOT NULL
    SQL

    remove_column :trivia_question_instances, :correct_answers
  end
end
```

**Step 3: Run the migration**

Run: `bin/rails db:migrate`
Expected: Migration succeeds, `db/schema.rb` shows `correct_answers` (jsonb) on both tables.

**Step 4: Commit**

```bash
git add db/migrate/*_replace_correct_answer_with_correct_answers.rb db/schema.rb
git commit -m "Replace correct_answer string with correct_answers jsonb array"
```

---

### Task 2: Update TriviaQuestion Model

**Files:**
- Modify: `app/models/trivia_question.rb`
- Test: `spec/models/trivia_question_spec.rb`

**Step 1: Write the failing tests**

Update `spec/models/trivia_question_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe TriviaQuestion, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:trivia_pack) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_presence_of(:options) }

    it 'validates options must be array of four' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, options: ["A", "B", "C"])
      expect(question).not_to be_valid
      expect(question.errors[:options]).to include("must contain exactly 4 choices")
    end

    it 'validates correct_answers must be present' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, correct_answers: [])
      expect(question).not_to be_valid
      expect(question.errors[:correct_answers]).to include("must have at least one correct answer")
    end

    it 'validates correct_answers must be an array' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, correct_answers: "Paris")
      expect(question).not_to be_valid
      expect(question.errors[:correct_answers]).to include("must be an array")
    end

    it 'validates all correct_answers must be in options' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, options: ["A", "B", "C", "D"], correct_answers: ["E"])
      expect(question).not_to be_valid
      expect(question.errors[:correct_answers]).to include("must all be included in options")
    end

    it 'allows multiple correct answers' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, options: ["A", "B", "C", "D"], correct_answers: ["A", "B"])
      expect(question).to be_valid
    end
  end

  describe 'options' do
    it 'stores options as an array' do
      question = create(:trivia_question, options: ["Paris", "London", "Berlin", "Madrid"])
      expect(question.reload.options).to eq(["Paris", "London", "Berlin", "Madrid"])
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bin/rspec spec/models/trivia_question_spec.rb`
Expected: Failures related to `correct_answers` validation.

**Step 3: Update the model**

Replace `app/models/trivia_question.rb`:

```ruby
class TriviaQuestion < ApplicationRecord
  belongs_to :trivia_pack

  validates :body, presence: true
  validates :options, presence: true
  validate :options_must_be_array_of_four
  validate :correct_answers_must_be_valid

  private

  def options_must_be_array_of_four
    unless options.is_a?(Array) && options.length == 4
      errors.add(:options, "must contain exactly 4 choices")
    end
  end

  def correct_answers_must_be_valid
    unless correct_answers.is_a?(Array)
      errors.add(:correct_answers, "must be an array")
      return
    end

    if correct_answers.empty?
      errors.add(:correct_answers, "must have at least one correct answer")
      return
    end

    unless correct_answers.all? { |a| options&.include?(a) }
      errors.add(:correct_answers, "must all be included in options")
    end
  end
end
```

**Step 4: Update the factory**

Update `spec/factories/trivia_questions.rb`:

```ruby
FactoryBot.define do
  factory :trivia_question do
    trivia_pack
    body { "What is the capital of France?" }
    correct_answers { ["Paris"] }
    options { ["Paris", "London", "Berlin", "Madrid"] }
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `bin/rspec spec/models/trivia_question_spec.rb`
Expected: All pass.

**Step 6: Commit**

```bash
git add app/models/trivia_question.rb spec/models/trivia_question_spec.rb spec/factories/trivia_questions.rb
git commit -m "Update TriviaQuestion model for correct_answers array"
```

---

### Task 3: Update TriviaQuestionInstance Model

**Files:**
- Modify: `app/models/trivia_question_instance.rb`
- Test: `spec/models/trivia_question_instance_spec.rb`

**Step 1: Write the failing tests**

Update `spec/models/trivia_question_instance_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe TriviaQuestionInstance, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:speed_trivia_game) }
    it { is_expected.to belong_to(:trivia_question) }
    it { is_expected.to have_many(:trivia_answers) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_presence_of(:position) }

    it 'validates correct_answers presence' do
      instance = build(:trivia_question_instance, correct_answers: [])
      expect(instance).not_to be_valid
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bin/rspec spec/models/trivia_question_instance_spec.rb`

**Step 3: Update the model**

Replace `app/models/trivia_question_instance.rb`:

```ruby
class TriviaQuestionInstance < ApplicationRecord
  belongs_to :speed_trivia_game
  belongs_to :trivia_question
  has_many :trivia_answers, dependent: :destroy

  validates :body, presence: true
  validates :correct_answers, presence: true
  validates :position, presence: true

  def vote_counts
    trivia_answers.group(:selected_option).count
  end

  def total_votes
    trivia_answers.count
  end
end
```

**Step 4: Update the factory**

Update `spec/factories/trivia_question_instances.rb`:

```ruby
FactoryBot.define do
  factory :trivia_question_instance do
    speed_trivia_game
    trivia_question
    body { "What is the capital of France?" }
    correct_answers { ["Paris"] }
    options { ["Paris", "London", "Berlin", "Madrid"] }
    sequence(:position) { |n| n }
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `bin/rspec spec/models/trivia_question_instance_spec.rb`
Expected: All pass.

**Step 6: Commit**

```bash
git add app/models/trivia_question_instance.rb spec/models/trivia_question_instance_spec.rb spec/factories/trivia_question_instances.rb
git commit -m "Update TriviaQuestionInstance model for correct_answers array"
```

---

### Task 4: Update TriviaAnswer Model (Correctness Check)

**Files:**
- Modify: `app/models/trivia_answer.rb`
- Test: `spec/models/trivia_answer_spec.rb`

**Step 1: Write the failing tests**

Update the `#determine_correctness` describe block in `spec/models/trivia_answer_spec.rb`:

```ruby
describe '#determine_correctness' do
  let(:player) { create(:player) }

  context 'with single correct answer' do
    let(:question) { create(:trivia_question_instance, correct_answers: ["Paris"]) }

    def build_answer(option)
      build(:trivia_answer, trivia_question_instance: question, player:, selected_option: option)
    end

    it 'sets correct to true when answer matches' do
      answer = build_answer("Paris")
      answer.determine_correctness
      expect(answer.correct).to be true
    end

    it 'sets correct to false when answer does not match' do
      answer = build_answer("London")
      answer.determine_correctness
      expect(answer.correct).to be false
    end

    it 'is case sensitive' do
      answer = build_answer("paris")
      answer.determine_correctness
      expect(answer.correct).to be false
    end
  end

  context 'with multiple correct answers' do
    let(:question) { create(:trivia_question_instance, correct_answers: ["Paris", "Berlin"]) }

    def build_answer(option)
      build(:trivia_answer, trivia_question_instance: question, player:, selected_option: option)
    end

    it 'sets correct to true when answer matches first correct answer' do
      answer = build_answer("Paris")
      answer.determine_correctness
      expect(answer.correct).to be true
    end

    it 'sets correct to true when answer matches second correct answer' do
      answer = build_answer("Berlin")
      answer.determine_correctness
      expect(answer.correct).to be true
    end

    it 'sets correct to false when answer matches no correct answer' do
      answer = build_answer("London")
      answer.determine_correctness
      expect(answer.correct).to be false
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bin/rspec spec/models/trivia_answer_spec.rb`

**Step 3: Update the model**

In `app/models/trivia_answer.rb`, change `determine_correctness`:

```ruby
def determine_correctness
  self.correct = trivia_question_instance.correct_answers.include?(selected_option)
end
```

**Step 4: Run tests to verify they pass**

Run: `bin/rspec spec/models/trivia_answer_spec.rb`
Expected: All pass.

**Step 5: Also update the `#calculate_points` tests**

The `#calculate_points` tests in the same file reference `correct_answer:` in factory calls. Update these to use `correct_answers: ["Paris"]`. Search for `correct_answer: "Paris"` in the `calculate_points` describe block and replace with `correct_answers: ["Paris"]`.

**Step 6: Run full test file**

Run: `bin/rspec spec/models/trivia_answer_spec.rb`
Expected: All pass.

**Step 7: Commit**

```bash
git add app/models/trivia_answer.rb spec/models/trivia_answer_spec.rb
git commit -m "Update TriviaAnswer correctness check for multiple correct answers"
```

---

### Task 5: Update Games::SpeedTrivia Service

**Files:**
- Modify: `app/services/games/speed_trivia.rb`
- Test: `spec/services/games/speed_trivia_spec.rb`

**Step 1: Update the service**

In `app/services/games/speed_trivia.rb`, change line 154 in `assign_questions`:

Old: `correct_answer: question.correct_answer,`
New: `correct_answers: question.correct_answers,`

**Step 2: Update the spec**

In `spec/services/games/speed_trivia_spec.rb`, update the `.submit_answer` before block (line 91):

Old: `correct_answer: "Paris",`
New: `correct_answers: ["Paris"],`

**Step 3: Run the spec**

Run: `bin/rspec spec/services/games/speed_trivia_spec.rb`
Expected: All pass.

**Step 4: Commit**

```bash
git add app/services/games/speed_trivia.rb spec/services/games/speed_trivia_spec.rb
git commit -m "Update SpeedTrivia service for correct_answers array"
```

---

### Task 6: Update Game Views

**Files:**
- Modify: `app/views/games/speed_trivia/_stage_reviewing.html.erb`
- Modify: `app/views/games/speed_trivia/_waiting.html.erb`
- Modify: `app/views/games/speed_trivia/_vote_summary.html.erb`
- Modify: `app/views/games/speed_trivia/_host_controls.html.erb`

**Step 1: Update stage reviewing view**

In `app/views/games/speed_trivia/_stage_reviewing.html.erb`, replace the correct answer display (lines 14-19):

Old:
```erb
<div class="flex items-center justify-center gap-4">
  <span class="text-6xl">✓</span>
  <h2 class="text-5xl md:text-7xl font-black text-green-400">
    <%= current_question&.correct_answer %>
  </h2>
</div>
```

New:
```erb
<div class="flex flex-wrap items-center justify-center gap-4">
  <span class="text-6xl">✓</span>
  <% current_question&.correct_answers&.each do |answer| %>
    <h2 class="text-5xl md:text-7xl font-black text-green-400">
      <%= answer %>
    </h2>
  <% end %>
</div>
```

**Step 2: Update player waiting/reviewing view**

In `app/views/games/speed_trivia/_waiting.html.erb`, update lines 35 and 39 where `correct_answer` is shown:

Replace both instances of:
```erb
<span class="font-bold text-green-400"><%= current_question.correct_answer %></span>
```
and:
```erb
<span class="font-bold text-green-400"><%= current_question&.correct_answer %></span>
```

With:
```erb
<span class="font-bold text-green-400"><%= current_question.correct_answers.join(", ") %></span>
```
and:
```erb
<span class="font-bold text-green-400"><%= current_question&.correct_answers&.join(", ") %></span>
```

**Step 3: Update vote summary view**

In `app/views/games/speed_trivia/_vote_summary.html.erb`, change line 10:

Old: `<% is_correct = option == question.correct_answer %>`
New: `<% is_correct = question.correct_answers.include?(option) %>`

**Step 4: Update host controls view**

In `app/views/games/speed_trivia/_host_controls.html.erb`, update two references:

Line 44 — Old: `<p class="text-green-400 text-sm">Correct: <%= current_q&.correct_answer %></p>`
New: `<p class="text-green-400 text-sm">Correct: <%= current_q&.correct_answers&.join(", ") %></p>`

Line 68 — Old: `<p class="text-green-400">Answer: <%= current_q&.correct_answer %></p>`
New: `<p class="text-green-400">Answer: <%= current_q&.correct_answers&.join(", ") %></p>`

**Step 5: Commit**

```bash
git add app/views/games/speed_trivia/_stage_reviewing.html.erb \
       app/views/games/speed_trivia/_waiting.html.erb \
       app/views/games/speed_trivia/_vote_summary.html.erb \
       app/views/games/speed_trivia/_host_controls.html.erb
git commit -m "Update game views to display multiple correct answers"
```

---

### Task 7: Update Trivia Pack CRUD (Show View)

**Files:**
- Modify: `app/views/trivia_packs/show.html.erb:96-97`

**Step 1: Update the show view**

Replace the two references to `question.correct_answer`:

Line 96 — Old: `option == question.correct_answer`
New: `question.correct_answers.include?(option)`

Line 97 — Old: `if option == question.correct_answer`
New: `if question.correct_answers.include?(option)`

**Step 2: Commit**

```bash
git add app/views/trivia_packs/show.html.erb
git commit -m "Update trivia pack show view for correct_answers array"
```

---

### Task 8: Update Trivia Pack CRUD (Form + Stimulus Controller)

**Files:**
- Modify: `app/views/trivia_packs/_form.html.erb`
- Modify: `app/javascript/controllers/trivia_editor_controller.js`
- Modify: `app/controllers/trivia_packs_controller.rb`

**Step 1: Update the form — existing questions section**

In `app/views/trivia_packs/_form.html.erb`, change the correct answer section for existing questions (~lines 95-116):

Change radio buttons to checkboxes. Replace:
```erb
<label class="block text-xs font-bold text-blue-200 mb-2 uppercase tracking-widest">Correct Answer</label>
```
With:
```erb
<label class="block text-xs font-bold text-blue-200 mb-2 uppercase tracking-widest">Correct Answer(s)</label>
```

Change radio inputs to checkboxes:
- `type="radio"` → `type="checkbox"`
- `name="<%= q.object_name %>[correct_answer_index]"` → `name="<%= q.object_name %>[correct_answer_indices][]"`
- `<%= 'checked' if q.object.options&.at(i) == q.object.correct_answer %>` → `<%= 'checked' if q.object.correct_answers&.include?(q.object.options&.at(i)) %>`
- `data-action="change->trivia-editor#updateCorrectAnswer"` → `data-action="change->trivia-editor#updateCorrectAnswers"`
- Radio style: `peer-checked:border-green-500 peer-checked:bg-green-500/20 peer-checked:text-green-300` stays the same (works with checkboxes too)

Replace the hidden field:
```erb
<%= q.hidden_field :correct_answer, data: { trivia_editor_target: "correctAnswerField" } %>
```
With:
```erb
<input type="hidden" name="<%= q.object_name %>[correct_answers][]" value="" data-trivia-editor-target="correctAnswersField">
```

Note: We'll use multiple hidden fields dynamically managed by JS instead of a single hidden field.

**Step 2: Update the form — template section for new questions**

Same changes in the template section (~lines 159-180):
- Radio → checkbox
- `correct_answer_index` → `correct_answer_indices[]`
- `correct_answer` hidden → `correct_answers[]` hidden
- `data-action` → `change->trivia-editor#updateCorrectAnswers`

**Step 3: Update the Stimulus controller**

In `app/javascript/controllers/trivia_editor_controller.js`:

1. Rename target: `correctAnswerField` → `correctAnswersField`
2. Update `createQuestionField` method to handle `correct_answers` array
3. Replace `updateCorrectAnswer` with `updateCorrectAnswers` that collects all checked options
4. Update `optionChanged` to update correct_answers when option text changes

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["questionList", "questionTemplate", "countDisplay", "questionField", "optionField", "correctAnswersField"]
    static values = { ratio: { type: Number, default: 1 } }

    connect() {
        this.updateCount()
    }

    addQuestion(event) {
        if (event) event.preventDefault()
        this.createQuestionField({ body: "", options: ["", "", "", ""], correct_answers: [] })
    }

    createQuestionField(data) {
        const timestamp = new Date().getTime() + Math.floor(Math.random() * 1000)
        const content = this.questionTemplateTarget.innerHTML.replace(
            /NEW_RECORD/g,
            timestamp
        )

        this.questionListTarget.insertAdjacentHTML('afterbegin', content)

        const wrapper = this.questionListTarget.firstElementChild

        // Set question body
        const bodyField = wrapper.querySelector("textarea[name*='[body]']")
        if (bodyField && data.body) {
            bodyField.value = data.body
        }

        // Set options
        const optionFields = wrapper.querySelectorAll("input[name*='[options]']")
        if (data.options && Array.isArray(data.options)) {
            data.options.forEach((option, index) => {
                if (optionFields[index]) {
                    optionFields[index].value = option
                }
            })
        }

        // Set correct answers
        if (data.correct_answers && Array.isArray(data.correct_answers)) {
            const checkboxes = wrapper.querySelectorAll("input[name*='[correct_answer_indices]']")
            data.correct_answers.forEach(answer => {
                const correctIndex = data.options?.indexOf(answer) ?? -1
                if (correctIndex >= 0 && checkboxes[correctIndex]) {
                    checkboxes[correctIndex].checked = true
                }
            })
            this.syncCorrectAnswersFields(wrapper)
        }

        this.updateCount()
    }

    removeQuestion(event) {
        event.preventDefault()

        const wrapper = event.target.closest(".question-field-wrapper")

        if (wrapper.dataset.newRecord === "true") {
            wrapper.remove()
        } else {
            wrapper.style.display = "none"
            wrapper.querySelector("input[name*='_destroy']").value = "1"
        }

        this.updateCount()
    }

    updateCorrectAnswers(event) {
        const questionWrapper = event.target.closest(".question-field-wrapper")
        this.syncCorrectAnswersFields(questionWrapper)
    }

    syncCorrectAnswersFields(questionWrapper) {
        const checkboxes = questionWrapper.querySelectorAll("input[name*='[correct_answer_indices]']")
        const optionFields = questionWrapper.querySelectorAll("input[name*='[options]']")

        // Remove existing correct_answers hidden fields
        questionWrapper.querySelectorAll("input[name*='[correct_answers]']").forEach(f => f.remove())

        // Add a hidden field for each checked option
        const checkedOptions = []
        checkboxes.forEach((checkbox, index) => {
            if (checkbox.checked && optionFields[index]) {
                checkedOptions.push(optionFields[index].value)
            }
        })

        // Insert hidden fields before the delete button area
        const insertPoint = questionWrapper.querySelector("input[name*='_destroy']") || questionWrapper.lastElementChild
        checkedOptions.forEach(value => {
            const hidden = document.createElement("input")
            hidden.type = "hidden"
            hidden.name = insertPoint.name.replace("[_destroy]", "[correct_answers][]").replace(/\[options\]\[\]/, "[correct_answers][]")
            // Derive the base name from any existing field
            const anyField = questionWrapper.querySelector("input[name*='[body]'], textarea[name*='[body]']")
            if (anyField) {
                const baseName = anyField.name.replace("[body]", "[correct_answers][]")
                hidden.name = baseName
            }
            hidden.value = value
            insertPoint.parentElement.insertBefore(hidden, insertPoint)
        })
    }

    optionChanged(event) {
        const questionWrapper = event.target.closest(".question-field-wrapper")
        this.syncCorrectAnswersFields(questionWrapper)
    }

    updateCount() {
        const visibleQuestions = this.questionFieldTargets.filter(field => {
            const wrapper = field.closest(".question-field-wrapper")
            const destroyInput = wrapper.querySelector("input[name*='_destroy']")

            return wrapper.style.display !== "none" && (!destroyInput || destroyInput.value !== "1")
        })

        const count = visibleQuestions.length
        const playerCapacity = Math.floor(count / this.ratioValue)
        this.countDisplayTarget.textContent = playerCapacity

        if (playerCapacity > 20) {
            this.countDisplayTarget.classList.add("text-red-600")
            this.countDisplayTarget.classList.remove("text-white")
        } else {
            this.countDisplayTarget.classList.remove("text-red-600")
            this.countDisplayTarget.classList.add("text-white")
        }
    }
}
```

**Step 4: Update the controller strong params**

In `app/controllers/trivia_packs_controller.rb`, change the permitted params:

Old: `:correct_answer,`
New: `correct_answers: [],`

**Step 5: Run the trivia pack CRUD system test**

Run: `bin/rspec spec/system/trivia_packs_crud_spec.rb`
Note: This test will need updates too (Task 10 covers test fixes).

**Step 6: Commit**

```bash
git add app/views/trivia_packs/_form.html.erb \
       app/javascript/controllers/trivia_editor_controller.js \
       app/controllers/trivia_packs_controller.rb
git commit -m "Update trivia pack CRUD form for multiple correct answers"
```

---

### Task 9: Update Seed Data

**Files:**
- Modify: `config/standard_trivia.yml`
- Modify: `db/seeds.rb`

**Step 1: Update the YAML format**

In `config/standard_trivia.yml`, change every `correct_answer: "X"` to `correct_answers: ["X"]`.

Add one multi-answer question at the end:

```yaml
- body: "Which of these animals can fly?"
  correct_answers:
    - "Eagle"
    - "Bat"
  options:
    - "Eagle"
    - "Penguin"
    - "Bat"
    - "Ostrich"
```

**Step 2: Update seeds.rb**

In `db/seeds.rb`, change line 44:

Old: `q.correct_answer = question_data["correct_answer"]`
New: `q.correct_answers = question_data["correct_answers"]`

**Step 3: Verify seeds load**

Run: `bin/rails db:seed`
Expected: Seeds load without errors.

**Step 4: Commit**

```bash
git add config/standard_trivia.yml db/seeds.rb
git commit -m "Update seed data for correct_answers array format"
```

---

### Task 10: Fix Remaining Tests

**Files:**
- Modify: `spec/system/trivia_packs_crud_spec.rb`
- Modify: `spec/system/games/speed_trivia_happy_path_spec.rb` (if it references correct_answer)
- Modify: any other specs that reference `correct_answer`

**Step 1: Find all remaining references**

Run: `grep -r "correct_answer" spec/ --include="*.rb" -l` to find all files still using the old field name.

**Step 2: Update each file**

For factory calls: change `correct_answer: "X"` to `correct_answers: ["X"]`
For system tests referencing CRUD forms: update to use checkboxes instead of radio buttons.

In `spec/system/trivia_packs_crud_spec.rb`:
- Change `correct_answer_index` references to `correct_answer_indices`
- Change `correct_answer` hidden field references to `correct_answers`
- Update the `editing` test factory call: `correct_answer: "A"` → `correct_answers: ["A"]`
- Update the `viewing` test factory call similarly

**Step 3: Run all trivia-related tests**

Run: `bin/rspec spec/models/trivia_question_spec.rb spec/models/trivia_question_instance_spec.rb spec/models/trivia_answer_spec.rb spec/services/games/speed_trivia_spec.rb spec/system/trivia_packs_crud_spec.rb`
Expected: All pass.

**Step 4: Run the full test suite**

Run: `bin/rspec`
Expected: All pass, no regressions.

**Step 5: Commit**

```bash
git add spec/
git commit -m "Fix remaining tests for correct_answers migration"
```

---

### Task 11: Code Quality Check

**Step 1: Run rubocop**

Run: `rubocop`
If issues: `rubocop -A` to auto-fix, then review changes.

**Step 2: Run brakeman**

Run: `brakeman -q`
Expected: No new warnings.

**Step 3: Commit any fixes**

```bash
git add -A
git commit -m "Fix rubocop/brakeman issues"
```

---

### Task 12: Final Verification

**Step 1: Run full test suite one more time**

Run: `bin/rspec`
Expected: All green.

**Step 2: Build Tailwind for test environment (if in worktree)**

Run: `RAILS_ENV=test bin/rails tailwindcss:build`

**Step 3: Run system tests specifically**

Run: `bin/rspec spec/system/`
Expected: All pass.
