# Trivia Question Images Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow users to attach optional images to trivia questions, displayed Kahoot-style on the stage (image above text + options), with browser preloading for zero-lag display during gameplay.

**Architecture:** Active Storage `has_one_attached :image` on both `TriviaQuestion` (editor source) and `TriviaQuestionInstance` (gameplay snapshot). The blob is shared at game-start time (no file copy), so storage is not duplicated. Images upload directly from the browser to Cloudflare R2 via Active Storage's DirectUpload mechanism. The stage preloads all images with `<link rel="preload">` during the instructions/waiting phase.

**Tech Stack:** Rails 8 Active Storage, Cloudflare R2 (already configured), `image_processing` gem (already in Gemfile for variants), `@rails/activestorage` JS (needs to be pinned), Stimulus for inline preview, Tailwind CSS for layout.

---

## Orientation: Key Files

Before starting, familiarise yourself with these files:

| File | What it does |
|---|---|
| `app/models/trivia_question.rb` | Question model — gets `has_one_attached :image` |
| `app/models/trivia_question_instance.rb` | Gameplay snapshot — also gets `has_one_attached :image` |
| `app/models/trivia_pack.rb` | Pack model — gets 20-image cap validation |
| `app/services/games/speed_trivia.rb` | `assign_questions` method (line 140) copies data from question → instance |
| `app/controllers/trivia_packs_controller.rb` | `trivia_pack_params` (line 52) needs `:image` and `:remove_image` |
| `app/views/trivia_packs/_form.html.erb` | The question editor form and its `<template>` block |
| `app/javascript/controllers/trivia_editor_controller.js` | Stimulus controller for the question editor |
| `app/views/games/speed_trivia/_stage_answering.html.erb` | Stage view during answering phase |
| `app/views/games/speed_trivia/_stage_reviewing.html.erb` | Stage view during reviewing phase |
| `app/views/games/speed_trivia/_stage_instructions.html.erb` | Stage view before game starts |
| `app/views/games/speed_trivia/_stage_waiting.html.erb` | Stage "Get Ready!" view |
| `config/importmap.rb` | JS package pins |
| `app/javascript/application.js` | Top-level JS entry point |
| `config/storage.yml` | Active Storage services (test = Disk, dev/prod = R2) |

**Test environment is already configured:** `config/environments/test.rb` sets `config.active_storage.service = :test` and `config/storage.yml` has a `test:` Disk service. No test setup changes needed.

---

## Task 1: Wire Up Active Storage DirectUpload JavaScript

Active Storage's direct-upload JS is not yet imported. Without it, `direct_upload: true` file inputs silently fall back to normal server-side uploads. We wire it up first so every later task builds on the correct foundation.

**Files:**
- Modify: `config/importmap.rb`
- Modify: `app/javascript/application.js`

**Step 1: Pin @rails/activestorage in the importmap**

Rails ships `activestorage.esm.js` as a built-in asset. Add this line to `config/importmap.rb`:

```ruby
pin "@rails/activestorage", to: "activestorage.esm.js"
```

**Step 2: Import and start Active Storage in application.js**

```javascript
// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
```

**Step 3: Verify the app still boots**

```bash
bin/rails runner "puts 'ok'"
```

Expected: prints `ok` with no errors.

**Step 4: Commit**

```bash
git add config/importmap.rb app/javascript/application.js
git commit -m "Wire up Active Storage DirectUpload JS"
```

---

## Task 2: TriviaQuestion — Image Attachment + Validations

**Files:**
- Modify: `app/models/trivia_question.rb`
- Modify: `spec/models/trivia_question_spec.rb`

### Background

`TriviaQuestion` is the user-owned question record. It gets `has_one_attached :image` with two validations:
- Content type must be JPEG, PNG, WebP, or GIF
- File size must be under 5MB

Both validations only fire when an image is being attached (Active Storage skips them if no image is attached, so image remains fully optional).

**Step 1: Write the failing tests**

Add to the `'validations'` describe block in `spec/models/trivia_question_spec.rb`:

```ruby
describe 'image attachment' do
  it 'is valid with no image attached' do
    question = build(:trivia_question)
    expect(question).to be_valid
  end

  it 'is valid with an acceptable image type' do
    question = build(:trivia_question)
    question.image.attach(
      io: StringIO.new("fake image content"),
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )
    expect(question).to be_valid
  end

  it 'is invalid with a disallowed content type' do
    question = build(:trivia_question)
    question.image.attach(
      io: StringIO.new("fake pdf content"),
      filename: "doc.pdf",
      content_type: "application/pdf"
    )
    expect(question).not_to be_valid
    expect(question.errors[:image]).to be_present
  end

  it 'is invalid when image exceeds 5MB' do
    question = build(:trivia_question)
    # Attach a blob whose byte_size is over the limit without uploading 5MB of data
    question.image.attach(
      io: StringIO.new("x"),
      filename: "big.jpg",
      content_type: "image/jpeg"
    )
    # Stub byte_size to simulate an oversized file
    allow(question.image.blob).to receive(:byte_size).and_return(6.megabytes)
    expect(question).not_to be_valid
    expect(question.errors[:image]).to be_present
  end
end
```

**Step 2: Run to confirm failure**

```bash
bin/rspec spec/models/trivia_question_spec.rb -e "image attachment" --format documentation
```

Expected: 3 failures (the `be_valid` with an image and disallowed type / oversized tests fail because no validations exist yet; the "no image" test may pass already since no image attachment is defined).

**Step 3: Add the attachment and validations to the model**

```ruby
class TriviaQuestion < ApplicationRecord
  belongs_to :trivia_pack
  has_one_attached :image

  validates :body, presence: true
  validates :options, presence: true
  validate :options_must_be_array_of_four
  validate :correct_answers_must_be_valid
  validates :image,
    content_type: { in: %w[image/jpeg image/png image/webp image/gif],
                    message: "must be a JPEG, PNG, WebP, or GIF" },
    size: { less_than: 5.megabytes, message: "must be less than 5MB" }

  private

  # ... existing private methods unchanged
```

**Step 4: Run tests to confirm they pass**

```bash
bin/rspec spec/models/trivia_question_spec.rb --format documentation
```

Expected: all pass.

**Step 5: Commit**

```bash
git add app/models/trivia_question.rb spec/models/trivia_question_spec.rb
git commit -m "Add image attachment to TriviaQuestion with content type and size validations"
```

---

## Task 3: TriviaPack — Max 20 Images Per Pack Validation

**Files:**
- Modify: `app/models/trivia_pack.rb`
- Modify: `spec/models/trivia_pack_spec.rb`

### Background

A pack with more than 20 image-bearing questions could run up storage costs from a single user. This is enforced as a model validation so it's checked on every save.

**Step 1: Write the failing test**

Add to `spec/models/trivia_pack_spec.rb`:

```ruby
describe 'image count validation' do
  it 'is valid with 20 or fewer questions that have images' do
    pack = create(:trivia_pack)
    20.times do
      q = create(:trivia_question, trivia_pack: pack)
      q.image.attach(io: StringIO.new("img"), filename: "x.jpg", content_type: "image/jpeg")
    end
    expect(pack).to be_valid
  end

  it 'is invalid when more than 20 questions have images' do
    pack = create(:trivia_pack)
    21.times do
      q = create(:trivia_question, trivia_pack: pack)
      q.image.attach(io: StringIO.new("img"), filename: "x.jpg", content_type: "image/jpeg")
    end
    expect(pack).not_to be_valid
    expect(pack.errors[:base]).to include("cannot have more than 20 questions with images")
  end
end
```

**Step 2: Run to confirm failure**

```bash
bin/rspec spec/models/trivia_pack_spec.rb -e "image count" --format documentation
```

Expected: 2 failures.

**Step 3: Add the custom validation to TriviaPack**

Add after the `before_validation :set_default_name` line in `app/models/trivia_pack.rb`:

```ruby
validate :image_count_within_limit

# inside private section:

def image_count_within_limit
  count = trivia_questions.select { |q| q.image.attached? }.count
  if count > 20
    errors.add(:base, "cannot have more than 20 questions with images")
  end
end
```

**Step 4: Run tests**

```bash
bin/rspec spec/models/trivia_pack_spec.rb --format documentation
```

Expected: all pass.

**Step 5: Commit**

```bash
git add app/models/trivia_pack.rb spec/models/trivia_pack_spec.rb
git commit -m "Add 20-image-per-pack cap validation on TriviaPack"
```

---

## Task 4: TriviaQuestionInstance — Image Snapshot at Game Start

**Files:**
- Modify: `app/models/trivia_question_instance.rb`
- Modify: `app/services/games/speed_trivia.rb`
- Modify: `spec/services/games/speed_trivia_spec.rb` (create if it doesn't exist — check with `ls spec/services/`)

### Background

`TriviaQuestionInstance` is a snapshot created at game start via `assign_questions` in `app/services/games/speed_trivia.rb` (line 140). It currently copies `body`, `options`, `correct_answers`. We add `has_one_attached :image` and update `assign_questions` to also copy the blob reference — not the file itself (the same blob is shared between question and instance, using no extra storage).

**Step 1: Add `has_one_attached :image` to TriviaQuestionInstance**

```ruby
class TriviaQuestionInstance < ApplicationRecord
  belongs_to :speed_trivia_game
  belongs_to :trivia_question
  has_many :trivia_answers, dependent: :destroy
  has_one_attached :image

  # ... rest unchanged
```

**Step 2: Write the failing test for assign_questions image copy**

Check whether `spec/services/` directory exists:

```bash
ls spec/services/games/ 2>/dev/null || echo "directory missing"
```

If missing, create it:

```bash
mkdir -p spec/services/games
```

Create or add to `spec/services/games/speed_trivia_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Games::SpeedTrivia do
  describe '.assign_questions' do
    let(:room) { create(:room) }
    let(:pack) { create(:trivia_pack) }
    let(:game) { create(:speed_trivia_game, trivia_pack: pack) }

    context 'when a question has an image' do
      it 'copies the image blob to the question instance' do
        question = create(:trivia_question, trivia_pack: pack)
        question.image.attach(
          io: StringIO.new("fake image"),
          filename: "test.jpg",
          content_type: "image/jpeg"
        )

        Games::SpeedTrivia.send(:assign_questions, game:, question_count: 1)

        instance = game.trivia_question_instances.first
        expect(instance.image).to be_attached
        expect(instance.image.blob).to eq(question.image.blob)
      end
    end

    context 'when a question has no image' do
      it 'creates an instance with no image' do
        create(:trivia_question, trivia_pack: pack)

        Games::SpeedTrivia.send(:assign_questions, game:, question_count: 1)

        instance = game.trivia_question_instances.first
        expect(instance.image).not_to be_attached
      end
    end
  end
end
```

**Step 3: Run to confirm failure**

```bash
bin/rspec spec/services/games/speed_trivia_spec.rb --format documentation
```

Expected: "copies the image blob" fails because `TriviaQuestionInstance` doesn't have `has_one_attached :image` yet and `assign_questions` doesn't copy it.

**Step 4: Update `assign_questions` in `app/services/games/speed_trivia.rb`**

Find the `assign_questions` method (line 140) and update it:

```ruby
def self.assign_questions(game:, question_count:)
  pack = game.trivia_pack || TriviaPack.default
  available_questions = pack.trivia_questions.to_a

  if available_questions.size < question_count
    raise "Not enough trivia questions to start game."
  end

  selected_questions = available_questions.sample(question_count)

  selected_questions.each_with_index do |question, index|
    instance = TriviaQuestionInstance.create!(
      speed_trivia_game: game,
      trivia_question: question,
      body: question.body,
      correct_answers: question.correct_answers,
      options: question.options,
      position: index
    )
    instance.image.attach(question.image.blob) if question.image.attached?
  end
end
```

**Step 5: Run tests**

```bash
bin/rspec spec/services/games/speed_trivia_spec.rb --format documentation
```

Expected: all pass.

**Step 6: Commit**

```bash
git add app/models/trivia_question_instance.rb app/services/games/speed_trivia.rb spec/services/games/speed_trivia_spec.rb
git commit -m "Snapshot image blob onto TriviaQuestionInstance at game start"
```

---

## Task 5: Controller — Permit Image Params

**Files:**
- Modify: `app/controllers/trivia_packs_controller.rb`

### Background

The `trivia_pack_params` method whitelists nested attributes for questions. We add `:image` (the file field) and `:remove_image` (a Rails-generated virtual attribute — when set to `"1"`, Active Storage purges the attachment on save).

No new tests needed here; the system test in Task 10 covers it end-to-end.

**Step 1: Update `trivia_pack_params`**

Find the `trivia_pack_params` method (line 52) and update:

```ruby
def trivia_pack_params
  params.require(:trivia_pack).permit(
    :name,
    :game_type,
    :status,
    trivia_questions_attributes: [
      :id,
      :body,
      :_destroy,
      :image,
      :remove_image,
      correct_answers: [],
      options: []
    ]
  )
end
```

**Step 2: Verify rubocop passes**

```bash
rubocop app/controllers/trivia_packs_controller.rb
```

**Step 3: Commit**

```bash
git add app/controllers/trivia_packs_controller.rb
git commit -m "Permit :image and :remove_image in trivia question nested params"
```

---

## Task 6: Form UI — Image Upload, Preview, and Remove

**Files:**
- Modify: `app/views/trivia_packs/_form.html.erb`

### Background

Each question card in the form gets an image section below the body textarea. This section has:
1. If question already has an image: a thumbnail of the current image + "Remove" button
2. A file input for uploading/replacing an image
3. An empty `<img>` preview tag (hidden until user picks a file)

The Stimulus actions `trivia-editor#previewImage` and `trivia-editor#removeImage` are wired up here. They're implemented in Task 7.

The `<template>` block for newly added questions needs the same UI (it uses `NEW_RECORD` placeholder names just like the existing options do).

**Step 1: Add the image section to the existing question card**

In `_form.html.erb`, find this comment in the question card (inside `form.fields_for :trivia_questions`):

```erb
<!-- Delete Button -->
<%= q.hidden_field :_destroy %>
```

Insert the image section **before** the `<!-- Delete Button -->` block:

```erb
<!-- Image Upload -->
<div class="mt-3 mb-3">
  <label class="block text-xs font-bold text-blue-200 mb-2 uppercase tracking-widest">Question Image (optional)</label>

  <%# Show existing image thumbnail and remove option %>
  <% if q.object.image.attached? %>
    <div class="mb-2 flex items-start gap-3" data-trivia-editor-target="existingImageContainer">
      <%= image_tag q.object.image.variant(resize_to_limit: [400, 225]),
            class: "rounded-lg object-cover h-24 w-auto border border-white/20",
            alt: "Question image" %>
      <label class="flex items-center gap-1.5 cursor-pointer text-red-300 hover:text-red-200 text-xs font-bold mt-1">
        <%= q.check_box :remove_image, { class: "sr-only peer", data: { action: "change->trivia-editor#removeImage" } } %>
        <%= lucide_icon('trash-2', class: "w-4 h-4", "aria-hidden": true) %>
        Remove image
      </label>
    </div>
  <% end %>

  <%# Preview shown after user picks a new file (hidden until JS shows it) %>
  <img data-trivia-editor-target="imagePreview"
       class="hidden mb-2 rounded-lg object-cover h-24 w-auto border border-white/20"
       alt="Image preview" />

  <%# File input — direct_upload sends file straight to R2, bypassing Rails server %>
  <%= q.file_field :image,
        accept: "image/jpeg,image/png,image/webp,image/gif",
        direct_upload: true,
        class: "block w-full text-xs text-blue-200 file:mr-3 file:py-1.5 file:px-3 file:rounded-lg file:border-0 file:bg-white/10 file:text-white file:font-bold hover:file:bg-white/20 cursor-pointer",
        data: { action: "change->trivia-editor#previewImage", trivia_editor_target: "imageInput" } %>
</div>
```

**Step 2: Add the same image section to the `<template>` block**

In the `<template data-trivia-editor-target="questionTemplate">` block, find the equivalent location (before the Delete Button comment in that block) and add:

```erb
<!-- Image Upload -->
<div class="mt-3 mb-3">
  <label class="block text-xs font-bold text-blue-200 mb-2 uppercase tracking-widest">Question Image (optional)</label>
  <img data-trivia-editor-target="imagePreview"
       class="hidden mb-2 rounded-lg object-cover h-24 w-auto border border-white/20"
       alt="Image preview" />
  <input type="file"
         name="trivia_pack[trivia_questions_attributes][NEW_RECORD][image]"
         accept="image/jpeg,image/png,image/webp,image/gif"
         data-direct-upload-url="<%= rails_direct_uploads_url %>"
         data-action="change->trivia-editor#previewImage"
         data-trivia-editor-target="imageInput"
         class="block w-full text-xs text-blue-200 file:mr-3 file:py-1.5 file:px-3 file:rounded-lg file:border-0 file:bg-white/10 file:text-white file:font-bold hover:file:bg-white/20 cursor-pointer">
</div>
```

Note: in the template, we use a raw `<input type="file">` with `data-direct-upload-url` explicitly set because ERB form helpers aren't available inside `<template>`.

**Step 3: Verify the app renders without error**

```bash
bin/rails runner "puts 'ok'"
```

Visit `http://localhost:3000/trivia_packs/new` in the browser and confirm the image upload section appears under each question's body field.

**Step 4: Commit**

```bash
git add app/views/trivia_packs/_form.html.erb
git commit -m "Add image upload UI to trivia question editor form"
```

---

## Task 7: Stimulus — previewImage and removeImage Actions

**Files:**
- Modify: `app/javascript/controllers/trivia_editor_controller.js`

### Background

Two new actions on the existing `trivia-editor` Stimulus controller:

- `previewImage(event)` — fires when user selects a file. Uses `FileReader` to read the file from disk and display it immediately in the `imagePreview` target `<img>` tag. This is instant (no network round-trip). The Active Storage DirectUpload begins in parallel.
- `removeImage(event)` — fires when the "Remove image" checkbox is checked. Hides the existing image container so the user sees it's queued for removal.

**Step 1: Add the new targets**

Find the `static targets = [...]` line and add `"imagePreview"`, `"imageInput"`, and `"existingImageContainer"`:

```javascript
static targets = ["questionList", "questionTemplate", "countDisplay", "questionField", "optionField", "correctAnswersContainer", "imagePreview", "imageInput", "existingImageContainer"]
```

**Step 2: Add the previewImage action**

Add this method to the controller class (before the closing `}`):

```javascript
previewImage(event) {
  const file = event.target.files[0]
  if (!file) return

  // Find the preview <img> in the same question card
  const wrapper = event.target.closest(".question-field-wrapper")
  const preview = wrapper.querySelector("[data-trivia-editor-target='imagePreview']")
  if (!preview) return

  const reader = new FileReader()
  reader.onload = (e) => {
    preview.src = e.target.result
    preview.classList.remove("hidden")
  }
  reader.readAsDataURL(file)
}
```

**Step 3: Add the removeImage action**

```javascript
removeImage(event) {
  const wrapper = event.target.closest(".question-field-wrapper")
  const container = wrapper.querySelector("[data-trivia-editor-target='existingImageContainer']")
  if (container) {
    container.style.opacity = event.target.checked ? "0.3" : "1"
  }
}
```

**Step 4: Verify rubocop/linting is clean**

```bash
rubocop --only Style/FrozenStringLiteralComment app/javascript/ 2>/dev/null || echo "not a Ruby file, skip"
```

(JS linting: nothing configured. Just verify the file is syntactically valid by loading the app.)

**Step 5: Commit**

```bash
git add app/javascript/controllers/trivia_editor_controller.js
git commit -m "Add previewImage and removeImage actions to trivia editor Stimulus controller"
```

---

## Task 8: Stage Views — Image Layout (Answering + Reviewing)

**Files:**
- Modify: `app/views/games/speed_trivia/_stage_answering.html.erb`
- Modify: `app/views/games/speed_trivia/_stage_reviewing.html.erb`

### Background

When a question has an image, the stage splits: image on top (~35vh), question text and options below. When no image, the question text expands naturally (the image slot simply doesn't render — no empty space).

All sizing uses `vh` units per the project convention. The stage never scrolls.

### stage_answering

Replace the entire file content with:

```erb
<div id="stage_answering" class="flex flex-col items-center justify-center flex-1 animate-fade-in">
  <% current_question = game.current_question %>

  <!-- Question Counter -->
  <div class="mb-[2vh]">
    <span class="text-vh-2xl text-blue-200 font-bold uppercase tracking-widest">
      Question <%= game.current_question_index + 1 %> of <%= game.trivia_question_instances.count %>
    </span>
  </div>

  <% if current_question&.image&.attached? %>
    <!-- Question Image -->
    <div class="w-full max-w-6xl mb-[2vh] px-[2vh]">
      <%= image_tag current_question.image.variant(resize_to_limit: [1920, 900]),
            class: "w-full h-[35vh] object-contain rounded-2xl shadow-2xl",
            alt: "" %>
    </div>

    <!-- Question Display (compact with image) -->
    <div class="relative bg-white/10 backdrop-blur-xl border border-white/20 rounded-3xl p-[2vh] shadow-2xl text-center max-w-6xl w-full mb-[2vh]">
      <h2 class="text-vh-3xl font-black text-white leading-tight">
        <%= current_question.body %>
      </h2>
    </div>
  <% else %>
    <!-- Question Display (full size without image) -->
    <div class="relative bg-white/10 backdrop-blur-xl border border-white/20 rounded-3xl p-[3vh] shadow-2xl text-center max-w-6xl w-full mb-[3vh]">
      <h2 class="text-vh-4xl font-black text-white leading-tight">
        <%= current_question&.body || "Loading question..." %>
      </h2>
    </div>
  <% end %>

  <!-- Options Grid -->
  <div class="grid grid-cols-1 md:grid-cols-2 gap-[2vh] w-full max-w-6xl px-[2vh]">
    <% if current_question %>
      <% current_question.options&.each_with_index do |option, index| %>
        <div class="bg-gray-800/80 backdrop-blur-md border-2 border-gray-600 rounded-2xl p-[2vh] flex items-center shadow-lg">
          <div class="bg-white text-black font-black text-vh-3xl h-[6vh] w-[6vh] rounded-full flex items-center justify-center mr-[2vh] shrink-0 shadow-md">
            <%= (index + 65).chr %>
          </div>
          <p class="text-vh-xl text-white font-bold">
            <%= option %>
          </p>
        </div>
      <% end %>
    <% end %>
  </div>

  <div class="mt-[3vh]">
    <p class="text-vh-2xl text-blue-200 animate-pulse font-semibold">Answer on your device!</p>
  </div>
</div>
```

### stage_reviewing

Replace the entire file content with:

```erb
<div id="stage_reviewing" class="flex flex-col items-center justify-center flex-1 animate-fade-in">
  <% current_question = game.current_question %>

  <!-- Question Counter -->
  <div class="mb-[2vh]">
    <span class="text-vh-2xl text-blue-200 font-bold uppercase tracking-widest">
      Question <%= game.current_question_index + 1 %> Results
    </span>
  </div>

  <% if current_question&.image&.attached? %>
    <!-- Question Image -->
    <div class="w-full max-w-6xl mb-[2vh] px-[2vh]">
      <%= image_tag current_question.image.variant(resize_to_limit: [1920, 900]),
            class: "w-full h-[25vh] object-contain rounded-2xl shadow-2xl",
            alt: "" %>
    </div>
  <% end %>

  <!-- Question with Answer -->
  <div class="bg-white/10 backdrop-blur-xl border border-white/20 rounded-3xl p-[3vh] shadow-2xl text-center max-w-6xl w-full mb-[2vh]">
    <p class="text-vh-2xl text-blue-200 mb-[2vh]"><%= current_question&.body %></p>
    <div class="flex flex-wrap items-center justify-center gap-[2vh]">
      <% current_question&.correct_answers&.each do |answer| %>
        <div class="flex items-center gap-2">
          <span class="text-vh-3xl">✓</span>
          <h2 class="text-vh-4xl font-black text-green-400"><%= answer %></h2>
        </div>
      <% end %>
    </div>
  </div>

  <%= render "games/speed_trivia/vote_summary", question: current_question %>
</div>
```

**Step: Commit**

```bash
git add app/views/games/speed_trivia/_stage_answering.html.erb \
        app/views/games/speed_trivia/_stage_reviewing.html.erb
git commit -m "Add Kahoot-style image layout to stage answering and reviewing views"
```

---

## Task 9: Stage Views — Preload Tags for Zero-Lag Images

**Files:**
- Modify: `app/views/games/speed_trivia/_stage_instructions.html.erb`
- Modify: `app/views/games/speed_trivia/_stage_waiting.html.erb`

### Background

The stage screen stays on one page for the entire game. During the instructions and waiting phases (before any questions appear), the browser is idle. We inject `<link rel="preload" as="image">` tags for all question images so the browser fetches them in the background. By the time question 1 appears via Turbo Stream, every image is already in the browser cache.

This is pure HTML — no JavaScript, no server-side caching, no architecture change.

### stage_instructions

Add preload tags at the **top** of `_stage_instructions.html.erb`, before the existing `<div id="stage_instructions">`:

```erb
<%# Preload all question images so they display instantly when questions appear %>
<% game.trivia_question_instances.each do |q| %>
  <% if q.image.attached? %>
    <link rel="preload" as="image" href="<%= url_for(q.image) %>">
  <% end %>
<% end %>

<div id="stage_instructions" class="flex flex-col items-center justify-center flex-1 animate-fade-in">
  <%# ... rest of file unchanged ... %>
```

### stage_waiting

Same pattern — add preload tags at the top of `_stage_waiting.html.erb`:

```erb
<%# Preload all question images so they display instantly when questions appear %>
<% game.trivia_question_instances.each do |q| %>
  <% if q.image.attached? %>
    <link rel="preload" as="image" href="<%= url_for(q.image) %>">
  <% end %>
<% end %>

<div id="stage_waiting" class="flex flex-col items-center justify-center flex-1 animate-fade-in">
  <%# ... rest of file unchanged ... %>
```

**Step: Commit**

```bash
git add app/views/games/speed_trivia/_stage_instructions.html.erb \
        app/views/games/speed_trivia/_stage_waiting.html.erb
git commit -m "Preload question images during instructions/waiting phase for zero-lag display"
```

---

## Task 10: System Test — Upload Image, Verify Preview and Persistence

**Files:**
- Create: `spec/fixtures/files/test_image.png` (a tiny valid PNG)
- Modify: `spec/system/trivia_packs_crud_spec.rb`

### Background

This system test verifies the full round-trip:
1. User attaches an image to a question in the editor
2. The inline preview appears immediately
3. After saving, the image is persisted on the question
4. The "Remove image" UI appears on next edit

Active Storage uses Disk storage in the test environment (`config/environments/test.rb` already sets `config.active_storage.service = :test`), so no R2 credentials needed.

**Step 1: Create a minimal valid PNG fixture**

Run this one-time command to generate a 1×1 white PNG:

```bash
ruby -e "
data = [137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,1,0,0,0,1,8,2,0,0,0,144,119,83,222,0,0,0,12,73,68,65,84,8,215,99,248,255,255,63,0,5,254,2,254,220,204,89,231,0,0,0,0,73,69,78,68,174,66,96,130].pack('C*')
File.write('spec/fixtures/files/test_image.png', data)
puts 'Created test_image.png'
"
```

**Step 2: Add the system test**

Add a new `describe` block to `spec/system/trivia_packs_crud_spec.rb`:

```ruby
describe "uploading an image to a question" do
  it "shows an inline preview and persists the image on save" do
    visit new_trivia_pack_path
    fill_in "Name", with: "Image Test Pack"

    # Fill the question
    find("textarea[data-trivia-editor-target='questionField']").set("Which planet is this?")
    all("input[name*='[options]']")[0].set("Mars")
    all("input[name*='[options]']")[1].set("Venus")
    all("input[name*='[options]']")[2].set("Earth")
    all("input[name*='[options]']")[3].set("Jupiter")
    checkbox = all("input[name*='[correct_answer_indices]']")[0]
    page.execute_script("arguments[0].click();", checkbox)

    # Attach image
    image_path = Rails.root.join("spec/fixtures/files/test_image.png")
    attach_file(find("input[type='file'][data-trivia-editor-target='imageInput']")[:id], image_path)

    # Inline preview should appear
    preview = find("img[data-trivia-editor-target='imagePreview']")
    expect(preview).not_to have_css(".hidden")
    expect(preview[:src]).to start_with("data:image/png;base64")

    screenshot_checkpoint("trivia_question_image_preview")
    click_button "Save Pack"

    expect(page).to have_content("Trivia pack created successfully")

    # Verify image was persisted
    question = TriviaPack.last.trivia_questions.first
    expect(question.image).to be_attached
    expect(question.image.filename.to_s).to eq("test_image.png")
  end

  it "removes an image when the remove checkbox is checked" do
    pack = create(:trivia_pack, user:)
    question = create(:trivia_question, trivia_pack: pack)
    question.image.attach(
      io: File.open(Rails.root.join("spec/fixtures/files/test_image.png")),
      filename: "test_image.png",
      content_type: "image/png"
    )

    visit edit_trivia_pack_path(pack)

    # Find and check the remove image checkbox
    remove_checkbox = find("input[name*='[remove_image]']", visible: :all)
    page.execute_script("arguments[0].click();", remove_checkbox)

    # Existing image container should dim
    container = find("[data-trivia-editor-target='existingImageContainer']")
    expect(container[:style]).to include("opacity")

    click_button "Save Pack"
    expect(page).to have_content("Trivia pack updated successfully")

    question.reload
    expect(question.image).not_to be_attached
  end
end
```

**Step 3: Run the system tests**

```bash
bin/rspec spec/system/trivia_packs_crud_spec.rb --format documentation
```

Expected: all pass, including the two new tests.

**Step 4: Run the full test suite**

```bash
bin/rspec
```

Expected: all pass. If any model tests fail due to Active Storage not being available in test env, confirm `config/storage.yml` has a `test:` service (it does — Disk at `tmp/storage`).

**Step 5: Run rubocop**

```bash
rubocop -A
```

Fix any auto-correctable offenses. Commit if anything changed.

**Step 6: Commit**

```bash
git add spec/fixtures/files/test_image.png spec/system/trivia_packs_crud_spec.rb
git commit -m "Add system tests for trivia question image upload and removal"
```

---

## Final Checklist

- [ ] `bin/rspec` — all tests pass
- [ ] `rubocop` — no offenses
- [ ] `brakeman -q` — no new warnings
- [ ] Manual smoke test: create a pack with an image question, start a game, verify the image preloads during instructions and displays instantly when the question appears
- [ ] Manual smoke test: create a pack without images, verify the stage layout looks normal (question text is full size with no empty gap)
