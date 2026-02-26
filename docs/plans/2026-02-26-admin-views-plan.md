# Admin Views Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a mobile-first `/admin` panel that lets the site owner view user stats and reset AI prompt limits.

**Architecture:** Rails `/admin` namespace with `Admin::BaseController` enforcing an `admin?` boolean flag. Two screens: user list (index with inline reset buttons) and user detail (three stat cards). Reset action flips `counts_against_limit` to false on current-window requests rather than deleting them.

**Tech Stack:** Rails 8, RSpec + Capybara system tests, Tailwind CSS, FactoryBot

---

### Task 1: Add `admin` column to users

**Files:**
- Create: `db/migrate/<timestamp>_add_admin_to_users.rb`
- Modify: `spec/factories/users.rb`
- Test: `spec/models/user_spec.rb`

**Step 1: Write the failing model test**

Add to `spec/models/user_spec.rb` inside `RSpec.describe User`:

```ruby
describe "#admin?" do
  it "is false by default" do
    user = build(:user)
    expect(user.admin?).to be false
  end

  it "is true when admin flag is set" do
    user = build(:user, admin: true)
    expect(user.admin?).to be true
  end
end
```

**Step 2: Run test to verify it fails**

```bash
bin/rspec spec/models/user_spec.rb -e "admin?"
```

Expected: FAIL with `unknown attribute 'admin'` or column not found.

**Step 3: Generate and run the migration**

```bash
bin/rails generate migration AddAdminToUsers admin:boolean
```

Edit the generated file so it looks like:

```ruby
class AddAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin, :boolean, default: false, null: false
  end
end
```

```bash
bin/rails db:migrate
```

**Step 4: Add admin trait to factory**

In `spec/factories/users.rb`, add a trait:

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    password { "password" }
    provider { "google_oauth2" }
    uid { "123456" }

    trait :admin do
      admin { true }
    end
  end
end
```

**Step 5: Run test to verify it passes**

```bash
bin/rspec spec/models/user_spec.rb -e "admin?"
```

Expected: 2 examples, 0 failures.

**Step 6: Commit**

```bash
git add db/migrate/*_add_admin_to_users.rb db/schema.rb spec/models/user_spec.rb spec/factories/users.rb
git commit -m "feat: add admin boolean flag to users"
```

---

### Task 2: Admin::BaseController with access guard

**Files:**
- Create: `app/controllers/admin/base_controller.rb`
- Test: `spec/system/admin_access_spec.rb`

**Step 1: Write the failing system test**

Create `spec/system/admin_access_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "Admin access control", type: :system do
  let(:regular_user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }

  context "when not logged in" do
    it "redirects to root" do
      visit admin_users_path
      expect(page).to have_current_path(root_path)
    end
  end

  context "when logged in as regular user" do
    before { sign_in(regular_user) }

    it "redirects to root with alert" do
      visit admin_users_path
      expect(page).to have_current_path(root_path)
    end
  end

  context "when logged in as admin" do
    before { sign_in(admin_user) }

    it "allows access to admin users list" do
      visit admin_users_path
      expect(page).to have_current_path(admin_users_path)
    end
  end
end
```

**Step 2: Run test to verify it fails**

```bash
bin/rspec spec/system/admin_access_spec.rb
```

Expected: FAIL with `uninitialized constant Admin::BaseController` or routing error.

**Step 3: Add admin routes**

In `config/routes.rb`, add before the final `match "*unmatched"` line:

```ruby
namespace :admin do
  root to: "users#index"
  resources :users, only: %i[index show] do
    member do
      post :reset_ai_limit
    end
  end
end
```

**Step 4: Create Admin::BaseController**

Create `app/controllers/admin/base_controller.rb`:

```ruby
class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  layout "admin"

  private

  def require_admin!
    redirect_to root_path, alert: "Not authorized." unless current_user&.admin?
  end
end
```

**Step 5: Create a stub Admin::UsersController** (to make routes resolve for the test)

Create `app/controllers/admin/users_controller.rb`:

```ruby
class Admin::UsersController < Admin::BaseController
  def index
    @users = User.all
    render plain: "admin users"
  end
end
```

**Step 6: Run test to verify it passes**

```bash
bin/rspec spec/system/admin_access_spec.rb
```

Expected: 3 examples, 0 failures.

**Step 7: Commit**

```bash
git add config/routes.rb app/controllers/admin/ spec/system/admin_access_spec.rb
git commit -m "feat: add admin namespace with access guard"
```

---

### Task 3: Admin layout

**Files:**
- Create: `app/views/layouts/admin.html.erb`

**Step 1: Create the layout**

Create `app/views/layouts/admin.html.erb`:

```erb
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>Admin · RoomRally</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag :tailwind, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  <body class="min-h-screen bg-gray-100 font-sans text-gray-900">
    <% if flash.any? %>
      <div id="flash" class="fixed top-4 right-4 z-50 space-y-2 max-w-sm">
        <% flash.each do |key, value| %>
          <div class="<%= key == 'notice' ? 'bg-green-600' : 'bg-red-600' %> text-white px-4 py-3 rounded-lg shadow-lg font-semibold text-sm"
               data-controller="flash">
            <%= value %>
          </div>
        <% end %>
      </div>
    <% end %>
    <header class="bg-white border-b border-gray-200 px-4 py-3 flex items-center justify-between">
      <div class="flex items-center gap-3">
        <%= link_to admin_root_path, class: "text-lg font-bold text-indigo-700" do %>
          RoomRally Admin
        <% end %>
        <% if content_for?(:breadcrumb) %>
          <span class="text-gray-400">/</span>
          <%= yield :breadcrumb %>
        <% end %>
      </div>
      <span class="text-xs font-semibold bg-red-100 text-red-700 px-2 py-1 rounded-full">ADMIN</span>
    </header>
    <main class="max-w-2xl mx-auto px-4 py-6">
      <%= yield %>
    </main>
  </body>
</html>
```

**Step 2: Verify layout loads by running existing access spec**

```bash
bin/rspec spec/system/admin_access_spec.rb
```

Expected: 3 examples, 0 failures (layout renders without error).

**Step 3: Commit**

```bash
git add app/views/layouts/admin.html.erb
git commit -m "feat: add admin layout"
```

---

### Task 4: Admin users index — user list with AI stats

**Files:**
- Modify: `app/controllers/admin/users_controller.rb`
- Create: `app/views/admin/users/index.html.erb`
- Test: `spec/system/admin_users_spec.rb`

**Step 1: Write the failing system test**

Create `spec/system/admin_users_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "Admin users index", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:other_user) { create(:user, name: "Jane Player", email: "jane@example.com") }

  before { sign_in(admin) }

  it "lists all users with their names and emails" do
    visit admin_users_path
    expect(page).to have_content("Jane Player")
    expect(page).to have_content("jane@example.com")
  end

  it "shows AI usage for a user with requests" do
    create(:ai_generation_request, user: other_user, counts_against_limit: true,
           created_at: 1.hour.ago)
    visit admin_users_path
    expect(page).to have_content("1 / 10")
  end

  it "links to user detail page" do
    visit admin_users_path
    click_on "Jane Player"
    expect(page).to have_current_path(admin_user_path(other_user))
  end
end
```

**Step 2: Run test to verify it fails**

```bash
bin/rspec spec/system/admin_users_spec.rb
```

Expected: FAIL — controller renders `plain: "admin users"` stub, no real view.

**Step 3: Implement the controller index action**

Replace `app/controllers/admin/users_controller.rb` with:

```ruby
class Admin::UsersController < Admin::BaseController
  def index
    @users = User.includes(:ai_generation_requests, :rooms, :prompt_packs, :trivia_packs, :category_packs)
                 .order(created_at: :desc)
  end

  def show
    @user = User.includes(:ai_generation_requests, :rooms, :prompt_packs, :trivia_packs, :category_packs)
                .find(params[:id])
  end

  def reset_ai_limit
    @user = User.find(params[:id])
    @user.ai_generation_requests
         .where(counts_against_limit: true)
         .where("created_at > ?", User::AI_WINDOW_HOURS.hours.ago)
         .update_all(counts_against_limit: false)
    redirect_to admin_user_path(@user), notice: "AI limit reset for #{@user.name}."
  end
end
```

**Step 4: Create the index view**

Create `app/views/admin/users/index.html.erb`:

```erb
<% content_for :breadcrumb do %>
  <span class="text-sm font-semibold text-gray-700">Users</span>
<% end %>

<h1 class="text-xl font-bold mb-4">Users (<%= @users.count %>)</h1>

<div class="space-y-3">
  <% @users.each do |user| %>
    <%
      window_start = User::AI_WINDOW_HOURS.hours.ago
      ai_used = user.ai_generation_requests.select { |r| r.counts_against_limit && r.created_at > window_start }.count
    %>
    <div class="bg-white rounded-xl shadow-sm p-4">
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0 flex-1">
          <%= link_to admin_user_path(user), class: "font-semibold text-indigo-700 hover:underline truncate block" do %>
            <%= user.name %>
          <% end %>
          <p class="text-xs text-gray-500 truncate"><%= user.email %></p>
          <p class="text-xs text-gray-400 mt-1">Joined <%= user.created_at.strftime("%b %d, %Y") %></p>
        </div>
        <div class="text-right shrink-0">
          <p class="text-sm font-semibold <%= ai_used > 0 ? 'text-orange-600' : 'text-gray-400' %>">
            <%= ai_used %> / 10
          </p>
          <p class="text-xs text-gray-400">AI used</p>
          <% if ai_used > 0 %>
            <%= button_to "Reset", reset_ai_limit_admin_user_path(user),
                method: :post,
                class: "mt-2 text-xs bg-orange-100 text-orange-700 hover:bg-orange-200 font-semibold px-3 py-1 rounded-full" %>
          <% end %>
        </div>
      </div>
    </div>
  <% end %>
</div>
```

**Step 5: Run test to verify it passes**

```bash
bin/rspec spec/system/admin_users_spec.rb
```

Expected: 3 examples, 0 failures.

**Step 6: Commit**

```bash
git add app/controllers/admin/users_controller.rb app/views/admin/users/index.html.erb spec/system/admin_users_spec.rb
git commit -m "feat: add admin users index with AI usage stats"
```

---

### Task 5: Admin user detail + reset AI limit

**Files:**
- Create: `app/views/admin/users/show.html.erb`
- Modify: `spec/system/admin_users_spec.rb` (add show + reset tests)

**Step 1: Add failing tests for show and reset**

Append to `spec/system/admin_users_spec.rb`:

```ruby
RSpec.describe "Admin user detail", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:target_user) { create(:user, name: "Bob Host", email: "bob@example.com") }

  before { sign_in(admin) }

  it "shows AI usage stats on the detail page" do
    create(:ai_generation_request, user: target_user, counts_against_limit: true,
           created_at: 1.hour.ago)
    visit admin_user_path(target_user)
    expect(page).to have_content("1 / 10")
    expect(page).to have_button("Reset AI Limit")
  end

  it "shows engagement stats" do
    create(:room, user: target_user)
    visit admin_user_path(target_user)
    expect(page).to have_content("1")  # rooms created
  end

  it "resets AI limit and shows success flash" do
    create(:ai_generation_request, user: target_user, counts_against_limit: true,
           created_at: 1.hour.ago)
    visit admin_user_path(target_user)
    click_button "Reset AI Limit"
    expect(page).to have_content("AI limit reset for Bob Host")
    expect(page).to have_content("0 / 10")
  end
end
```

**Step 2: Run test to verify it fails**

```bash
bin/rspec spec/system/admin_users_spec.rb -e "Admin user detail"
```

Expected: FAIL — missing show template.

**Step 3: Create the show view**

Create `app/views/admin/users/show.html.erb`:

```erb
<% content_for :breadcrumb do %>
  <%= link_to "Users", admin_users_path, class: "text-sm text-indigo-600 hover:underline" %>
  <span class="text-gray-400 mx-1">/</span>
  <span class="text-sm font-semibold text-gray-700"><%= @user.name %></span>
<% end %>

<%
  window_start = User::AI_WINDOW_HOURS.hours.ago
  window_requests = @user.ai_generation_requests.select { |r| r.created_at > window_start }
  ai_used = window_requests.count { |r| r.counts_against_limit }
  ai_remaining = [User::AI_REQUEST_LIMIT - ai_used, 0].max
  grace_used = window_requests.count { |r| !r.counts_against_limit && r.status == "failed" }
  oldest_counting = window_requests.select(&:counts_against_limit).min_by(&:created_at)
  reset_at = oldest_counting&.created_at&.+(User::AI_WINDOW_HOURS.hours)
%>

<div class="mb-4">
  <h1 class="text-xl font-bold"><%= @user.name %></h1>
  <p class="text-sm text-gray-500"><%= @user.email %></p>
  <p class="text-xs text-gray-400">Joined <%= @user.created_at.strftime("%B %d, %Y") %></p>
</div>

<%# AI Usage Card %>
<div class="bg-white rounded-xl shadow-sm p-5 mb-4">
  <h2 class="font-bold text-gray-700 mb-3">AI Usage</h2>
  <div class="grid grid-cols-2 gap-3 mb-4">
    <div>
      <p class="text-2xl font-black <%= ai_used > 0 ? 'text-orange-600' : 'text-gray-300' %>">
        <%= ai_used %> / <%= User::AI_REQUEST_LIMIT %>
      </p>
      <p class="text-xs text-gray-500">Used this window</p>
    </div>
    <div>
      <p class="text-2xl font-black text-green-600"><%= ai_remaining %></p>
      <p class="text-xs text-gray-500">Remaining</p>
    </div>
    <% if grace_used > 0 %>
      <div>
        <p class="text-lg font-bold text-gray-500"><%= grace_used %></p>
        <p class="text-xs text-gray-500">Grace failures</p>
      </div>
    <% end %>
    <% if reset_at %>
      <div>
        <p class="text-sm font-semibold text-gray-600"><%= reset_at.strftime("%I:%M %p") %></p>
        <p class="text-xs text-gray-500">Window resets</p>
      </div>
    <% end %>
  </div>
  <% if ai_used > 0 %>
    <%= button_to "Reset AI Limit", reset_ai_limit_admin_user_path(@user),
        method: :post,
        class: "w-full bg-orange-500 hover:bg-orange-600 text-white font-bold py-3 rounded-xl text-sm" %>
  <% else %>
    <p class="text-center text-sm text-gray-400 py-2">No requests in current window</p>
  <% end %>
</div>

<%# Engagement Card %>
<div class="bg-white rounded-xl shadow-sm p-5 mb-4">
  <h2 class="font-bold text-gray-700 mb-3">Engagement</h2>
  <div class="space-y-2 text-sm">
    <div class="flex justify-between">
      <span class="text-gray-600">Rooms created</span>
      <span class="font-semibold"><%= @user.rooms.size %></span>
    </div>
    <% last_room = @user.rooms.max_by(&:created_at) %>
    <% if last_room %>
      <div class="flex justify-between">
        <span class="text-gray-600">Last room</span>
        <span class="font-semibold"><%= last_room.created_at.strftime("%b %d, %Y") %></span>
      </div>
    <% end %>
  </div>
</div>

<%# Packs Card %>
<div class="bg-white rounded-xl shadow-sm p-5 mb-4">
  <h2 class="font-bold text-gray-700 mb-3">Packs</h2>
  <div class="space-y-2 text-sm">
    <div class="flex justify-between">
      <span class="text-gray-600">Prompt packs</span>
      <span class="font-semibold">
        <%= @user.prompt_packs.size %>
        <span class="text-gray-400 font-normal">
          (<%= @user.prompt_packs.count { |p| p.status == "live" } %> live)
        </span>
      </span>
    </div>
    <div class="flex justify-between">
      <span class="text-gray-600">Trivia packs</span>
      <span class="font-semibold">
        <%= @user.trivia_packs.size %>
        <span class="text-gray-400 font-normal">
          (<%= @user.trivia_packs.count { |p| p.status == "live" } %> live)
        </span>
      </span>
    </div>
    <div class="flex justify-between">
      <span class="text-gray-600">Category packs</span>
      <span class="font-semibold">
        <%= @user.category_packs.size %>
        <span class="text-gray-400 font-normal">
          (<%= @user.category_packs.count { |p| p.status == "live" } %> live)
        </span>
      </span>
    </div>
  </div>
</div>
```

**Step 4: Run tests to verify they pass**

```bash
bin/rspec spec/system/admin_users_spec.rb
```

Expected: all examples pass, 0 failures.

**Step 5: Commit**

```bash
git add app/views/admin/users/show.html.erb spec/system/admin_users_spec.rb
git commit -m "feat: add admin user detail page with stats and AI limit reset"
```

---

### Task 6: Final check — run full test suite

**Step 1: Run all tests**

```bash
bin/rspec
```

Expected: 0 failures. Fix any regressions before continuing.

**Step 2: Rubocop**

```bash
rubocop app/controllers/admin/ app/views/admin/
```

Fix any offenses with `rubocop -A app/controllers/admin/`.

**Step 3: Brakeman security check**

```bash
brakeman -q
```

Expected: no new warnings.

**Step 4: Set yourself as admin via rails console** (manual step, not automated)

```bash
bin/rails console
User.find_by(email: "your@email.com").update!(admin: true)
```

**Step 5: Commit any rubocop fixes, then finish**

```bash
git add -p
git commit -m "style: rubocop fixes for admin controllers"
```
