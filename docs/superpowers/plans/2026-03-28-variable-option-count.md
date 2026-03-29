# Variable Option Count Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow 1-4 answer options per trivia question, with enhanced results display (percentages, bigger cards for 1-2 options).

**Architecture:** Model validation change (hardcoded 4 → range 1-4), view partial updates for adaptive grid layouts, and Stimulus controller changes for dynamic option add/remove in the editor.

**Tech Stack:** Rails 8, AASM, Hotwire (Turbo + Stimulus), Tailwind CSS, RSpec

**Spec:** `docs/superpowers/specs/2026-03-28-variable-option-count-design.md`

---

### Task 1: Model Validation — Allow 1-4 Options

**Files:**
- Modify: `app/models/trivia_question.rb:17-18,43-47`
- Test: `spec/models/trivia_question_spec.rb`

- [ ] **Step 1: Update existing spec to expect new validation message**

In `spec/models/trivia_question_spec.rb`, replace the test at line 12-16:

```ruby
it 'validates options must have 1-4 entries' do
  trivia_pack = create(:trivia_pack)

  question = build(:trivia_question, trivia_pack:, options: [])
  expect(question).not_to be_valid
  expect(question.errors[:options]).to include("must contain between 1 and 4 choices")

  question = build(:trivia_question, trivia_pack:, options: ["A"])
  expect(question).to be_valid

  question = build(:trivia_question, trivia_pack:, options: ["A", "B"])
  expect(question).to be_valid

  question = build(:trivia_question, trivia_pack:, options: ["A", "B", "C"])
  expect(question).to be_valid

  question = build(:trivia_question, trivia_pack:, options: ["A", "B", "C", "D"])
  expect(question).to be_valid

  question = build(:trivia_question, trivia_pack:, options: ["A", "B", "C", "D", "E"])
  expect(question).not_to be_valid
  expect(question.errors[:options]).to include("must contain between 1 and 4 choices")
end
```

For the test at line 49 that checks multiple correct answers, also add a 2-option variant:

```ruby
it 'allows multiple correct answers' do
  trivia_pack = create(:trivia_pack)
  question = build(:trivia_question, trivia_pack:, options: ["A", "B", "C", "D"], correct_answers: ["A", "B"])
  expect(question).to be_valid
end

it 'allows all options marked correct (poll-style)' do
  trivia_pack = create(:trivia_pack)
  question = build(:trivia_question, trivia_pack:, options: ["John", "Janice"], correct_answers: ["John", "Janice"])
  expect(question).to be_valid
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rspec spec/models/trivia_question_spec.rb`
Expected: Failures on the new validation message and the 1/2/3 option cases.

- [ ] **Step 3: Update model validation**

In `app/models/trivia_question.rb`, replace lines 17-18 and 43-52:

```ruby
# Replace:
OPTIONS_COUNT = 4

# With:
MIN_OPTIONS = 1
MAX_OPTIONS = 4
```

```ruby
# Replace the entire options_must_be_array_of_four method with:
def options_must_have_valid_count
  unless options.is_a?(Array) && options.length.between?(MIN_OPTIONS, MAX_OPTIONS)
    errors.add(:options, "must contain between #{MIN_OPTIONS} and #{MAX_OPTIONS} choices")
    return
  end

  if options.any?(&:blank?)
    errors.add(:options, "must not contain blank choices")
  end
end
```

Update the `validate` call at line 9 from `:options_must_be_array_of_four` to `:options_must_have_valid_count`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rspec spec/models/trivia_question_spec.rb`
Expected: All pass.

- [ ] **Step 5: Run rubocop on changed files**

Run: `rubocop app/models/trivia_question.rb spec/models/trivia_question_spec.rb -A`

- [ ] **Step 6: Commit**

```bash
git add app/models/trivia_question.rb spec/models/trivia_question_spec.rb
git commit -m "feat: allow 1-4 answer options per trivia question

Relaxes TriviaQuestion validation from exactly 4 options to 1-4.
No migration needed — options is already a Postgres array column."
```

---

### Task 2: Vote Summary Partial — Adaptive Layout with Percentages

**Files:**
- Modify: `app/views/games/speed_trivia/_vote_summary.html.erb`
- Modify: `app/models/trivia_question_instance.rb` (add `vote_percentage` helper)

- [ ] **Step 1: Add percentage helper to TriviaQuestionInstance**

In `app/models/trivia_question_instance.rb`, add after the `total_votes` method:

```ruby
def vote_percentage(option)
  total = total_votes
  return 0 if total.zero?

  count = vote_counts[option] || 0
  (count.to_f / total * 100).round
end
```

- [ ] **Step 2: Run existing speed trivia specs to confirm nothing breaks**

Run: `bin/rspec spec/system/games/speed_trivia_happy_path_spec.rb`
Expected: All pass (no behavior change yet).

- [ ] **Step 3: Rewrite the vote summary partial**

Replace `app/views/games/speed_trivia/_vote_summary.html.erb` entirely:

```erb
<%# app/views/games/speed_trivia/_vote_summary.html.erb %>
<%# Adaptive vote summary: Face-Off Cards for 1-2 options, compact grid for 3-4. %>
<% vote_counts = question.vote_counts %>
<% total = question.total_votes %>
<% option_count = question.options.size %>

<% if option_count <= 2 %>
  <%# Face-Off Cards — big, dramatic, with percentage %>
  <% colors = [
    { bg: "bg-blue-500/20", border: "border-blue-500", text: "text-blue-400" },
    { bg: "bg-purple-500/20", border: "border-purple-500", text: "text-purple-400" }
  ] %>
  <div class="flex gap-[2vh] max-w-4xl w-full shrink-0 justify-center">
    <% question.options.each_with_index do |option, index| %>
      <% votes = vote_counts[option] || 0 %>
      <% pct = question.vote_percentage(option) %>
      <% is_correct = question.correct_answers.include?(option) %>
      <% color = colors[index] || colors[0] %>

      <div class="<%= color[:bg] %> backdrop-blur-md border-2 <%= is_correct ? 'border-green-500 bg-green-500/10' : color[:border] %> rounded-2xl p-[2vh] flex flex-col items-center text-center gap-[1vh] flex-1 max-w-sm">
        <div class="bg-white text-black font-black text-vh-2xl h-[5vh] w-[5vh] rounded-full flex items-center justify-center shrink-0">
          <%= (index + 65).chr %>
        </div>
        <p class="text-vh-lg text-white font-bold"><%= option %></p>
        <div class="text-vh-4xl font-black <%= is_correct ? 'text-green-400' : color[:text] %> font-mono">
          <%= total > 0 ? "#{pct}%" : "—" %>
        </div>
        <div class="text-vh-sm text-gray-400"><%= votes %> <%= votes == 1 ? "vote" : "votes" %></div>
      </div>
    <% end %>
  </div>

<% else %>
  <%# Compact grid — 3 or 4 columns with percentage added %>
  <div class="grid grid-cols-<%= option_count %> gap-[1.5vh] max-w-6xl w-full shrink-0">
    <% question.options.each_with_index do |option, index| %>
      <% votes = vote_counts[option] || 0 %>
      <% pct = question.vote_percentage(option) %>
      <% is_correct = question.correct_answers.include?(option) %>

      <div class="bg-black/40 backdrop-blur-md border-2 <%= is_correct ? 'border-green-500 bg-green-500/10' : 'border-gray-600' %> rounded-xl p-[1.5vh] flex flex-col items-center text-center gap-[0.5vh]">
        <div class="bg-white text-black font-black text-vh-lg h-[4vh] w-[4vh] rounded-full flex items-center justify-center shrink-0">
          <%= (index + 65).chr %>
        </div>
        <p class="text-vh-sm text-white font-bold line-clamp-2 flex-grow"><%= option %></p>
        <div class="text-vh-2xl font-black <%= is_correct ? 'text-green-400' : 'text-blue-300' %> font-mono">
          <%= total > 0 ? "#{pct}%" : "—" %>
        </div>
        <div class="text-vh-xs text-gray-400"><%= votes %> <%= votes == 1 ? "vote" : "votes" %></div>
      </div>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 4: Run rubocop on changed files**

Run: `rubocop app/models/trivia_question_instance.rb`

- [ ] **Step 5: Commit**

```bash
git add app/views/games/speed_trivia/_vote_summary.html.erb app/models/trivia_question_instance.rb
git commit -m "feat: adaptive vote summary with percentages

Face-Off Cards for 1-2 options (bigger, percentage-first).
Compact grid for 3-4 options with percentage added.
Adds vote_percentage helper to TriviaQuestionInstance."
```

---

### Task 3: Stage Answering Partial — Adaptive Grid

**Files:**
- Modify: `app/views/games/speed_trivia/_stage_answering.html.erb:35`

- [ ] **Step 1: Update the options grid to adapt by option count**

In `app/views/games/speed_trivia/_stage_answering.html.erb`, replace the options grid div (line 35):

```erb
<%# Replace: %>
<div class="grid grid-cols-1 md:grid-cols-2 gap-[2vh] w-full max-w-6xl px-[2vh]">

<%# With: %>
<% grid_class = case current_question&.options&.size
                when 1 then "grid-cols-1 max-w-md mx-auto"
                when 3 then "grid-cols-3"
                else "grid-cols-1 md:grid-cols-2"
                end %>
<div class="grid <%= grid_class %> gap-[2vh] w-full max-w-6xl px-[2vh]">
```

- [ ] **Step 2: Run existing system specs**

Run: `bin/rspec spec/system/games/speed_trivia_happy_path_spec.rb`
Expected: All pass (still using 4-option questions by default).

- [ ] **Step 3: Commit**

```bash
git add app/views/games/speed_trivia/_stage_answering.html.erb
git commit -m "feat: adaptive stage grid for variable option counts

1 option: centered single card. 3 options: single row.
2 and 4 options: 2-column grid (existing behavior)."
```

---

### Task 4: Hand Answer Form — Verify Variable Options Work

**Files:**
- Modify: `app/views/games/speed_trivia/_answer_form.html.erb:20,41`

The hand form already iterates `options.each_with_index` and has `options.size` guards. Only changes needed:

- [ ] **Step 1: Handle 1-option centering in the "already answered" grid**

In `app/views/games/speed_trivia/_answer_form.html.erb`, line 20, the grid already uses `grid-cols-2`. For 1 option, the single card should center. Update line 20:

```erb
<%# Replace: %>
<div class="grid <%= options.size <= 2 ? 'grid-cols-2' : 'grid-cols-2' %> gap-3 flex-1 mb-4">

<%# With: %>
<div class="grid <%= options.size == 1 ? 'grid-cols-1 max-w-[50%] mx-auto' : 'grid-cols-2' %> gap-3 flex-1 mb-4">
```

Also update the active answer grid at line 41:

```erb
<%# Replace: %>
<div class="grid grid-cols-2 gap-3 flex-1" data-controller="games--speed-trivia">

<%# With: %>
<div class="grid <%= options.size == 1 ? 'grid-cols-1 max-w-[50%] mx-auto' : 'grid-cols-2' %> gap-3 flex-1" data-controller="games--speed-trivia">
```

- [ ] **Step 2: Commit**

```bash
git add app/views/games/speed_trivia/_answer_form.html.erb
git commit -m "feat: center single-option answer button on hand view"
```

---

### Task 5: Trivia Editor — Dynamic Option Add/Remove

**Files:**
- Modify: `app/views/trivia_packs/_form.html.erb:94-112,211-227` (both the existing questions block and the `<template>`)
- Modify: `app/javascript/controllers/trivia_editor_controller.js`

This is the largest task. The editor currently hardcodes `4.times` for option fields. We need to make option fields dynamically addable/removable.

- [ ] **Step 1: Update the existing question options block in `_form.html.erb`**

Replace the options grid (lines 94-112) for existing questions:

```erb
<!-- Options Grid -->
<div class="grid grid-cols-1 gap-2 mb-3" data-trivia-editor-target="optionsContainer">
  <% (q.object.options || ["", "", "", ""]).each_with_index do |option_value, i| %>
    <div class="flex items-center gap-2" data-trivia-editor-target="optionRow">
      <span class="inline-flex items-center justify-center w-6 h-6 bg-blue-500/20 text-blue-300 font-bold text-xs rounded flex-shrink-0" data-trivia-editor-target="optionLetter">
        <%= ('A'.ord + i).chr %>
      </span>
      <input type="text"
             name="<%= q.object_name %>[options][]"
             value="<%= option_value %>"
             placeholder="Option <%= ('A'.ord + i).chr %>"
             data-trivia-editor-target="optionField"
             data-action="input->trivia-editor#optionChanged"
             class="flex-1 rounded-lg bg-white/10 border border-white/10 focus:border-orange-500 focus:ring focus:ring-orange-500/20 text-sm font-medium text-white placeholder-white/30 transition-all px-3 py-2">
      <button type="button"
              data-action="trivia-editor#removeOption"
              class="text-white/20 hover:text-red-400 p-1 rounded hover:bg-red-500/10 transition-colors"
              aria-label="Remove option">
        <%= lucide_icon('x', class: "w-4 h-4", "aria-hidden": true) %>
      </button>
    </div>
  <% end %>
  <button type="button"
          data-action="trivia-editor#addOption"
          class="<%= (q.object.options || []).size >= 4 ? 'hidden' : '' %> text-xs text-blue-300 hover:text-white font-bold flex items-center gap-1 mt-1 px-2 py-1 rounded hover:bg-white/10 transition-colors"
          data-trivia-editor-target="addOptionButton">
    <%= lucide_icon('plus', class: "w-3 h-3", "aria-hidden": true) %>
    Add Option
  </button>
</div>
```

- [ ] **Step 2: Update the correct answers block for existing questions**

Replace the correct answer(s) section (lines 114-133). Instead of hardcoded `4.times`, render based on actual options:

```erb
<!-- Correct Answer(s) Selection -->
<div class="mb-3">
  <label class="block text-xs font-bold text-blue-200 mb-2 uppercase tracking-widest">Correct Answer(s)</label>
  <div class="flex gap-2" data-trivia-editor-target="correctAnswerButtons">
    <% (q.object.options || ["", "", "", ""]).each_with_index do |_opt, i| %>
      <label class="flex-1 cursor-pointer">
        <input type="checkbox"
               name="<%= q.object_name %>[correct_answer_indices][]"
               value="<%= i %>"
               <%= 'checked' if q.object.correct_answers&.include?(q.object.options&.at(i)) %>
               data-action="change->trivia-editor#updateCorrectAnswers"
               class="sr-only peer">
        <div class="text-center py-2 px-3 rounded-lg bg-white/10 border-2 border-white/10 peer-checked:border-green-500 peer-checked:bg-green-500/20 peer-checked:text-green-300 text-blue-200 font-bold text-xs transition-all hover:bg-white/20">
          <%= ('A'.ord + i).chr %>
        </div>
      </label>
    <% end %>
  </div>
</div>
```

- [ ] **Step 3: Update the `<template>` for new questions**

Replace the options grid inside the `<template>` (lines 211-227):

```erb
<!-- Options Grid -->
<div class="grid grid-cols-1 gap-2 mb-3" data-trivia-editor-target="optionsContainer">
  <% 4.times do |i| %>
    <div class="flex items-center gap-2" data-trivia-editor-target="optionRow">
      <span class="inline-flex items-center justify-center w-6 h-6 bg-blue-500/20 text-blue-300 font-bold text-xs rounded flex-shrink-0" data-trivia-editor-target="optionLetter">
        <%= ('A'.ord + i).chr %>
      </span>
      <input type="text"
             name="trivia_pack[trivia_questions_attributes][NEW_RECORD][options][]"
             placeholder="Option <%= ('A'.ord + i).chr %>"
             data-trivia-editor-target="optionField"
             data-action="input->trivia-editor#optionChanged"
             class="flex-1 rounded-lg bg-white/10 border border-white/10 focus:border-orange-500 focus:ring focus:ring-orange-500/20 text-sm font-medium text-white placeholder-white/30 transition-all px-3 py-2">
      <button type="button"
              data-action="trivia-editor#removeOption"
              class="text-white/20 hover:text-red-400 p-1 rounded hover:bg-red-500/10 transition-colors"
              aria-label="Remove option">
        <%= lucide_icon('x', class: "w-4 h-4", "aria-hidden": true) %>
      </button>
    </div>
  <% end %>
  <button type="button"
          data-action="trivia-editor#addOption"
          class="hidden text-xs text-blue-300 hover:text-white font-bold flex items-center gap-1 mt-1 px-2 py-1 rounded hover:bg-white/10 transition-colors"
          data-trivia-editor-target="addOptionButton">
    <%= lucide_icon('plus', class: "w-3 h-3", "aria-hidden": true) %>
    Add Option
  </button>
</div>
```

Also replace the correct answers section in the template (lines 229-243):

```erb
<!-- Correct Answer(s) Selection -->
<div class="mb-3">
  <label class="block text-xs font-bold text-blue-200 mb-2 uppercase tracking-widest">Correct Answer(s)</label>
  <div class="flex gap-2" data-trivia-editor-target="correctAnswerButtons">
    <% 4.times do |i| %>
      <label class="flex-1 cursor-pointer">
        <input type="checkbox"
               name="trivia_pack[trivia_questions_attributes][NEW_RECORD][correct_answer_indices][]"
               value="<%= i %>"
               data-action="change->trivia-editor#updateCorrectAnswers"
               class="sr-only peer">
        <div class="text-center py-2 px-3 rounded-lg bg-white/10 border-2 border-white/10 peer-checked:border-green-500 peer-checked:bg-green-500/20 peer-checked:text-green-300 text-blue-200 font-bold text-xs transition-all hover:bg-white/20">
          <%= ('A'.ord + i).chr %>
        </div>
      </label>
    <% end %>
  </div>
</div>
```

- [ ] **Step 4: Update the Stimulus controller with add/remove option methods**

In `app/javascript/controllers/trivia_editor_controller.js`, add `"optionRow", "optionLetter", "optionsContainer", "addOptionButton", "correctAnswerButtons"` to the static targets array.

Add these methods:

```javascript
// --- Add / Remove Options ---

addOption(event) {
    event.preventDefault()
    const wrapper = event.target.closest(".question-field-wrapper")
    const container = wrapper.querySelector("[data-trivia-editor-target='optionsContainer']")
    const rows = container.querySelectorAll("[data-trivia-editor-target='optionRow']")
    if (rows.length >= 4) return

    const index = rows.length
    const letter = String.fromCharCode(65 + index)

    // Derive field name from an existing option input
    const existingInput = rows[0].querySelector("input[type='text']")
    const baseName = existingInput.name // e.g. "trivia_pack[trivia_questions_attributes][0][options][]"

    const row = document.createElement("div")
    row.className = "flex items-center gap-2"
    row.setAttribute("data-trivia-editor-target", "optionRow")
    row.innerHTML = `
        <span class="inline-flex items-center justify-center w-6 h-6 bg-blue-500/20 text-blue-300 font-bold text-xs rounded flex-shrink-0" data-trivia-editor-target="optionLetter">${letter}</span>
        <input type="text"
               name="${this.escapeHtml(baseName)}"
               placeholder="Option ${letter}"
               data-trivia-editor-target="optionField"
               data-action="input->trivia-editor#optionChanged"
               class="flex-1 rounded-lg bg-white/10 border border-white/10 focus:border-orange-500 focus:ring focus:ring-orange-500/20 text-sm font-medium text-white placeholder-white/30 transition-all px-3 py-2">
        <button type="button"
                data-action="trivia-editor#removeOption"
                class="text-white/20 hover:text-red-400 p-1 rounded hover:bg-red-500/10 transition-colors"
                aria-label="Remove option">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
        </button>
    `

    // Insert before the "Add Option" button
    const addBtn = container.querySelector("[data-trivia-editor-target='addOptionButton']")
    container.insertBefore(row, addBtn)

    // Add corresponding correct answer button
    this.addCorrectAnswerButton(wrapper, index, letter)

    this.updateOptionState(wrapper)
    this.syncCorrectAnswersFields(wrapper)

    // Focus the new input
    row.querySelector("input[type='text']").focus()
}

removeOption(event) {
    event.preventDefault()
    const wrapper = event.target.closest(".question-field-wrapper")
    const container = wrapper.querySelector("[data-trivia-editor-target='optionsContainer']")
    const rows = container.querySelectorAll("[data-trivia-editor-target='optionRow']")
    if (rows.length <= 1) return

    const row = event.target.closest("[data-trivia-editor-target='optionRow']")
    const rowIndex = Array.from(rows).indexOf(row)
    row.remove()

    // Remove corresponding correct answer button
    this.removeCorrectAnswerButton(wrapper, rowIndex)

    // Re-letter remaining options and correct answer buttons
    this.updateOptionState(wrapper)
    this.syncCorrectAnswersFields(wrapper)
}

addCorrectAnswerButton(wrapper, index, letter) {
    const container = wrapper.querySelector("[data-trivia-editor-target='correctAnswerButtons']")
    const existingCheckbox = container.querySelector("input[type='checkbox']")
    const baseName = existingCheckbox.name.replace(/\[\d+\]$/, `[]`) // keep the array name pattern

    const label = document.createElement("label")
    label.className = "flex-1 cursor-pointer"
    label.innerHTML = `
        <input type="checkbox"
               name="${this.escapeHtml(existingCheckbox.name)}"
               value="${index}"
               data-action="change->trivia-editor#updateCorrectAnswers"
               class="sr-only peer">
        <div class="text-center py-2 px-3 rounded-lg bg-white/10 border-2 border-white/10 peer-checked:border-green-500 peer-checked:bg-green-500/20 peer-checked:text-green-300 text-blue-200 font-bold text-xs transition-all hover:bg-white/20">
            ${letter}
        </div>
    `
    container.appendChild(label)
}

removeCorrectAnswerButton(wrapper, removedIndex) {
    const container = wrapper.querySelector("[data-trivia-editor-target='correctAnswerButtons']")
    const labels = container.querySelectorAll("label")
    if (labels[removedIndex]) {
        labels[removedIndex].remove()
    }
}

updateOptionState(wrapper) {
    const container = wrapper.querySelector("[data-trivia-editor-target='optionsContainer']")
    const rows = container.querySelectorAll("[data-trivia-editor-target='optionRow']")
    const addBtn = container.querySelector("[data-trivia-editor-target='addOptionButton']")

    // Re-letter option rows
    rows.forEach((row, i) => {
        const letter = String.fromCharCode(65 + i)
        const letterEl = row.querySelector("[data-trivia-editor-target='optionLetter']")
        if (letterEl) letterEl.textContent = letter

        const input = row.querySelector("input[type='text']")
        if (input) input.placeholder = `Option ${letter}`

        // Disable remove button if only 1 option remains
        const removeBtn = row.querySelector("[data-action='trivia-editor#removeOption']")
        if (removeBtn) {
            removeBtn.disabled = rows.length <= 1
            removeBtn.classList.toggle("opacity-10", rows.length <= 1)
            removeBtn.classList.toggle("pointer-events-none", rows.length <= 1)
        }
    })

    // Show/hide add button
    if (addBtn) {
        addBtn.classList.toggle("hidden", rows.length >= 4)
    }

    // Re-letter and re-index correct answer buttons
    const correctContainer = wrapper.querySelector("[data-trivia-editor-target='correctAnswerButtons']")
    if (correctContainer) {
        const labels = correctContainer.querySelectorAll("label")
        labels.forEach((label, i) => {
            const letter = String.fromCharCode(65 + i)
            const checkbox = label.querySelector("input[type='checkbox']")
            if (checkbox) checkbox.value = i
            const div = label.querySelector("div")
            if (div) div.textContent = letter
        })
    }
}
```

- [ ] **Step 5: Update `createQuestionField` to call `updateOptionState`**

In the existing `createQuestionField` method, add at the end (before `this.updatePositions()`):

```javascript
// Initialize option add/remove state
this.updateOptionState(wrapper)
```

- [ ] **Step 6: Run rubocop and verify editor works manually**

Run: `rubocop app/views/trivia_packs/_form.html.erb`

- [ ] **Step 7: Commit**

```bash
git add app/views/trivia_packs/_form.html.erb app/javascript/controllers/trivia_editor_controller.js
git commit -m "feat: dynamic add/remove options in trivia editor

Each option field gets an X button to remove (disabled at min 1).
Add Option button appears when below 4 options.
New questions still default to 4 fields for zero friction.
Correct answer buttons stay synced when options are added/removed."
```

---

### Task 6: System Test — Mixed Option Count Game

**Files:**
- Create: `spec/system/games/speed_trivia_variable_options_spec.rb`

- [ ] **Step 1: Write system spec for a game with mixed 2-option and 4-option questions**

```ruby
require "rails_helper"

RSpec.describe "Speed Trivia with variable option counts", :js, type: :system do
  it "plays through questions with different option counts" do
    pack = create(:trivia_pack)
    create(:trivia_question,
      trivia_pack: pack,
      body: "Who will change more diapers?",
      options: ["John", "Janice"],
      correct_answers: ["John", "Janice"],
      position: 1
    )
    create(:trivia_question,
      trivia_pack: pack,
      body: "What is the capital of France?",
      options: ["Paris", "London", "Berlin", "Madrid"],
      correct_answers: ["Paris"],
      position: 2
    )

    host_session = Capybara::Session.new(:playwright)
    player_session = Capybara::Session.new(:playwright)

    # Host creates room
    host_session.visit "/"
    host_session.click_on "Host a Game"
    host_session.select "Think Fast", from: "Game"
    host_session.click_on "Create Room"

    code = host_session.find("[data-test-id='room-code']").text

    # Player joins
    player_session.visit "/"
    player_session.fill_in "Room Code", with: code
    player_session.fill_in "Your Name", with: "Alice"
    player_session.click_on "Join"

    # Assign pack and start
    room = Room.find_by(code: code)
    room.update!(trivia_pack: pack)
    Games::SpeedTrivia.game_started(room: room, question_count: 2, show_instructions: false, timer_enabled: false)

    # Start question 1 (2 options)
    Games::SpeedTrivia.start_question(game: room.current_game)

    # Stage should show 2 options
    host_session.visit "/stages/#{code}"
    expect(host_session).to have_content("Who will change more diapers?")
    expect(host_session).to have_content("John")
    expect(host_session).to have_content("Janice")

    # Player answers
    player_session.visit "/rooms/#{code}/hand"
    expect(player_session).to have_css("[data-test-id='answer-option-0']")
    expect(player_session).not_to have_css("[data-test-id='answer-option-2']")
    player_session.find("[data-test-id='answer-option-0']").click
    expect(player_session).to have_content("Locked in!")

    # Close round — results should show percentage
    Games::SpeedTrivia.close_round(game: room.current_game.reload)
    host_session.visit "/stages/#{code}"
    expect(host_session).to have_content("100%")
    expect(host_session).to have_content("1 vote")

    # Advance to question 2 (4 options)
    Games::SpeedTrivia.next_question(game: room.current_game.reload)
    host_session.visit "/stages/#{code}"
    expect(host_session).to have_content("What is the capital of France?")
    expect(host_session).to have_content("Paris")
    expect(host_session).to have_content("Madrid")

    # Player should see 4 options
    player_session.visit "/rooms/#{code}/hand"
    expect(player_session).to have_css("[data-test-id='answer-option-0']")
    expect(player_session).to have_css("[data-test-id='answer-option-3']")
  ensure
    host_session&.quit
    player_session&.quit
  end
end
```

- [ ] **Step 2: Build Tailwind CSS for test environment**

Run: `RAILS_ENV=test bin/rails tailwindcss:build`

- [ ] **Step 3: Run the system spec**

Run: `bin/rspec spec/system/games/speed_trivia_variable_options_spec.rb`
Expected: Pass.

- [ ] **Step 4: Run full speed trivia test suite to catch regressions**

Run: `bin/rspec spec/system/games/speed_trivia_happy_path_spec.rb spec/system/games/speed_trivia_score_display_spec.rb spec/models/trivia_question_spec.rb`
Expected: All pass.

- [ ] **Step 5: Run rubocop**

Run: `rubocop spec/system/games/speed_trivia_variable_options_spec.rb -A`

- [ ] **Step 6: Commit**

```bash
git add spec/system/games/speed_trivia_variable_options_spec.rb
git commit -m "test: system spec for mixed option count Think Fast game

Plays through a 2-option poll question and a 4-option trivia question,
verifying stage display, hand answer buttons, and percentage results."
```

---

### Task 7: Brakeman + Final Checks

- [ ] **Step 1: Run brakeman**

Run: `brakeman -q`
Expected: No new warnings.

- [ ] **Step 2: Run full test suite**

Run: `bin/rspec`
Expected: All pass.

- [ ] **Step 3: Run rubocop on all changed files**

Run: `rubocop -A`
Expected: No offenses.
