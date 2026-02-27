# Prompt Stepper Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the "Prompt 1 of 2" progress pill in Comedy Clash with a 2-up horizontal stepper that shows both prompt texts simultaneously, so players can see at a glance they have two prompts without scrolling.

**Architecture:** Pure view change — no new models, controllers, or Stimulus controllers. The stepper is rendered server-side in `_prompt_screen.html.erb`. Each stepper card carries `data-test-id="player-prompt"` (replacing the old pending card). The existing Turbo Stream targets (`id="prompt-instance-{id}"`) stay in the DOM inside the loop below the stepper.

**Tech Stack:** Ruby on Rails ERB partials, Tailwind CSS (`line-clamp-2`, `flex`, `gap`, `border`, opacity utilities)

---

### Task 1: Update the prompt display spec with stepper assertions

**Files:**
- Modify: `spec/system/games/write_and_vote_prompt_display_spec.rb`

**Step 1: Add stepper content assertions to the existing spec**

Open `spec/system/games/write_and_vote_prompt_display_spec.rb` and expand the test to assert stepper labels and prompt text visibility:

```ruby
require 'rails_helper'

RSpec.describe "WriteAndVote Prompt Display", type: :system do
  let(:room) { Room.create!(game_type: "Write And Vote") }
  let!(:alice) { Player.create!(name: "Alice", room:) }

  before do
    default_pack = FactoryBot.create(:prompt_pack, :default)
    3.times { |i| Prompt.create!(body: "Prompt #{i + 1}", prompt_pack: default_pack) }

    Games::WriteAndVote.game_started(room:, show_instructions: false)
    room.update!(status: "playing")
  end

  it "shows exactly two prompts to each player" do
    visit "/dev/testing/set_player_session/#{alice.id}"
    visit "/rooms/#{room.code}/hand"

    expect(page).to have_css('[data-test-id="player-prompt"]', count: 2)
  end

  it "shows both prompt texts in the stepper without requiring scroll" do
    visit "/dev/testing/set_player_session/#{alice.id}"
    visit "/rooms/#{room.code}/hand"

    # Both prompt texts should be visible on the page
    expect(page).to have_content("Prompt 1")
    expect(page).to have_content("Prompt 2")

    # Stepper state labels should be visible
    expect(page).to have_content("Active", count: 1)
    expect(page).to have_content("Up Next", count: 1)

    # Old progress pill should be gone
    expect(page).not_to have_content("of 2")
  end
end
```

**Step 2: Run the new test to verify it fails**

```bash
bin/rspec spec/system/games/write_and_vote_prompt_display_spec.rb -f doc
```

Expected: The first test PASSES (existing), the new test FAILS because "Active" / "Up Next" labels don't exist yet and "of 2" still appears.

---

### Task 2: Replace progress pill with 2-up stepper in `_prompt_screen.html.erb`

**Files:**
- Modify: `app/views/games/write_and_vote/_prompt_screen.html.erb`

**Step 1: Write the new partial**

Replace the entire file with the following:

```erb
<%# app/views/games/write_and_vote/_prompt_screen.html.erb %>
<%# Main writing phase hand view for Write and Vote %>

<header class="max-w-md mx-auto mb-6 px-2">
  <span class="text-blue-100/80 text-xs font-bold tracking-widest uppercase">Write your best answer...</span>
</header>

<div class="max-w-md mx-auto space-y-4">
  <%# Calculate active index: First prompt with blank/pending response or rejected status %>
  <% active_index = active_prompt_index(player, prompts) %>

  <%# 2-up Prompt Stepper — shows both prompts at a glance %>
  <div class="flex gap-3">
    <% prompts.each_with_index do |prompt_item, idx| %>
      <% prompt_response = player.responses.find_by(prompt_instance: prompt_item) %>
      <% is_active = idx == active_index %>
      <% is_done = prompt_response&.submitted? %>
      <div class="flex-1 rounded-2xl p-3 border <%= is_active ? 'bg-white/15 border-blue-400/50' : 'bg-white/5 border-white/10' %>"
           data-test-id="player-prompt">
        <div class="flex items-center justify-between mb-1.5">
          <span class="text-[9px] font-black tracking-widest uppercase <%= is_active ? 'text-blue-300' : (is_done ? 'text-green-400' : 'text-blue-200/40') %>">
            <% if is_done %>Done<% elsif is_active %>Active<% else %>Up Next<% end %>
          </span>
          <% if is_done %>
            <svg class="w-3.5 h-3.5 text-green-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/>
            </svg>
          <% else %>
            <span class="text-[9px] font-black <%= is_active ? 'text-blue-300' : 'text-blue-200/40' %>"><%= idx + 1 %></span>
          <% end %>
        </div>
        <p class="text-white text-xs font-semibold line-clamp-2 leading-snug <%= is_done || !is_active ? 'opacity-50' : '' %>">
          <%= prompt_item.body %>
        </p>
      </div>
    <% end %>
  </div>

  <% if game.timer_enabled? %>
    <div data-controller="dramatic-timer"
         data-dramatic-timer-end-value="<%= game.timer_expires_at_iso8601 %>"
         data-dramatic-timer-target="container"
         class="bg-blue-950/40 backdrop-blur-md rounded-xl p-3 flex items-center justify-between border border-blue-400/30 shadow-lg transition-all">
      <span class="text-blue-400 text-xs font-black tracking-widest uppercase ml-2"
            data-dramatic-timer-target="visual">Time Left</span>
      <div class="rounded-lg px-3 py-1">
        <span class="text-2xl font-black text-white font-mono leading-none drop-shadow-md"
              data-dramatic-timer-target="output"><%= game.time_remaining.ceil %>s</span>
      </div>
    </div>
  <% end %>

  <% prompts.each_with_index do |prompt, index| %>
    <% response = player.responses.find_by(prompt_instance: prompt) %>

    <% if index == active_index %>
      <% if response.pending? || response.rejected? %>
        <%= render "responses/form", response: response, prompt: prompt %>
      <% else %>
        <%# All prompts done (transitioning to voting) — keep ID as Turbo target %>
        <div id="prompt-instance-<%= prompt.id %>">
          <%= render "responses/submission_success", response: response %>
        </div>
      <% end %>
    <% else %>
      <% if response.submitted? %>
        <%# Keep ID as Turbo target for moderation rejection broadcast %>
        <div id="prompt-instance-<%= prompt.id %>">
          <%= render "responses/submission_success", response: response %>
        </div>
      <% else %>
        <%# Pending but not active — stepper handles the visual; keep ID as Turbo target %>
        <div id="prompt-instance-<%= prompt.id %>" class="hidden"></div>
      <% end %>
    <% end %>
  <% end %>
</div>
```

**Step 2: Run the display spec**

```bash
bin/rspec spec/system/games/write_and_vote_prompt_display_spec.rb -f doc
```

Expected: Both tests PASS.

---

### Task 3: Remove the "Active Prompt" header from `_form.html.erb`

**Files:**
- Modify: `app/views/responses/_form.html.erb`

**Step 1: Remove the header bar**

The stepper already tells players which prompt is active. Remove the redundant "Active Prompt" header inside the form card to save vertical space.

Current `app/views/responses/_form.html.erb` lines 4–8:
```erb
  <div class="bg-white/10 backdrop-blur-md rounded-3xl overflow-hidden border border-white/20 shadow-xl">
    <div class="bg-white/5 px-6 py-3 border-b border-white/10 flex justify-between items-center">
      <span class="text-blue-200 font-bold text-xs tracking-widest">Active Prompt</span>
      <span class="w-2 h-2 bg-blue-400 rounded-full animate-pulse shadow-[0_0_10px_rgba(96,165,250,0.5)]"></span>
    </div>
```

Replace lines 4–8 with just the outer card div (no header bar):
```erb
  <div class="bg-white/10 backdrop-blur-md rounded-3xl overflow-hidden border border-white/20 shadow-xl">
```

The final `_form.html.erb` should look like:

```erb
<%# app/views/responses/_form.html.erb %>
<%# partial locals: response, prompt %>
<div id="prompt-instance-<%= prompt.id %>" data-test-id="player-prompt" data-controller="character-counter" data-character-counter-max-value="280">
  <div class="bg-white/10 backdrop-blur-md rounded-3xl overflow-hidden border border-white/20 shadow-xl">
    <div class="p-6">
      <h2 class="text-xl font-bold text-white mb-6 leading-snug drop-shadow-sm"><%= prompt.body %></h2>

      <% if response.status == "rejected" %>
        <div class="bg-blue-500/20 backdrop-blur-sm rounded-2xl p-4 shadow-lg border border-blue-400/30 animate-in fade-in zoom-in duration-300 mb-6">
          <div class="flex items-center gap-3 mb-1">
            <div class="text-2xl">✨</div>
            <h3 class="font-black text-white text-sm tracking-tight">Let's try another answer</h3>
          </div>
          <p class="text-blue-50 font-bold text-sm">
            "<%= response.rejection_reason || "Please check your answer." %>"
          </p>
        </div>
      <% end %>

      <%= form_with model: response, url: response_path(response), method: :patch, local: true do |f| %>
        <%= f.text_area :body,
            data: {
              character_counter_target: "textarea",
              action: "input->character-counter#update"
            },
            class: "w-full bg-black/20 border-2 border-white/10 rounded-2xl p-4 text-white text-lg placeholder-white/30 focus:ring-4 focus:ring-blue-500/20 focus:border-blue-400 focus:bg-black/30 outline-none transition-all resize-none shadow-inner",
            rows: 3,
            placeholder: "Type your answer...",
            value: (response.status == "rejected" ? response.body : "") %>

        <div class="flex justify-between items-center mt-3 px-2">
          <span data-character-counter-target="counter" class="text-sm font-bold transition-colors">0/280</span>
          <span data-character-counter-target="message" class="text-sm font-bold"></span>
        </div>

        <%= f.submit (response.status == "rejected" ? "Submit Revision" : "Submit Response"),
            data: { character_counter_target: "submit" },
            class: "w-full mt-3 bg-orange-500 hover:bg-orange-600 active:scale-[0.95] text-white font-black py-4 rounded-2xl shadow-lg shadow-orange-900/20 transition-all text-lg tracking-tight cursor-pointer" %>
      <% end %>
    </div>
  </div>
</div>
```

**Note:** `data-test-id="player-prompt"` stays on `_form.html.erb` because this partial is also used for moderation rejection broadcasts — when rejection fires, the full form replaces the `id` element in the DOM and the test-id is needed to keep the count correct.

**Step 2: Run all write_and_vote specs**

```bash
bin/rspec spec/system/games/write_and_vote_prompt_display_spec.rb spec/system/games/write_and_vote_happy_path_spec.rb -f doc
```

Expected: All tests PASS.

---

### Task 4: Run the full test suite and commit

**Step 1: Run all tests**

```bash
bin/rspec spec/system/games/
```

Expected: All system tests pass.

**Step 2: Run Rubocop**

```bash
rubocop -A
```

Expected: No offenses (or auto-fixed).

**Step 3: Commit**

```bash
git add app/views/games/write_and_vote/_prompt_screen.html.erb \
        app/views/responses/_form.html.erb \
        spec/system/games/write_and_vote_prompt_display_spec.rb
git commit -m "feat: replace progress pill with 2-up prompt stepper in Comedy Clash"
```
