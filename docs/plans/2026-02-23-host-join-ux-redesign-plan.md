# Host/Join UX Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Separate the host (create room) and player (join room) entry points into distinct routes (`/host` and `/play`), add a shared top nav bar with clear wayfinding, and gate `/host` with a mobile speed-bump modal for logged-out users.

**Architecture:** New `HostsController` renders the create-room form at `/host`; `HomeController` is stripped to join-only at `/play`; a shared `_topnav` partial is injected via `content_for(:topnav)` in the layout so it only appears on public-facing pages; a Stimulus `mobile-warning` controller drives a native `<dialog>` modal.

**Tech Stack:** Ruby on Rails 8, Hotwire/Stimulus, Tailwind CSS, RSpec/Capybara system specs.

**Design doc:** `docs/plans/2026-02-23-host-join-ux-redesign-design.md`

---

### Task 1: Add `/host` route and `HostsController`

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/hosts_controller.rb`
- Modify: `spec/system/create_room_flow_spec.rb` (existing spec will break — update it first)

**Step 1: Update the existing spec to reflect the new split**

The current `spec/system/create_room_flow_spec.rb` visits `/play` and expects a "Create Room" button. After this change the form moves to `/host`. Rewrite the spec so it covers both pages separately:

```ruby
# spec/system/create_room_flow_spec.rb
require 'rails_helper'

RSpec.describe 'Room Creation Flow', type: :system do
  describe '/play' do
    it 'shows only the join form, not the create form' do
      visit play_path
      expect(page).to have_button('Join Room')
      expect(page).not_to have_button('Create Room')
    end
  end

  describe '/host' do
    it 'shows the create room form' do
      visit host_path
      expect(page).to have_button('Create Room')
    end

    it 'creates a room and redirects to stage' do
      visit host_path
      click_on 'Create Room'
      expect(page).to have_current_path(/\/rooms\/[A-Z0-9]{4}\/stage/, wait: 5)
      room_code = page.current_path.split('/')[2]
      room = Room.find_by!(code: room_code)
      expect(page).to have_content(room.code)
      expect(page).to have_selector('#stage_content')
    end
  end
end
```

**Step 2: Run the spec to verify it fails**

```bash
bin/rspec spec/system/create_room_flow_spec.rb
```

Expected: FAIL — `host_path` undefined.

**Step 3: Add the route**

In `config/routes.rb`, add after `get "play", to: "home#index"`:

```ruby
get "host", to: "hosts#index", as: :host
```

**Step 4: Create the controller**

```ruby
# app/controllers/hosts_controller.rb
class HostsController < ApplicationController
end
```

**Step 5: Create a stub view to unblock routing**

```erb
<%# app/views/hosts/index.html.erb %>
<p>Host page coming soon</p>
```

**Step 6: Run the spec again**

```bash
bin/rspec spec/system/create_room_flow_spec.rb
```

Expected: The `/play` describe block passes (join button present, create button absent — will pass once Task 3 strips the form). The `/host` describe blocks fail with "Create Room button not found" — expected for now.

**Step 7: Commit**

```bash
git add config/routes.rb app/controllers/hosts_controller.rb app/views/hosts/index.html.erb spec/system/create_room_flow_spec.rb
git commit -m "feat: add /host route and HostsController stub"
```

---

### Task 2: Build the `/host` view (create-room form)

**Files:**
- Modify: `app/views/hosts/index.html.erb`

The create-room form currently lives in `app/views/home/index.html.erb`. Copy it to the host view, removing the join form section. Keep the logo/header block for now (will be replaced by shared nav in Task 4).

**Step 1: Replace the stub with the full form**

```erb
<%# app/views/hosts/index.html.erb %>
<% content_for(:title) { "Host a Game – RoomRally" } %>

<div class="flex items-center justify-center min-h-[calc(100vh-4rem)]">
  <div class="max-w-md w-full">
    <div class="text-center mb-8">
      <div class="flex flex-col items-center justify-center mb-8">
        <div class="text-8xl mb-4 drop-shadow-xl">🎮</div>
        <%= link_to root_path do %>
          <h1 class="roomrally-logo mb-4 hover:opacity-80 transition-opacity">
            Room<span>Rally</span>
          </h1>
        <% end %>
      </div>
      <p class="text-blue-200 text-lg font-bold tracking-widest">Set up your game room</p>
      <div class="mt-2">
        <%= link_to play_path, class: "text-blue-300 text-xs hover:text-orange-400 transition-colors" do %>
          Looking to join? Enter a room code →
        <% end %>
      </div>

      <div class="mt-4">
        <% if current_user %>
          <div class="flex flex-col items-center space-y-2">
            <%= link_to dashboard_path, class: "bg-white text-blue-900 font-bold py-2 px-6 rounded-full shadow-lg hover:bg-blue-50 transform hover:scale-105 transition-all" do %>
              Go to Dashboard
            <% end %>
            <div class="text-blue-200/80 text-xs mt-2 flex gap-2">
              <span>Logged in as <%= current_user.name %></span>
              <span>•</span>
              <%= button_to "Logout", logout_path, method: :delete, class: "underline hover:text-white" %>
            </div>
          </div>
        <% else %>
          <%= form_with url: "/auth/google_oauth2", method: :post, data: { turbo: false } do |f| %>
            <%= f.submit "Login with Google", class: "bg-white text-blue-900 font-bold py-2 px-4 rounded-full shadow-sm hover:bg-blue-50 transition-colors text-sm" %>
          <% end %>
          <p class="text-blue-300/70 text-xs mt-2">Sign in to save game templates and create custom content.</p>
        <% end %>
      </div>
    </div>

    <div class="bg-white/10 backdrop-blur-md rounded-3xl shadow-2xl p-8 border border-white/20">
      <%= form_with url: rooms_path, method: :post, class: "space-y-4" do |form| %>
        <div>
          <span class="block text-blue-200 font-bold text-xs tracking-widest mb-3">Select Game</span>
          <div class="space-y-2">
            <% Room::GAME_TYPES.each_with_index do |game_type, index| %>
              <% info = game_info(game_type) %>
              <label class="block cursor-pointer">
                <%= form.radio_button :game_type, game_type,
                    checked: index == 0,
                    class: "hidden peer" %>
                <div class="px-4 py-3 bg-white/10 border-2 border-white/10 rounded-xl transition-all peer-checked:border-orange-500 peer-checked:bg-orange-500/10 hover:bg-white/15">
                  <div class="flex items-center gap-3">
                    <span class="text-2xl"><%= info[:emoji] %></span>
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center gap-2">
                        <span class="text-white font-bold"><%= Room::GAME_DISPLAY_NAMES[game_type] || game_type %></span>
                      </div>
                      <p class="text-blue-200/70 text-xs mt-0.5"><%= info[:tagline] %></p>
                    </div>
                  </div>
                  <div class="flex gap-2 mt-2 ml-9">
                    <span class="text-[10px] text-blue-300/60 bg-white/5 px-2 py-0.5 rounded-full"><%= info[:player_count] %></span>
                    <span class="text-[10px] text-blue-300/60 bg-white/5 px-2 py-0.5 rounded-full"><%= info[:duration] %></span>
                  </div>
                </div>
              </label>
            <% end %>
          </div>
        </div>
        <% if current_user %>
          <details class="mt-2">
            <summary class="text-blue-200 text-sm cursor-pointer hover:text-white transition-colors">
              ▸ Game Options
            </summary>
            <div class="mt-3">
              <%= form.label :display_name, "Game Name (optional)", class: "block text-blue-200 font-bold text-xs tracking-widest mb-2" %>
              <%= form.text_field :display_name, placeholder: "e.g. Mike's Birthday Bash", class: "w-full px-4 py-3 bg-white/20 border-2 border-white/10 rounded-xl text-white placeholder-white/30 focus:outline-none focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20 transition-all" %>
              <p class="text-blue-300/60 text-xs mt-1">Leave blank for default</p>
            </div>
            <div class="mt-3">
              <label class="flex items-center gap-2 cursor-pointer">
                <%= form.check_box :stage_only, { class: "form-checkbox h-5 w-5 text-orange-500 rounded border-white/30 bg-white/10 focus:ring-orange-500 focus:ring-offset-0 transition-colors" }, "1", "0" %>
                <span class="text-blue-200 font-medium text-sm">Stage-Only Mode</span>
              </label>
              <p class="text-blue-300/60 text-xs mt-1">No phones needed — run from backstage only</p>
            </div>
          </details>
        <% end %>
        <%= form.submit "Create Room", class: "w-full bg-orange-500 text-white font-black py-4 px-6 rounded-xl hover:bg-orange-600 active:scale-[0.98] transform hover:shadow-lg shadow-orange-900/20 transition-all duration-200 text-lg tracking-tight" %>
      <% end %>
    </div>
  </div>
</div>
```

**Step 2: Run the spec**

```bash
bin/rspec spec/system/create_room_flow_spec.rb
```

Expected: `/host` describe blocks now pass. `/play` blocks may still fail if the join-only work isn't done — that's fine, Task 3 covers it.

**Step 3: Commit**

```bash
git add app/views/hosts/index.html.erb
git commit -m "feat: build /host view with create-room form"
```

---

### Task 3: Strip `/play` to join-only

**Files:**
- Modify: `app/views/home/index.html.erb`

**Step 1: Rewrite home/index.html.erb as join-only**

```erb
<%# app/views/home/index.html.erb %>
<% content_for(:title) { "Join a Game – RoomRally" } %>

<div class="flex items-center justify-center min-h-[calc(100vh-4rem)]">
  <div class="max-w-md w-full">
    <div class="text-center mb-8">
      <div class="flex flex-col items-center justify-center mb-8">
        <div class="text-8xl mb-4 drop-shadow-xl animate-bounce">📢</div>
        <%= link_to root_path do %>
          <h1 class="roomrally-logo mb-4 hover:opacity-80 transition-opacity">
            Room<span>Rally</span>
          </h1>
        <% end %>
      </div>
      <p class="text-blue-200 text-lg font-bold tracking-widest">Enter your room code to join</p>
      <div class="mt-2">
        <%= link_to host_path, class: "text-blue-300 text-xs hover:text-orange-400 transition-colors" do %>
          Want to host? Set up a game room →
        <% end %>
      </div>
    </div>

    <div class="bg-white/10 backdrop-blur-md rounded-3xl shadow-2xl p-8 border border-white/20">
      <%= form_with url: "javascript:void(0);", method: :get, data: { turbo: false, controller: "redirect-form", action: "submit->redirect-form#join", "redirect-form-url-template-value": "/rooms/{{value}}/join" }, class: "space-y-4" do |form| %>
        <div>
          <%= form.label :room_code, "Room Code", class: "block text-blue-200 font-bold text-xs tracking-widest mb-2" %>
          <%= form.text_field :room_code,
              data: { "redirect-form-target": "input" },
              autofocus: true,
              class: "w-full px-4 py-3 bg-white/20 border-2 border-white/10 rounded-xl text-white placeholder-white/30 focus:outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20 transition-all text-center text-2xl font-mono font-black uppercase",
              placeholder: "ABCD" %>
        </div>
        <%= form.submit "Join Room", class: "w-full bg-blue-600 text-white font-black py-4 px-6 rounded-xl hover:bg-blue-700 active:scale-[0.98] transform hover:shadow-lg transition-all duration-200 tracking-tight" %>
      <% end %>
    </div>
  </div>
</div>
```

**Step 2: Run the full spec file**

```bash
bin/rspec spec/system/create_room_flow_spec.rb
```

Expected: all examples pass.

**Step 3: Run the player join spec to make sure nothing broke**

```bash
bin/rspec spec/system/player_join_flow_spec.rb
```

Expected: all pass.

**Step 4: Commit**

```bash
git add app/views/home/index.html.erb
git commit -m "feat: strip /play to join-only, move create-room to /host"
```

---

### Task 4: Shared top nav bar

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Create: `app/views/shared/_topnav.html.erb`
- Modify: `app/views/pages/landing.html.erb`
- Modify: `app/views/home/index.html.erb`
- Modify: `app/views/hosts/index.html.erb`

**Step 1: Write a failing system spec for the nav**

Create `spec/system/navigation_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Top navigation', type: :system do
  it 'landing page has nav links to host and join' do
    visit root_path
    within('nav[data-testid="topnav"]') do
      expect(page).to have_link('Host a Game', href: host_path)
      expect(page).to have_link('Join a Game', href: play_path)
    end
  end

  it '/play has nav links to host and join' do
    visit play_path
    within('nav[data-testid="topnav"]') do
      expect(page).to have_link('Host a Game', href: host_path)
      expect(page).to have_link('Join a Game', href: play_path)
    end
  end

  it '/host has nav links to host and join' do
    visit host_path
    within('nav[data-testid="topnav"]') do
      expect(page).to have_link('Host a Game', href: host_path)
      expect(page).to have_link('Join a Game', href: play_path)
    end
  end

  context 'when logged out' do
    it 'landing page nav shows login link' do
      visit root_path
      within('nav[data-testid="topnav"]') do
        expect(page).to have_button('Login with Google')
      end
    end
  end

  context 'when logged in', :as_user do
    it 'landing page nav shows dashboard link' do
      visit root_path
      within('nav[data-testid="topnav"]') do
        expect(page).to have_link('Dashboard', href: dashboard_path)
      end
    end
  end
end
```

**Step 2: Run spec to confirm failure**

```bash
bin/rspec spec/system/navigation_spec.rb
```

Expected: FAIL — `nav[data-testid="topnav"]` not found.

> **Note:** If `as_user` shared context doesn't exist in your support files, check `spec/support/` for the authentication helper pattern used in other specs and adapt accordingly.

**Step 3: Add topnav yield to the application layout**

In `app/views/layouts/application.html.erb`, insert `<%= yield :topnav %>` immediately before the opening `<main>` tag:

```erb
  </head>

  <body class="min-h-screen flex flex-col bg-gradient-to-b from-blue-600 to-indigo-900 font-sans selection:bg-orange-500 selection:text-white">
    <% if flash.any? %>
      ...flash block (unchanged)...
    <% end %>
    <%= yield :topnav %>
    <main class="container mx-auto px-4 py-8 flex-grow">
      <%= yield %>
    </main>
```

**Step 4: Create the shared nav partial**

```erb
<%# app/views/shared/_topnav.html.erb %>
<nav data-testid="topnav" class="sticky top-0 z-50 bg-blue-900/80 backdrop-blur-md border-b border-white/10">
  <div class="container mx-auto px-4 py-3 flex items-center justify-between gap-4">
    <%# Logo %>
    <%= link_to root_path, class: "group hover:opacity-80 transition-opacity shrink-0" do %>
      <span class="roomrally-logo text-xl">Room<span>Rally</span></span>
    <% end %>

    <%# Actions %>
    <div class="flex items-center gap-2 sm:gap-3 flex-wrap justify-end">
      <%= link_to "Join a Game", play_path,
          class: "text-white font-bold py-2 px-4 rounded-full border border-white/30 hover:bg-white/10 transition-all text-sm" %>
      <%= link_to "Host a Game", host_path,
          class: "bg-orange-500 text-white font-bold py-2 px-4 rounded-full hover:bg-orange-600 transition-all text-sm shadow-lg shadow-orange-900/30" %>

      <% if current_user %>
        <%= link_to "Dashboard", dashboard_path,
            class: "text-blue-200 hover:text-white transition-colors text-sm font-medium" %>
      <% else %>
        <%= form_with url: "/auth/google_oauth2", method: :post, data: { turbo: false } do |f| %>
          <%= f.submit "Login with Google",
              class: "text-blue-200 hover:text-white transition-colors text-sm font-medium bg-transparent border-0 cursor-pointer p-0" %>
        <% end %>
      <% end %>
    </div>
  </div>
</nav>
```

**Step 5: Include the nav in the landing page**

At the very top of `app/views/pages/landing.html.erb`, before the existing `<div class="max-w-6xl...">`, add:

```erb
<% content_for :topnav do %>
  <%= render 'shared/topnav' %>
<% end %>
```

Also replace the existing hero CTA (single "Host or Play for Free" button) with two side-by-side buttons:

Find this block in `landing.html.erb`:
```erb
      <%= link_to play_path, class: "inline-block bg-orange-500 text-white font-black py-4 px-12 rounded-full hover:bg-orange-600 active:scale-95 transform hover:shadow-2xl shadow-orange-900/40 transition-all duration-200 text-xl" do %>
        Host or Play for Free
      <% end %>
```

Replace with:
```erb
      <div class="flex flex-col sm:flex-row gap-4 justify-center">
        <%= link_to host_path, class: "inline-block bg-orange-500 text-white font-black py-4 px-10 rounded-full hover:bg-orange-600 active:scale-95 transform hover:shadow-2xl shadow-orange-900/40 transition-all duration-200 text-xl" do %>
          Host a Game
        <% end %>
        <%= link_to play_path, class: "inline-block bg-white/20 backdrop-blur text-white font-black py-4 px-10 rounded-full hover:bg-white/30 active:scale-95 transform transition-all duration-200 text-xl border border-white/30" do %>
          Join a Game
        <% end %>
      </div>
```

Also remove the existing centered `<header>` block from the landing page (the logo is now in the nav):

Find and remove:
```erb
  <%# Header with Logo %>
  <header class="pt-6 px-4 mb-4 md:mb-0 flex justify-center">
    <%= link_to root_path, class: "group hover:opacity-80 transition-opacity" do %>
      <h1 class="roomrally-logo text-3xl md:text-4xl">
        Room<span>Rally</span>
      </h1>
    <% end %>
  </header>
```

**Step 6: Include the nav in /play and /host**

Add at the top of `app/views/home/index.html.erb`:
```erb
<% content_for :topnav do %>
  <%= render 'shared/topnav' %>
<% end %>
```

Add at the top of `app/views/hosts/index.html.erb`:
```erb
<% content_for :topnav do %>
  <%= render 'shared/topnav' %>
<% end %>
```

While you're there, remove the inline logo/header blocks from both views (the `roomrally-logo` h1 and surrounding div) since the nav now provides the logo. Keep the emoji and subtitle line — just remove the redundant logo link.

**Step 7: Run the navigation spec**

```bash
bin/rspec spec/system/navigation_spec.rb
```

Expected: all pass (or skip the `as_user` context if the shared context doesn't exist yet — note it for follow-up).

**Step 8: Run the full system suite to check for regressions**

```bash
bin/rspec spec/system/create_room_flow_spec.rb spec/system/player_join_flow_spec.rb
```

Expected: all pass.

**Step 9: Commit**

```bash
git add app/views/layouts/application.html.erb app/views/shared/_topnav.html.erb app/views/pages/landing.html.erb app/views/home/index.html.erb app/views/hosts/index.html.erb spec/system/navigation_spec.rb
git commit -m "feat: add shared topnav with Host/Join links to landing, /play, and /host"
```

---

### Task 5: Mobile warning Stimulus controller and modal

**Files:**
- Create: `app/javascript/controllers/mobile_warning_controller.js`
- Modify: `app/views/hosts/index.html.erb`

**Step 1: Write a failing system spec**

Create `spec/system/mobile_warning_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Mobile warning modal on /host', type: :system, js: true do
  let(:mobile_size) { [390, 844] }   # iPhone 14 viewport
  let(:desktop_size) { [1280, 800] }

  describe 'logged-out user on mobile' do
    before { page.driver.browser.manage.window.resize_to(*mobile_size) }
    after  { page.driver.browser.manage.window.resize_to(*desktop_size) }

    it 'shows the warning modal immediately' do
      visit host_path
      expect(page).to have_css('dialog[open]')
      expect(page).to have_text('are you joining or hosting')
    end

    it '"Go to Join Screen" navigates to /play' do
      visit host_path
      click_button 'Go to Join Screen'
      expect(page).to have_current_path(play_path)
    end

    it '"Continue Anyway" dismisses the modal and shows the form' do
      visit host_path
      click_button 'Continue Anyway'
      expect(page).not_to have_css('dialog[open]')
      expect(page).to have_button('Create Room')
    end
  end

  describe 'logged-out user on desktop' do
    before { page.driver.browser.manage.window.resize_to(*desktop_size) }

    it 'does not show the modal' do
      visit host_path
      expect(page).not_to have_css('dialog[open]')
    end
  end

  describe 'logged-in user on mobile', :as_user do
    before { page.driver.browser.manage.window.resize_to(*mobile_size) }
    after  { page.driver.browser.manage.window.resize_to(*desktop_size) }

    it 'does not show the modal' do
      visit host_path
      expect(page).not_to have_css('dialog[open]')
    end
  end
end
```

**Step 2: Run the spec to confirm failure**

```bash
bin/rspec spec/system/mobile_warning_spec.rb
```

Expected: FAIL — dialog not found.

**Step 3: Create the Stimulus controller**

```javascript
// app/javascript/controllers/mobile_warning_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { loggedIn: Boolean }

  connect() {
    // Prevent Escape key from closing the dialog
    this.dialogTarget.addEventListener("cancel", (e) => e.preventDefault())

    if (!this.loggedInValue && window.innerWidth <= 768) {
      this.dialogTarget.showModal()
    }
  }

  goToJoin() {
    window.location.href = this.element.dataset.mobileWarningJoinUrlValue
  }

  dismiss() {
    this.dialogTarget.close()
  }
}
```

Wait — the join URL is a constant (`/play`). Hardcode it instead of using a data value to keep the controller simple:

```javascript
// app/javascript/controllers/mobile_warning_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { loggedIn: Boolean }

  connect() {
    this.dialogTarget.addEventListener("cancel", (e) => e.preventDefault())
    if (!this.loggedInValue && window.innerWidth <= 768) {
      this.dialogTarget.showModal()
    }
  }

  goToJoin() {
    window.location.href = "/play"
  }

  dismiss() {
    this.dialogTarget.close()
  }
}
```

**Step 4: Add the controller and modal HTML to the /host view**

Wrap the top-level div in `app/views/hosts/index.html.erb` with the Stimulus controller and add the `<dialog>` element. Change the outer wrapper to:

```erb
<div data-controller="mobile-warning"
     data-mobile-warning-logged-in-value="<%= current_user.present? %>">

  <dialog data-mobile-warning-target="dialog"
          class="rounded-2xl p-0 shadow-2xl border border-white/20 backdrop:bg-black/60 max-w-sm w-full mx-auto bg-transparent">
    <div class="bg-gradient-to-b from-blue-700 to-indigo-800 rounded-2xl p-8 text-white">
      <h2 class="text-xl font-black mb-6 text-center">Wait — are you joining or hosting?</h2>

      <div class="space-y-4">
        <div class="bg-white/10 rounded-xl p-4 border border-white/10">
          <p class="font-bold mb-2">I want to play</p>
          <button data-action="mobile-warning#goToJoin"
                  class="w-full bg-blue-600 text-white font-black py-3 px-6 rounded-xl hover:bg-blue-700 active:scale-[0.98] transition-all">
            Go to Join Screen
          </button>
        </div>

        <div class="bg-white/10 rounded-xl p-4 border border-white/10">
          <p class="font-bold mb-2">I am the host</p>
          <p class="text-blue-200 text-sm mb-3">
            RoomRally is designed to be displayed on a TV or laptop for the room to see.
            If you create a game here, this phone will become the main display.
          </p>
          <button data-action="mobile-warning#dismiss"
                  class="w-full bg-white/20 text-white font-bold py-3 px-6 rounded-xl hover:bg-white/30 active:scale-[0.98] transition-all border border-white/20">
            Continue Anyway
          </button>
        </div>
      </div>
    </div>
  </dialog>

  <%# ...rest of the existing /host view content... %>
</div>
```

The `<dialog>` element goes right after the opening `<div data-controller=...>` wrapper, before the existing content div.

**Step 5: Run the spec**

```bash
bin/rspec spec/system/mobile_warning_spec.rb
```

Expected: all pass.

**Step 6: Run the full system suite**

```bash
bin/rspec spec/system/
```

Expected: all pass. If `create_room_flow_spec.rb` or `player_join_flow_spec.rb` fail, investigate before continuing.

**Step 7: Commit**

```bash
git add app/javascript/controllers/mobile_warning_controller.js app/views/hosts/index.html.erb spec/system/mobile_warning_spec.rb
git commit -m "feat: add mobile warning modal on /host for logged-out users"
```

---

### Task 6: Final cleanup and PR

**Step 1: Run rubocop**

```bash
rubocop app/controllers/hosts_controller.rb
rubocop -A app/controllers/hosts_controller.rb
```

**Step 2: Run brakeman**

```bash
brakeman -q
```

Expected: no new warnings.

**Step 3: Run the full system suite one final time**

```bash
bin/rspec spec/system/
```

Expected: all pass.

**Step 4: Create a feature branch and PR**

This work should be on a feature branch. If you're not already on one:

```bash
git checkout -b feature/host-join-ux-redesign
git push -u origin feature/host-join-ux-redesign
```

Then open a PR targeting `main`.
