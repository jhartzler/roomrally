# Speed Trivia Clicker Hand View — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the Speed Trivia phone hand view with a "clicker" — big letter-only buttons (A/B/C/D) in a grid, no question text, forcing players to look at the shared screen.

**Architecture:** Single partial rewrite (`_answer_form.html.erb`). The Stimulus controller gets minor CSS class updates. No model/controller/service changes. Stage view unchanged.

**Tech Stack:** ERB, Tailwind CSS, Stimulus (existing controller)

**Design doc:** `docs/plans/2026-03-06-speed-trivia-clicker-hand-design.md`

---

### Task 1: Rewrite the answer form partial to clicker layout

**Files:**
- Modify: `app/views/games/speed_trivia/_answer_form.html.erb`

**Step 1: Replace the answer form partial**

Rewrite `app/views/games/speed_trivia/_answer_form.html.erb` with the clicker layout. Key changes from the current file:

- Remove the question text card (lines 26-30 in current file)
- Replace vertical `space-y-3` button stack with a `grid` layout
- Each button shows only the letter (A, B, C, D) — no `<span>` with option text
- Grid fills available viewport height so buttons are large tap targets
- Dynamic grid: 2x2 for 4 options, side-by-side for 2, centered last row for 3

```erb
<%# app/views/games/speed_trivia/_answer_form.html.erb %>
<% current_question = game.current_question %>
<% existing_answer = current_question&.trivia_answers&.find_by(player:) %>
<% options = current_question&.options || [] %>
<% selected_letter = existing_answer ? (options.index(existing_answer.selected_option).to_i + 65).chr : nil %>

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
    <%# Already answered — show grid with selected button highlighted %>
    <div class="grid <%= options.size <= 2 ? 'grid-cols-2' : 'grid-cols-2' %> gap-3 flex-1 mb-4">
      <% options.each_with_index do |_option, index| %>
        <% letter = (index + 65).chr %>
        <% is_selected = letter == selected_letter %>
        <div class="<%= 'col-span-2 max-w-[50%] mx-auto' if options.size == 3 && index == 2 %>">
          <div class="rounded-2xl flex items-center justify-center h-full min-h-[20vh] text-6xl font-black shadow-lg
            <%= if is_selected
                  'bg-blue-600 border-4 border-blue-300 text-white ring-4 ring-blue-400/50'
                else
                  'bg-gray-800/40 border-2 border-gray-700 text-gray-600'
                end %>">
            <%= letter %>
          </div>
        </div>
      <% end %>
    </div>
    <p class="text-center text-xl text-white font-bold">Locked in!</p>

  <% elsif current_question %>
    <%# Answer grid — big tappable letter buttons %>
    <div class="grid grid-cols-2 gap-3 flex-1" data-controller="games--speed-trivia">
      <% options.each_with_index do |option, index| %>
        <% letter = (index + 65).chr %>
        <div class="<%= 'col-span-2 max-w-[50%] mx-auto w-full' if options.size == 3 && index == 2 %>">
          <%= button_to trivia_answers_path,
              method: :post,
              params: { trivia_answer: { selected_option: option }, code: room.code },
              class: "w-full h-full min-h-[20vh] rounded-2xl flex items-center justify-center text-6xl font-black text-white shadow-lg transition-all active:scale-95 bg-gray-800/80 hover:bg-gray-700/80 backdrop-blur-md border-2 border-gray-600 hover:border-blue-400",
              data: {
                turbo_frame: "hand_screen",
                test_id: "answer-option-#{index}",
                action: "click->games--speed-trivia#disableOptions",
                games__speed_trivia_target: "option"
              } do %>
            <%= letter %>
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

**Step 2: Update the Stimulus controller CSS classes**

Modify `app/javascript/controllers/games/speed_trivia_controller.js`. The `disableOptions` method removes hover classes that no longer exist in the new markup. Update to match:

```javascript
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="games--speed-trivia"
export default class extends Controller {
    static targets = ["option"]

    disableOptions(event) {
        const button = event.currentTarget
        if (button.disabled) {
            event.preventDefault()
            return
        }

        setTimeout(() => {
            this.optionTargets.forEach(btn => {
                btn.disabled = true
                btn.classList.add("opacity-50", "cursor-not-allowed")
                btn.classList.remove("hover:bg-gray-700/80", "hover:border-blue-400", "active:scale-95")
            })
        }, 0)
    }
}
```

Note: The Stimulus controller doesn't actually need changes — the hover classes it removes (`hover:bg-gray-700/80`, `hover:border-blue-400`, `active:scale-95`) still exist on the new buttons. Leave it as-is.

**Step 3: Run the existing system spec to verify nothing broke**

Run: `bin/rspec spec/system/games/speed_trivia_happy_path_spec.rb`

The spec clicks `[data-test-id="answer-option-0"]` and checks for "Locked in!" — both are preserved in the new markup. Expected: PASS.

**Step 4: Commit**

```bash
git add app/views/games/speed_trivia/_answer_form.html.erb
git commit -m "feat: redesign speed trivia hand as clicker with letter-only buttons

Players now see big A/B/C/D buttons instead of full answer text,
encouraging them to look at the shared screen for question details."
```

### Task 2: Visual regression check

**Step 1: Capture baseline screenshots (before is already on main)**

```bash
rake screenshots:capture
rake screenshots:approve
```

**Step 2: Capture new screenshots and review**

```bash
rake screenshots:capture
rake screenshots:report
```

**Step 3: Review the report**

Verify:
- Answer form shows 2x2 grid of big letter buttons, no question text
- Already-answered state shows highlighted selected button + "Locked in!"
- Stage view is unchanged
- Waiting/reviewing/game_over screens are unchanged

**Step 4: Clean up**

```bash
rake screenshots:clean
```
