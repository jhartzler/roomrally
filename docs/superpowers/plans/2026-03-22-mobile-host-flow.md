# Mobile Host Flow Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a guest creates a room on their phone, they become a player+host automatically and land on the Hand view with Stage URL instructions, instead of the broken Stage-first flow.

**Architecture:** Three new focused controllers (MobileHostsController, ShortcodesController) plus small changes to RoomsController and the lobby partial. Server-side UA detection branches the redirect in `RoomsController#create`. A Stimulus clipboard controller handles copy-to-clipboard.

**Tech Stack:** Rails 8, Hotwire/Stimulus, RSpec request + system specs

**Spec:** `docs/superpowers/specs/2026-03-22-mobile-host-flow-design.md`

---

## Chunk 1: Routes, ShortcodesController, and UA Detection

### Task 1: Add routes

**Files:**
- Modify: `config/routes.rb:47-57` (rooms resource block) and before line 117 (catch-all)

- [ ] **Step 1: Write the routing request spec**

Create `spec/requests/shortcodes_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "Shortcodes", type: :request do
  describe "GET /:code" do
    let!(:room) { FactoryBot.create(:room) }

    it "redirects to the stage view" do
      get "/#{room.code}"
      expect(response).to redirect_to(room_stage_path(room))
    end

    it "handles lowercase codes" do
      get "/#{room.code.downcase}"
      expect(response).to redirect_to(room_stage_path(room))
    end

    it "returns 404 for nonexistent room codes" do
      get "/ZZZZ"
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("not found")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rspec spec/requests/shortcodes_spec.rb`
Expected: FAIL — route not defined

- [ ] **Step 3: Add routes to config/routes.rb**

Add `resource :mobile_host, only: [:show, :create]` inside the rooms resource block (after line 50, the `backstage` resource):

```ruby
resources :rooms, only: %i[create show], param: :code do
  resource :stage, only: :show
  resource :hand, only: :show
  resource :backstage, only: :show
  resource :mobile_host, only: [:show, :create]
  resources :score_tracker_entries, only: %i[create update destroy]
  member do
    post :start_game
    post :claim_host
    post :reassign_host
  end
end
```

Add the shortcode route immediately before the `*unmatched` catch-all (before line 117):

```ruby
# Short URL: roomrally.app/ABCD → stage view (case-insensitive)
get "/:code", to: "shortcodes#show", as: :shortcode, constraints: { code: /[A-Za-z0-9]{4}/ }

match "*unmatched", to: "errors#not_found", via: :all, constraints: ->(req) { !req.path.start_with?("/rails/") }
```

- [ ] **Step 4: Create ShortcodesController**

Create `app/controllers/shortcodes_controller.rb`:

```ruby
class ShortcodesController < ApplicationController
  def show
    room = Room.find_by(code: params[:code].upcase)

    if room
      redirect_to room_stage_path(room)
    else
      redirect_to root_path, alert: "Room '#{params[:code].upcase}' not found. Please check the room code and try again."
    end
  end
end
```

- [ ] **Step 5: Run shortcode specs to verify they pass**

Run: `bin/rspec spec/requests/shortcodes_spec.rb`
Expected: All 3 examples pass

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/shortcodes_controller.rb spec/requests/shortcodes_spec.rb
git commit -m "feat: add shortcode route and mobile_host resource route"
```

### Task 2: Add UA detection and mobile redirect to RoomsController

**Files:**
- Modify: `app/controllers/rooms_controller.rb:13-26` (create action) and private section
- Modify: `spec/requests/rooms_spec.rb`

- [ ] **Step 1: Write the request spec for mobile redirect**

Add to `spec/requests/rooms_spec.rb` a new top-level describe block:

```ruby
describe "POST /rooms (create)" do
  let(:game_type) { "Write And Vote" }

  context "when guest user on desktop" do
    it "redirects to stage view" do
      post rooms_path, params: { game_type: game_type }
      room = Room.last
      expect(response).to redirect_to(room_stage_path(room))
    end
  end

  context "when guest user on mobile" do
    it "redirects to mobile host setup" do
      post rooms_path, params: { game_type: game_type },
           headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Mobile/15E148" }
      room = Room.last
      expect(response).to redirect_to(room_mobile_host_path(room))
    end
  end

  context "when logged-in user" do
    let(:user) { FactoryBot.create(:user) }

    before do
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      # rubocop:enable RSpec/AnyInstance
    end

    it "redirects to backstage regardless of UA" do
      post rooms_path, params: { game_type: game_type },
           headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Mobile/15E148" }
      room = Room.last
      expect(response).to redirect_to(room_backstage_path(room))
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rspec spec/requests/rooms_spec.rb -e "POST /rooms"`
Expected: FAIL — mobile test expects mobile_host redirect but gets stage redirect

- [ ] **Step 3: Add mobile_request? and update create action**

In `app/controllers/rooms_controller.rb`, update the `create` method (lines 13-26):

```ruby
def create
  room = Room.create!(room_params)
  Analytics.track(
    distinct_id: current_user ? "user_#{current_user.id}" : "room_#{room.code}",
    event: "room_created",
    properties: { game_type: room.game_type, room_code: room.code, from_template: false }
  )
  if current_user
    room.update(user: current_user)
    redirect_to room_backstage_path(room)
  elsif mobile_request?
    redirect_to room_mobile_host_path(room)
  else
    redirect_to room_stage_path(room)
  end
end
```

Add to the private section (after `room_not_found`):

```ruby
def mobile_request?
  request.user_agent&.match?(/Mobile|Android|iPhone|iPod/i)
end
```

- [ ] **Step 4: Run specs to verify they pass**

Run: `bin/rspec spec/requests/rooms_spec.rb`
Expected: All examples pass

- [ ] **Step 5: Commit**

```bash
git add app/controllers/rooms_controller.rb spec/requests/rooms_spec.rb
git commit -m "feat: redirect mobile guests to mobile host setup on room creation"
```

---

## Chunk 2: MobileHostsController

### Task 3: Create MobileHostsController with show and create actions

**Files:**
- Create: `app/controllers/mobile_hosts_controller.rb`
- Create: `app/views/mobile_hosts/show.html.erb`
- Create: `spec/requests/mobile_hosts_spec.rb`

- [ ] **Step 1: Write the request specs**

Create `spec/requests/mobile_hosts_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "MobileHosts", type: :request do
  let(:room) { FactoryBot.create(:room) }

  describe "GET /rooms/:code/mobile_host" do
    it "renders the name entry form" do
      get room_mobile_host_path(room)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("name")
    end

    context "when room already has a host" do
      let(:host_player) { FactoryBot.create(:player, room: room) }
      before { room.update!(host: host_player) }

      it "redirects to hand view" do
        get room_mobile_host_path(room)
        expect(response).to redirect_to(room_hand_path(room))
      end
    end

    context "when room has a facilitator" do
      let(:user) { FactoryBot.create(:user) }
      before { room.update!(user: user) }

      it "redirects to join page" do
        get room_mobile_host_path(room)
        expect(response).to redirect_to(join_room_path(code: room.code))
      end
    end
  end

  describe "POST /rooms/:code/mobile_host" do
    it "creates a player, assigns as host, and redirects to hand view" do
      expect {
        post room_mobile_host_path(room), params: { player: { name: "Alex" } }
      }.to change(Player, :count).by(1)

      player = Player.last
      expect(player.name).to eq("Alex")
      expect(player.status).to eq("active")
      expect(player.room).to eq(room)
      expect(room.reload.host).to eq(player)
      expect(response).to redirect_to(room_hand_path(room))
    end

    it "sets the session player_session_id" do
      post room_mobile_host_path(room), params: { player: { name: "Alex" } }
      # Session is set — following redirect should resolve current_player
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    context "when session already has a player in this room" do
      before do
        # First POST creates a player and sets the session
        post room_mobile_host_path(room), params: { player: { name: "Alex" } }
      end

      it "redirects to hand view without creating a new player" do
        expect {
          post room_mobile_host_path(room), params: { player: { name: "Bob" } }
        }.not_to change(Player, :count)
        expect(response).to redirect_to(room_hand_path(room))
      end
    end

    context "when room already has a host" do
      let(:host_player) { FactoryBot.create(:player, room: room) }
      before { room.update!(host: host_player) }

      it "redirects to hand view with alert" do
        post room_mobile_host_path(room), params: { player: { name: "Alex" } }
        expect(response).to redirect_to(room_hand_path(room))
        expect(flash[:alert]).to be_present
      end
    end

    context "when room has a facilitator" do
      let(:user) { FactoryBot.create(:user) }
      before { room.update!(user: user) }

      it "redirects to join page" do
        post room_mobile_host_path(room), params: { player: { name: "Alex" } }
        expect(response).to redirect_to(join_room_path(code: room.code))
      end
    end

    context "when player name is blank" do
      it "re-renders the form with errors" do
        post room_mobile_host_path(room), params: { player: { name: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rspec spec/requests/mobile_hosts_spec.rb`
Expected: FAIL — controller not defined

- [ ] **Step 3: Create MobileHostsController**

Create `app/controllers/mobile_hosts_controller.rb`:

```ruby
class MobileHostsController < ApplicationController
  before_action :set_room
  before_action :guard_availability
  rescue_from ActiveRecord::RecordNotFound, with: :room_not_found

  def show
    @player = Player.new
  end

  def create
    # Check if session already has a player in this room
    existing_player = @room.players.find_by(session_id: session[:player_session_id])
    if existing_player
      redirect_to room_hand_path(@room)
      return
    end

    @player = @room.players.build(player_params)
    session_id = session[:player_session_id] || SecureRandom.uuid
    session[:player_session_id] = session_id
    @player.session_id = session_id
    @player.status = :active

    if @player.save
      @room.update!(host: @player)

      Rails.logger.info "Mobile host #{@player.name} created in room #{@room.code}"

      Analytics.track(
        distinct_id: "player_#{@player.session_id}",
        event: "player_joined",
        properties: { room_code: @room.code, game_type: @room.game_type, mobile_host: true, player_count_after: @room.players.active_players.count }
      )

      GameBroadcaster.broadcast_player_joined(room: @room, player: @player)
      GameBroadcaster.broadcast_host_change(room: @room)

      redirect_to room_hand_path(@room)
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def set_room
    @room = Room.find_by!(code: params[:room_code])
  end

  def guard_availability
    if @room.user.present?
      redirect_to join_room_path(code: @room.code)
      return
    end

    if @room.host.present?
      redirect_to room_hand_path(@room), alert: "This room already has a host."
      return
    end
  end

  def player_params
    params.require(:player).permit(:name)
  end

  def room_not_found
    redirect_to root_path, alert: "Room not found. Please check the room code and try again."
  end
end
```

- [ ] **Step 4: Create the mobile host setup view**

Create `app/views/mobile_hosts/show.html.erb`:

```erb
<div class="flex items-center justify-center min-h-[calc(100vh-4rem)]">
  <div class="max-w-md w-full">
    <div class="text-center mb-8">
      <h1 class="text-5xl font-bold text-white mb-2">🎮</h1>
      <h1 class="text-4xl font-black text-white mb-2 drop-shadow-lg tracking-tight">You're Hosting!</h1>
      <div class="inline-block bg-white/10 backdrop-blur-md rounded-xl px-6 py-3 mb-3 border border-white/20">
        <p class="text-blue-200 text-xs font-bold tracking-widest mb-1">Room Code</p>
        <p class="text-3xl font-black text-white font-mono"><%= @room.code %></p>
      </div>
      <div class="inline-block bg-white/10 backdrop-blur-md rounded-lg px-4 py-2 border border-white/20">
        <p class="text-blue-200 text-[10px] font-bold tracking-widest mb-0.5">Game</p>
        <p class="text-lg font-bold text-white"><%= @room.display_name %></p>
      </div>
    </div>

    <div class="bg-white/10 backdrop-blur-md rounded-3xl shadow-2xl p-8 border border-white/20">
      <%= form_with model: @player, url: room_mobile_host_path(@room), class: "space-y-6" do |form| %>
        <div>
          <%= form.label :name, "Pick a name so players know who's running the show", class: "block text-blue-200 font-bold text-xs tracking-widest mb-3" %>
          <%= form.text_field :name, autofocus: true, class: "w-full px-4 py-4 bg-white/20 border-2 border-white/10 rounded-xl text-white placeholder-white/30 focus:outline-none focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20 transition-all text-lg", placeholder: "Enter your name" %>
        </div>

        <%= form.submit "Let's Go!", class: "w-full bg-orange-500 text-white font-black py-4 px-6 rounded-xl hover:bg-orange-600 active:scale-[0.98] transform hover:shadow-lg shadow-orange-900/20 transition-all duration-200 text-lg tracking-tight" %>
      <% end %>
    </div>
  </div>
</div>
```

- [ ] **Step 5: Run specs to verify they pass**

Run: `bin/rspec spec/requests/mobile_hosts_spec.rb`
Expected: All examples pass

- [ ] **Step 6: Commit**

```bash
git add app/controllers/mobile_hosts_controller.rb app/views/mobile_hosts/show.html.erb spec/requests/mobile_hosts_spec.rb
git commit -m "feat: add MobileHostsController for phone-based room creation"
```

---

## Chunk 3: Stage URL Banner and Clipboard Controller

### Task 4: Add clipboard Stimulus controller

**Files:**
- Create: `app/javascript/controllers/clipboard_controller.js`

- [ ] **Step 1: Create the clipboard controller**

Create `app/javascript/controllers/clipboard_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }
  static targets = ["button"]

  copy() {
    navigator.clipboard.writeText(this.textValue)
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = "Copied!"
    setTimeout(() => { this.buttonTarget.textContent = original }, 2000)
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/javascript/controllers/clipboard_controller.js
git commit -m "feat: add clipboard Stimulus controller for copy-to-clipboard"
```

### Task 5: Add Stage URL banner to lobby partial

**Files:**
- Modify: `app/views/rooms/_lobby.html.erb:31-35` (before host controls section)

- [ ] **Step 1: Write a system spec for the banner**

Create `spec/system/mobile_host_flow_spec.rb`:

Note: This project uses Selenium Chrome, so `set_rack_session` is not available. Use `visit set_player_session_path(player)` (dev testing endpoint) to establish session identity.

```ruby
require 'rails_helper'

RSpec.describe 'Mobile Host Flow', type: :system do
  describe 'stage URL banner in lobby' do
    it 'shows the stage URL banner to the host' do
      room = FactoryBot.create(:room)
      host = FactoryBot.create(:player, room: room, name: "HostPlayer")
      room.update!(host: host)

      # Set session via dev testing endpoint (Selenium can't set rack session directly)
      visit set_player_session_path(host)
      visit room_hand_path(room)
      expect(page).to have_content("Throw this up on a big screen")
      expect(page).to have_content(room.code)
      expect(page).to have_button("Copy Link")
    end

    it 'does not show the banner to non-host players' do
      room = FactoryBot.create(:room)
      host = FactoryBot.create(:player, room: room, name: "HostPlayer")
      player = FactoryBot.create(:player, room: room, name: "RegularPlayer")
      room.update!(host: host)

      visit set_player_session_path(player)
      visit room_hand_path(room)
      expect(page).not_to have_content("Throw this up on a big screen")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rspec spec/system/mobile_host_flow_spec.rb`
Expected: FAIL — banner text not found

- [ ] **Step 3: Add the Stage URL banner to _lobby.html.erb**

In `app/views/rooms/_lobby.html.erb`, add the banner between the claim-host section (line 28) and the host controls section (line 30). The full file becomes:

```erb
<%# app/views/rooms/_lobby.html.erb %>
<div class="text-center mb-8">
  <h2 class="text-3xl font-black text-white mb-2 drop-shadow-md">Game Lobby</h2>
  <p class="text-blue-100 flex items-center justify-center gap-2 font-medium">
    <span class="animate-pulse">⏳</span>
    The crowd is gathering...
  </p>
</div>

<!-- Player List -->
<div id="player-list" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
  <%= render partial: "players/player", collection: room.players.active_players, as: :player, locals: { current_player: player } %>
</div>

<!-- Claim Host Button (No Host, non-facilitated rooms only) -->
<% if room.host.nil? && !room.user.present? %>
  <div class="border-t-2 border-white/10 pt-6 mb-6">
    <div class="max-w-md mx-auto">
      <div class="bg-red-500/20 backdrop-blur-md rounded-xl p-4 mb-4 border border-red-400/30">
        <p class="text-center text-sm font-semibold text-red-100 flex items-center justify-center gap-2">
          <span>⚠️</span>
          <span>No host in this room. Claim host to start the game!</span>
        </p>
      </div>
      <%= button_to "Claim Host", claim_host_room_path(room.code), method: :post, class: "w-full bg-gradient-to-r from-orange-500 to-amber-500 text-white font-bold py-4 px-6 rounded-xl hover:from-orange-600 hover:to-amber-600 transform hover:scale-105 transition-all duration-200 shadow-lg text-lg border border-white/20" %>
    </div>
  </div>
<% end %>

<!-- Stage URL Banner (Host Only) -->
<% if player == room.host %>
  <div class="border-t-2 border-white/10 pt-6 mb-6" data-controller="clipboard" data-clipboard-text-value="<%= request.base_url %>/<%= room.code %>">
    <div class="max-w-md mx-auto">
      <div class="bg-indigo-500/20 backdrop-blur-md rounded-xl p-5 border border-indigo-400/30 text-center">
        <p class="text-lg font-black text-white mb-2">Throw this up on a big screen!</p>
        <p class="text-3xl font-black text-white font-mono tracking-wider mb-3"><%= request.base_url %>/<%= room.code %></p>
        <button data-action="click->clipboard#copy" data-clipboard-target="button"
                class="bg-white/20 text-white font-bold py-2 px-6 rounded-lg hover:bg-white/30 transition-all duration-200 text-sm border border-white/20 mb-2">
          Copy Link
        </button>
        <p class="text-indigo-200 text-xs">Laptop, TV, projector — anything bigger than your phone</p>
      </div>
    </div>
  </div>
<% end %>

<!-- Start Game Button (Host Only) -->
<% if player == room.host %>
  <div id="host-controls" class="border-t-2 border-white/10 pt-6">
    <%= render "rooms/host_controls", room: room %>
  </div>
<% end %>
```

- [ ] **Step 4: Run specs to verify they pass**

Run: `bin/rspec spec/system/mobile_host_flow_spec.rb`
Expected: All examples pass

- [ ] **Step 5: Commit**

```bash
git add app/views/rooms/_lobby.html.erb app/javascript/controllers/clipboard_controller.js spec/system/mobile_host_flow_spec.rb
git commit -m "feat: add stage URL banner with copy button for mobile hosts"
```

---

## Chunk 4: System Specs for End-to-End Flow

### Task 6: Add end-to-end system specs

**Files:**
- Modify: `spec/system/mobile_host_flow_spec.rb` (add more specs)
- Modify: `spec/system/create_room_flow_spec.rb` (update existing spec)

- [ ] **Step 1: Add end-to-end mobile host flow specs**

Add to `spec/system/mobile_host_flow_spec.rb`:

Note: Selenium Chrome doesn't support `page.driver.header` for setting UA. The UA-branching logic is covered by request specs (Task 2). System specs test the mobile host setup flow by visiting the URL directly.

```ruby
describe 'full mobile host flow (starting from mobile host setup)' do
  it 'user enters name, becomes host, sees banner on hand view' do
    room = FactoryBot.create(:room)

    # Start at mobile host setup page (simulates redirect from RoomsController)
    visit room_mobile_host_path(room)

    expect(page).to have_content("You're Hosting!")
    fill_in "Enter your name", with: "PartyStarter"
    click_on "Let's Go!"

    # Should land on hand view as host
    expect(page).to have_current_path(room_hand_path(room))
    expect(page).to have_content("Throw this up on a big screen")
    expect(page).to have_content("PartyStarter")

    # Verify player and host were created
    player = Player.find_by(name: "PartyStarter")
    expect(player).not_to be_nil
    expect(room.reload.host).to eq(player)
  end
end

describe 'banner disappears when game starts' do
  it 'hides the stage URL banner after game starts', :js do
    room = FactoryBot.create(:room, game_type: "Write And Vote")
    host = FactoryBot.create(:player, room: room, name: "Host")
    FactoryBot.create(:player, room: room, name: "Player2")
    FactoryBot.create(:player, room: room, name: "Player3")
    room.update!(host: host)

    # Create prompts for the game
    default_pack = FactoryBot.create(:prompt_pack, :default)
    FactoryBot.create_list(:prompt, 5, prompt_pack: default_pack)

    visit set_player_session_path(host)
    visit room_hand_path(room)

    # Banner is visible in lobby
    expect(page).to have_content("Throw this up on a big screen")

    # Start the game
    click_on "Start Game"

    # Banner should disappear (lobby partial replaced by game hand partial)
    expect(page).not_to have_content("Throw this up on a big screen")
  end
end

describe 'shortcode route' do
  it 'redirects /:code to stage view' do
    room = FactoryBot.create(:room)
    visit "/#{room.code}"
    expect(page).to have_current_path(room_stage_path(room))
  end

  it 'handles lowercase codes' do
    room = FactoryBot.create(:room)
    visit "/#{room.code.downcase}"
    expect(page).to have_current_path(room_stage_path(room))
  end
end
```

- [ ] **Step 2: Update existing create_room_flow_spec.rb**

The existing spec at `spec/system/create_room_flow_spec.rb:18-26` tests that room creation redirects to stage. This is desktop behavior. Update the test description to be explicit:

```ruby
it 'creates a room and redirects to stage (desktop)' do
  visit host_path
  click_on 'Create Room'
  expect(page).to have_current_path(/\/rooms\/[A-Z0-9]{4}\/stage/, wait: 5)
  room_code = page.current_path.split('/')[2]
  room = Room.find_by!(code: room_code)
  expect(page).to have_content(room.code)
  expect(page).to have_selector('#stage_content')
end
```

- [ ] **Step 3: Run all specs**

Run: `bin/rspec spec/system/mobile_host_flow_spec.rb spec/system/create_room_flow_spec.rb`
Expected: All examples pass

- [ ] **Step 4: Run the full test suite to check for regressions**

Run: `bin/rspec`
Expected: All existing tests still pass

- [ ] **Step 5: Run rubocop and fix any issues**

Run: `rubocop -A`

- [ ] **Step 6: Commit**

```bash
git add spec/system/mobile_host_flow_spec.rb spec/system/create_room_flow_spec.rb
git commit -m "test: add end-to-end system specs for mobile host flow"
```

### Task 7: Remove the mobile warning dialog on /host

The existing mobile warning dialog on `/host` (`app/views/hosts/index.html.erb:7-37`) shows a modal asking mobile users "are you joining or hosting?" with a "Continue Anyway" button. With the new server-side UA redirect, mobile users who click "Create Room" will be redirected to `/rooms/ABCD/mobile_host` before they ever see the Stage — making this dialog redundant and confusing (double-gatekeeping).

**Files:**
- Modify: `app/views/hosts/index.html.erb` (remove dialog and `mobile-warning` controller)
- Modify: `spec/system/mobile_warning_spec.rb` (update or remove tests)

- [ ] **Step 1: Remove the mobile warning dialog from hosts/index.html.erb**

Remove the `data-controller="mobile-warning"` wrapper div and the `<dialog>` element (lines 7-37). The outer div should just be a plain div without the data-controller attribute.

Replace:
```erb
<div data-controller="mobile-warning"
     data-mobile-warning-logged-in-value="<%= current_user.present? %>">

  <dialog data-mobile-warning-target="dialog" ...>
    ...
  </dialog>
```

With just:
```erb
<div>
```

- [ ] **Step 2: Update mobile_warning_spec.rb**

Review `spec/system/mobile_warning_spec.rb` and update or remove tests that verify the dialog shows on `/host`. If the spec only tests the `/host` page dialog, the file can be removed entirely. If it tests other mobile warning behavior, update accordingly.

- [ ] **Step 3: Run specs**

Run: `bin/rspec spec/system/mobile_warning_spec.rb spec/system/create_room_flow_spec.rb`
Expected: All pass (or file removed)

- [ ] **Step 4: Commit**

```bash
git add app/views/hosts/index.html.erb spec/system/mobile_warning_spec.rb
git commit -m "chore: remove mobile warning dialog from /host (replaced by server-side redirect)"
```

### Task 8: Final verification and cleanup

- [ ] **Step 1: Run rubocop and fix any issues**

Run: `rubocop -A`

- [ ] **Step 2: Run full test suite**

Run: `bin/rspec`
Expected: All green

- [ ] **Step 3: Run brakeman security check**

Run: `brakeman -q`
Expected: No new warnings

- [ ] **Step 4: Verify routes look correct**

Run: `bin/rails routes | grep -E "mobile_host|shortcode"`
Expected output should show:
- `room_mobile_host GET /rooms/:room_code/mobile_host(.:format) mobile_hosts#show`
- `room_mobile_host POST /rooms/:room_code/mobile_host(.:format) mobile_hosts#create`
- `shortcode GET /:code(.:format) shortcodes#show {:code=>/[A-Za-z0-9]{4}/}`
