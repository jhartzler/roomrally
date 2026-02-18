# Trivia Question Images — Design Doc

**Date:** 2026-02-17
**Status:** Approved

## Overview

Allow users to attach optional images to individual trivia questions, displayed Kahoot-style on the stage screen (image above question text and answer options). Images are stored on Cloudflare R2 via Active Storage. The stage preloads all images before gameplay begins so there is zero visible lag when questions appear.

---

## Data Model

### TriviaQuestion
- Add `has_one_attached :image`
- Validations:
  - Content type: JPEG, PNG, WebP, GIF
  - Max file size: **5MB per image**

### TriviaQuestionInstance (gameplay snapshot)
- Add `has_one_attached :image`
- `assign_questions` copies the blob reference when snapshotting a question that has an image: `instance.image.attach(question.image.blob)`
- If the question has no image, the instance has no image — no special handling needed
- This keeps the snapshot fully self-contained (consistent with how `body`, `options`, and `correct_answers` are already copied)

### TriviaPack (abuse prevention)
- Custom validation: at most **20 questions with images per pack**
- Enforced at save time, surfaced as a form error

---

## Upload UX (Trivia Pack Editor)

Each question card in `_form.html.erb` gets an image section below the body textarea:

- A file input using Active Storage `direct_upload: true` — the browser uploads directly to R2, bypassing the Rails server
- After file selection, show an inline image thumbnail preview (Stimulus, no page reload)
- A "Remove image" button that marks the image for deletion (`remove_image: true` param)
- For existing questions with images, show the current image thumbnail on load

The `trivia_questions_attributes` permitted params in the controller gain `:image` and `:remove_image`.

The Stimulus `trivia-editor` controller gains a `previewImage` action that reads the selected file via `FileReader` and updates a preview `<img>` tag inline — no server round-trip needed for the preview.

The `<template>` block for new questions also includes the image upload UI so newly added questions behave identically.

---

## Stage Layout — Answering Phase

### With image

```
┌─────────────────────────────────────────────────┐
│  Question 2 of 8                                │  ← question counter
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │                                         │    │
│  │              [IMAGE]                    │    │  ← ~35vh, object-cover, rounded
│  │                                         │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  "What is the largest planet in the solar...?"  │  ← text-vh-3xl (slightly smaller)
│                                                 │
│  [A] Mercury    [B] Jupiter                    │  ← 2×2 options grid
│  [C] Saturn     [D] Neptune                    │
│                                                 │
│            Answer on your device!              │
└─────────────────────────────────────────────────┘
```

### Without image (graceful fallback — no visual gap)

```
┌─────────────────────────────────────────────────┐
│  Question 2 of 8                                │
│                                                 │
│  "What is the largest planet in the solar...?"  │  ← text-vh-4xl (full size, more space)
│                                                 │
│  [A] Mercury    [B] Jupiter                    │
│  [C] Saturn     [D] Neptune                    │
│                                                 │
│            Answer on your device!              │
└─────────────────────────────────────────────────┘
```

Implementation: a single conditional `<% if current_question.image.attached? %>` block in `_stage_answering.html.erb`. The overall container uses `flex flex-col` so removing the image section naturally expands the text area with no gap.

### Reviewing phase

`_stage_reviewing.html.erb` follows the same pattern — image rendered above the question body and answer reveal if present.

---

## Image Preloading (Zero-Lag Strategy)

The `_stage_instructions.html.erb` and `_stage_waiting.html.erb` partials inject hidden `<link rel="preload" as="image">` tags for every question image in the current game:

```erb
<% game.trivia_question_instances.each do |q| %>
  <% if q.image.attached? %>
    <link rel="preload" as="image" href="<%= url_for(q.image) %>">
  <% end %>
<% end %>
```

The stage browser fetches all images in the background while players read the instructions screen. By the time question 1 appears via Turbo Stream, all images are in the browser cache. No JavaScript required — this is native browser behavior.

---

## Image Variants

Define a display variant to normalize dimensions for the stage:

```ruby
# In _stage_answering.html.erb
q.image.variant(resize_to_limit: [1920, 900])
```

This prevents oversized images from breaking the vh-based layout and converts to a consistent format for faster delivery. The `image_processing` gem (already in `Gemfile`) handles this via libvips.

---

## Storage Caps Summary

| Constraint | Limit | Enforced by |
|---|---|---|
| Max file size | 5 MB per image | `TriviaQuestion` model validation |
| Max images per pack | 20 questions with images | `TriviaPack` model validation |
| Accepted formats | JPEG, PNG, WebP, GIF | `TriviaQuestion` model validation |

---

## Files Affected

| File | Change |
|---|---|
| `app/models/trivia_question.rb` | `has_one_attached :image`, size/type validations |
| `app/models/trivia_question_instance.rb` | `has_one_attached :image` |
| `app/models/trivia_pack.rb` | Custom validation: max 20 images per pack |
| `app/services/games/speed_trivia.rb` | `assign_questions`: copy blob to instance |
| `app/controllers/trivia_packs_controller.rb` | Permit `:image`, `:remove_image` in nested params |
| `app/views/trivia_packs/_form.html.erb` | Add image file input + preview per question card |
| `app/views/trivia_packs/_form.html.erb` (template) | Same image UI in the `<template>` block for new questions |
| `app/javascript/controllers/trivia_editor_controller.js` | `previewImage` action for inline thumbnail |
| `app/views/games/speed_trivia/_stage_answering.html.erb` | Conditional image block above question text |
| `app/views/games/speed_trivia/_stage_reviewing.html.erb` | Same conditional image block |
| `app/views/games/speed_trivia/_stage_instructions.html.erb` | Inject `<link rel="preload">` tags |
| `app/views/games/speed_trivia/_stage_waiting.html.erb` | Inject `<link rel="preload">` tags |
| `spec/models/trivia_question_spec.rb` | Tests for image validations |
| `spec/models/trivia_pack_spec.rb` | Test for 20-image-per-pack limit |
| `spec/system/trivia_packs_crud_spec.rb` | Test uploading an image, verifying preview |

---

## Out of Scope

- Image editing/cropping in-browser
- Player-side image display (players see answer options only on their phones)
- URL-based image linking
- Per-account storage quotas (not needed at current scale)
