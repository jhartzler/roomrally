# Create Content Pack from Game Template Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let users create a new content pack directly from the game template form, with their in-progress template state preserved via sessionStorage and restored with the new pack auto-selected on return.

**Architecture:** "Create new pack" links appear below each pack dropdown, scoped to the selected game type. Clicking saves form data to `sessionStorage` and navigates to pack creation with a `return_to` param. After creating the pack, the controller redirects back with `?new_pack_id=X`; the Stimulus controller restores all form state and auto-selects the new pack. `CategoryPack` gets a full CRUD controller and views to fill the existing gap.

**Tech Stack:** Rails 8, Hotwire Stimulus, Tailwind CSS, RSpec request + system specs

**Design doc:** `docs/plans/2026-02-20-create-pack-from-template-design.md`

---

### Task 1: CategoryPacksController — routes, controller, request specs

**Files:**
- Create: `app/controllers/category_packs_controller.rb`
- Create: `spec/requests/category_packs_spec.rb`
- Modify: `config/routes.rb` — add `resources :category_packs`

**Step 1: Write the failing request spec**

```ruby
# spec/requests/category_packs_spec.rb
require 'rails_helper'

RSpec.describe "CategoryPacks", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe "GET /index" do
    it "returns http success" do
      get category_packs_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get new_category_pack_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /create" do
    let(:valid_attributes) do
      {
        name: "Animals Pack",
        game_type: "Category List",
        status: "draft",
        categories_attributes: [
          { name: "Mammals" },
          { name: "Birds" }
        ]
      }
    end

    it "creates a new CategoryPack with categories" do
      expect {
        post category_packs_path, params: { category_pack: valid_attributes }
      }.to change(CategoryPack, :count).by(1).and change(Category, :count).by(2)

      expect(response).to redirect_to(category_packs_path)
    end

    it "renders new on invalid params" do
      post category_packs_path, params: { category_pack: { name: "", game_type: "Category List" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /edit" do
    let(:category_pack) { create(:category_pack, user:) }

    it "returns http success" do
      get edit_category_pack_path(category_pack)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /update" do
    let(:category_pack) { create(:category_pack, user:) }

    it "updates and redirects" do
      patch category_pack_path(category_pack), params: { category_pack: { name: "Updated Name" } }
      expect(response).to redirect_to(category_packs_path)
    end
  end

  describe "DELETE /destroy" do
    let!(:category_pack) { create(:category_pack, user:) }

    it "destroys and redirects" do
      expect {
        delete category_pack_path(category_pack)
      }.to change(CategoryPack, :count).by(-1)
      expect(response).to redirect_to(category_packs_path)
    end
  end

  describe "authentication" do
    it "redirects unauthenticated users" do
      # Start a fresh session without signing in
      get category_packs_path, headers: { "Cookie" => "" }
      # Rails session-based auth redirects; assert not 200
      expect(response).not_to have_http_status(:success)
    end
  end
end
```

**Step 2: Run to confirm failure**

```bash
bin/rspec spec/requests/category_packs_spec.rb
```

Expected: Failures — `uninitialized constant CategoryPacksController` or routing error.

**Step 3: Add route**

In `config/routes.rb`, add after `resources :trivia_packs`:

```ruby
resources :category_packs
```

**Step 4: Create the controller**

```ruby
# app/controllers/category_packs_controller.rb
class CategoryPacksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_owned_category_pack, only: %i[show edit update destroy]

  def index
    @category_packs = current_user.category_packs.includes(:categories).recent
    @system_packs = CategoryPack.global.includes(:categories).alphabetical
  end

  def show
  end

  def new
    @category_pack = current_user.category_packs.new(game_type: "Category List")
    @category_pack.categories.build
    @return_to = params[:return_to]
  end

  def create
    @category_pack = current_user.category_packs.new(category_pack_params)

    if @category_pack.save
      if valid_return_to?(params[:return_to])
        redirect_to append_new_pack_id(params[:return_to], @category_pack.id),
                    notice: "Category pack created. Returning to your game."
      else
        redirect_to category_packs_path, notice: "Category pack created successfully."
      end
    else
      @return_to = params[:return_to]
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @return_to = params[:return_to]
  end

  def update
    if @category_pack.update(category_pack_params)
      redirect_to category_packs_path, notice: "Category pack updated successfully."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @category_pack.destroy
    redirect_to category_packs_path, notice: "Category pack deleted."
  end

  private

  def set_owned_category_pack
    @category_pack = current_user.category_packs.find(params[:id])
  end

  def category_pack_params
    params.require(:category_pack).permit(
      :name,
      :game_type,
      :status,
      categories_attributes: [ :id, :name, :_destroy ]
    )
  end
end
```

**Step 5: Run tests to confirm pass**

```bash
bin/rspec spec/requests/category_packs_spec.rb
```

Expected: all pass (views will render even without templates in request specs — if they fail on missing views, proceed to Task 2 first then rerun).

**Step 6: Commit**

```bash
git add config/routes.rb app/controllers/category_packs_controller.rb spec/requests/category_packs_spec.rb
git commit -m "feat: add CategoryPacksController with full CRUD and routes"
```

---

### Task 2: CategoryPack views

**Files:**
- Create: `app/views/category_packs/index.html.erb`
- Create: `app/views/category_packs/_card.html.erb`
- Create: `app/views/category_packs/show.html.erb`
- Create: `app/views/category_packs/new.html.erb`
- Create: `app/views/category_packs/edit.html.erb`
- Create: `app/views/category_packs/_form.html.erb`

**Step 1: Create the index view** (modeled on `app/views/prompt_packs/index.html.erb`)

```erb
<%# app/views/category_packs/index.html.erb %>
<div class="p-6 md:p-12 font-sans">
  <header class="max-w-5xl mx-auto mb-10 flex justify-between items-end">
    <div>
      <h1 class="text-4xl font-black text-white tracking-tighter drop-shadow-md">Category Library</h1>
      <p class="text-blue-200 font-medium">Your category pack library</p>
    </div>

    <div class="flex items-center gap-4">
      <%= link_to dashboard_path, class: "text-blue-200 hover:text-white font-bold text-sm flex items-center gap-2 px-4 py-2 rounded-lg hover:bg-white/5 transition-colors" do %>
        <%= lucide_icon('layout-dashboard', class: "w-4 h-4", "aria-hidden": true) %>
        Dashboard
      <% end %>

      <%= link_to new_category_pack_path, class: "inline-flex items-center gap-2 bg-orange-500 hover:bg-orange-600 text-white font-bold py-3 px-6 rounded-xl shadow-lg transition-all transform hover:scale-105 active:scale-95" do %>
        <%= lucide_icon('plus', class: "w-5 h-5", "aria-hidden": true) %>
        <span>New Pack</span>
      <% end %>
    </div>
  </header>

  <section class="max-w-5xl mx-auto mb-12">
    <h2 class="text-xl font-black text-white mb-6 flex items-center gap-2 tracking-wide">
      <%= lucide_icon('layout-template', class: "w-6 h-6 text-blue-200/50", "aria-hidden": true) %>
      Template Gallery
    </h2>
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      <% @system_packs.each do |pack| %>
        <%= render "card", pack: pack, variant: :system %>
      <% end %>
      <% if @system_packs.empty? %>
        <div class="col-span-full text-center py-8 text-blue-200/50 font-medium italic">
          No system templates available.
        </div>
      <% end %>
    </div>
  </section>

  <section class="max-w-5xl mx-auto">
    <h2 class="text-xl font-black text-white mb-6 flex items-center gap-2 tracking-wide">
      <%= lucide_icon('folder-open', class: "w-6 h-6 text-blue-200/50", "aria-hidden": true) %>
      My Packs
    </h2>

    <% if @category_packs.any? %>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <% @category_packs.each do |pack| %>
          <%= render "card", pack: pack, variant: :user %>
        <% end %>
      </div>
    <% else %>
      <div class="text-center py-20 bg-white/5 backdrop-blur-md rounded-3xl border-2 border-dashed border-white/10">
        <div class="mx-auto w-20 h-20 bg-white/5 rounded-full flex items-center justify-center text-blue-200/30 mb-6">
          <%= lucide_icon('folder-plus', class: "w-10 h-10", "aria-hidden": true) %>
        </div>
        <h3 class="text-2xl font-black text-white mb-2">No Category Packs Yet</h3>
        <p class="text-blue-200 font-medium mb-8 max-w-sm mx-auto">Create your first pack to start organizing your categories.</p>
        <%= link_to new_category_pack_path, class: "inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white font-black py-4 px-8 rounded-xl shadow-lg transition-all transform hover:scale-105 active:scale-95" do %>
          <%= lucide_icon('plus', class: "w-5 h-5", "aria-hidden": true) %>
          <span>Create Category Pack</span>
        <% end %>
      </div>
    <% end %>
  </section>
</div>
```

**Step 2: Create the card partial**

```erb
<%# app/views/category_packs/_card.html.erb %>
<%# locals: (pack:, variant: :user) %>
<% is_system = variant == :system %>
<% is_user = variant == :user %>

<div class="bg-white/10 backdrop-blur-md rounded-3xl <%= is_system ? 'p-6' : '' %> border border-white/20 hover:border-white/40 shadow-xl transition-all duration-300 relative overflow-hidden group flex flex-col h-full cursor-pointer">
  <div class="<%= is_system ? '' : 'p-6 flex-grow' %>">
    <div class="flex justify-between items-start mb-4">
      <div class="bg-white/5 p-3 rounded-2xl text-blue-200 group-hover:bg-blue-600 group-hover:text-white transition-colors duration-300 border border-white/10">
        <%= lucide_icon(is_system ? 'sparkles' : 'folder', class: is_system ? "w-6 h-6" : "w-8 h-8", "aria-hidden": true) %>
      </div>

      <% unless is_system %>
        <div class="flex items-center gap-2 px-3 py-1 rounded-full text-xs font-bold <%= pack.live? ? 'bg-green-500/20 text-green-300' : 'bg-white/5 text-blue-200' %> border border-white/10">
          <div class="w-2 h-2 rounded-full <%= pack.live? ? 'bg-green-400' : 'bg-blue-300/50' %> animate-pulse"></div>
          <%= pack.status.humanize %>
        </div>
      <% end %>
    </div>

    <div>
      <h3 class="<%= is_system ? 'text-lg' : 'text-xl' %> font-black text-white mb-1 <%= is_user ? 'truncate' : '' %> group-hover:text-blue-300 transition-colors">
        <%= link_to pack.name, category_pack_path(pack), class: "before:absolute before:inset-0 before:z-0" %>
      </h3>
      <p class="text-sm text-blue-200/70 <%= is_system ? 'mb-4' : 'mb-5' %> font-medium uppercase tracking-widest"><%= pack.game_type %></p>
    </div>

    <% if is_user %>
      <div class="text-sm text-blue-200/70 font-medium">
        <%= pluralize(pack.categories.size, "category") %>
      </div>
    <% end %>
  </div>

  <% if is_system %>
    <div class="mt-4 pt-4 border-t border-white/10 flex justify-between items-center">
      <span class="text-xs font-bold bg-white/5 text-blue-200 px-3 py-1 rounded-full uppercase tracking-widest border border-white/10">System Pack</span>
      <span class="text-sm font-bold text-blue-300 opacity-0 group-hover:opacity-100 transition-opacity">View Pack &rarr;</span>
    </div>
  <% else %>
    <div class="bg-white/5 p-4 border-t border-white/10 flex items-center justify-between gap-3 relative z-10 backdrop-blur-sm">
      <%= link_to "View", category_pack_path(pack), class: "flex-1 text-center py-2 rounded-lg bg-white/10 border border-white/20 text-white font-bold text-sm hover:bg-white/20 transition-all shadow-sm" %>
      <%= link_to "Edit", edit_category_pack_path(pack), class: "flex-1 text-center py-2 rounded-lg bg-blue-600 text-white font-black text-sm hover:bg-blue-700 transition-all shadow-lg active:scale-95" %>
    </div>
  <% end %>
</div>
```

**Step 3: Create show, new, edit views**

```erb
<%# app/views/category_packs/show.html.erb %>
<div class="p-6 md:p-12 font-sans">
  <div class="max-w-4xl mx-auto">
    <div class="flex items-center justify-between mb-8">
      <%= link_to category_packs_path, class: "group flex items-center gap-2 text-blue-200 hover:text-white transition-colors font-bold" do %>
        <div class="p-2 rounded-full bg-white/10 group-hover:bg-white/20 transition-colors border border-white/10">
          <%= lucide_icon('arrow-left', class: "w-5 h-5") %>
        </div>
        <span>Back to Library</span>
      <% end %>

      <% if @category_pack.user == current_user %>
        <%= link_to edit_category_pack_path(@category_pack), class: "inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-5 rounded-lg shadow-md transition-all" do %>
          <%= lucide_icon('edit-3', class: "w-4 h-4") %>
          <span>Edit Pack</span>
        <% end %>
      <% end %>
    </div>

    <div class="bg-white/10 backdrop-blur-md rounded-3xl shadow-2xl overflow-hidden border border-white/20">
      <div class="bg-white/5 p-8 border-b border-white/10">
        <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <div class="flex items-center gap-3 mb-2">
              <h1 class="text-3xl font-black text-white"><%= @category_pack.name %></h1>
              <% if @category_pack.user.nil? %>
                <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wide bg-blue-500/20 text-blue-200 border border-blue-400/30">System Pack</span>
              <% else %>
                <span class="inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-bold <%= @category_pack.live? ? 'bg-green-500/20 text-green-300' : 'bg-white/10 text-slate-300' %> border border-white/10">
                  <div class="w-2 h-2 rounded-full <%= @category_pack.live? ? 'bg-green-400 animate-pulse' : 'bg-slate-400' %>"></div>
                  <%= @category_pack.status.humanize %>
                </span>
              <% end %>
            </div>
            <p class="text-blue-200 font-medium text-lg"><%= @category_pack.game_type %></p>
          </div>
          <div class="bg-white/5 p-4 rounded-2xl shadow-lg border border-white/10 text-center min-w-[100px]">
            <span class="block text-3xl font-black text-white"><%= @category_pack.categories.count %></span>
            <span class="text-xs font-bold text-blue-300 uppercase tracking-widest">Categories</span>
          </div>
        </div>
      </div>

      <div class="p-8 bg-black/20">
        <h2 class="text-lg font-bold text-white mb-6 flex items-center gap-2 pb-4 border-b border-white/10 tracking-wide">
          <%= lucide_icon('list', class: "w-5 h-5 text-blue-300") %>
          Categories Included
        </h2>
        <% if @category_pack.categories.any? %>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <% @category_pack.categories.each do |category| %>
              <div class="p-4 rounded-xl bg-white/5 border border-white/10 text-blue-50 font-medium hover:bg-white/10 transition-colors flex items-center gap-3">
                <%= lucide_icon('tag', class: "w-4 h-4 text-blue-300 shrink-0") %>
                <%= category.name %>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-12 bg-white/5 rounded-2xl border-2 border-dashed border-white/10">
            <p class="text-blue-300/50 font-medium">This pack has no categories yet.</p>
          </div>
        <% end %>
      </div>
    </div>
  </div>
</div>
```

```erb
<%# app/views/category_packs/new.html.erb %>
<div class="p-6 md:p-12 font-sans">
  <div class="max-w-5xl mx-auto">
    <header class="mb-10">
      <%= link_to category_packs_path, class: "group flex items-center gap-2 text-blue-200 hover:text-white transition-colors font-bold mb-4 w-fit" do %>
        <div class="p-2 rounded-full bg-white/10 group-hover:bg-white/20 transition-colors border border-white/10">
          <%= lucide_icon('arrow-left', class: "w-5 h-5") %>
        </div>
        <span>Back to Library</span>
      <% end %>
      <h1 class="text-4xl font-black text-white mb-2 tracking-tighter drop-shadow-md">New Category Pack</h1>
      <p class="text-blue-200 font-medium">Create a new category pack for A-List games</p>
    </header>
    <%= render "form", category_pack: @category_pack, return_to: @return_to %>
  </div>
</div>
```

```erb
<%# app/views/category_packs/edit.html.erb %>
<div class="p-6 md:p-12 font-sans">
  <div class="max-w-5xl mx-auto">
    <header class="mb-10">
      <%= link_to category_packs_path, class: "group flex items-center gap-2 text-blue-200 hover:text-white transition-colors font-bold mb-4 w-fit" do %>
        <div class="p-2 rounded-full bg-white/10 group-hover:bg-white/20 transition-colors border border-white/10">
          <%= lucide_icon('arrow-left', class: "w-5 h-5") %>
        </div>
        <span>Back to Library</span>
      <% end %>
      <h1 class="text-4xl font-black text-white mb-2 tracking-tighter drop-shadow-md">Edit Category Pack</h1>
    </header>
    <%= render "form", category_pack: @category_pack, return_to: @return_to %>
  </div>
</div>
```

**Step 4: Create the form partial**

This uses a new `category-editor` Stimulus controller (built in Task 3).

```erb
<%# app/views/category_packs/_form.html.erb %>
<%# locals: (category_pack:, return_to: nil) %>
<%= form_with(model: category_pack, class: "contents", data: { controller: "category-editor" }) do |form| %>
  <% if category_pack.errors.any? %>
    <div class="bg-red-500/20 text-red-200 px-6 py-4 font-medium rounded-2xl mb-8 border border-red-500/30 backdrop-blur-md">
      <h2 class="font-bold mb-2"><%= pluralize(category_pack.errors.count, "error") %> prohibited this pack from being saved:</h2>
      <ul class="list-disc list-inside text-sm">
        <% category_pack.errors.each do |error| %>
          <li><%= error.full_message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <%= hidden_field_tag :return_to, return_to if return_to.present? %>

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
            <%= form.label :game_type, class: "block text-sm font-bold text-blue-200 mb-2 uppercase tracking-widest" %>
            <%= form.select :game_type, Room::GAME_TYPES, {}, class: "block w-full rounded-xl bg-white/5 border-2 border-white/10 shadow-sm focus:border-orange-500 focus:ring focus:ring-orange-500/20 transition-all font-medium py-3 px-4 text-white [&>option]:text-gray-900" %>
          </div>

          <div>
            <%= form.label :status, class: "block text-sm font-bold text-blue-200 mb-2 uppercase tracking-widest" %>
            <%= form.select :status, CategoryPack.statuses.keys.map { |k| [k.humanize, k] }, {}, class: "block w-full rounded-xl bg-white/5 border-2 border-white/10 shadow-sm focus:border-orange-500 focus:ring focus:ring-orange-500/20 transition-all font-medium py-3 px-4 text-white [&>option]:text-gray-900" %>
          </div>
        </div>
      </div>

      <div class="pt-2">
        <%= form.submit "Save Pack", class: "w-full rounded-xl py-4 px-6 bg-orange-500 hover:bg-orange-600 text-white block font-black text-lg shadow-lg shadow-orange-900/20 transition-all cursor-pointer transform hover:scale-[1.02] active:scale-95" %>
        <%= link_to "Cancel", category_packs_path, class: "block w-full text-center mt-4 text-blue-200/50 hover:text-white font-bold text-sm transition-colors" %>
      </div>
    </div>

    <!-- Right Column: Categories -->
    <div class="bg-white/10 backdrop-blur-md rounded-3xl p-8 shadow-xl border border-white/20 h-fit">
      <div class="flex justify-between items-center mb-6">
        <h3 class="text-xl font-black text-white tracking-wide">Categories</h3>
        <button type="button" data-action="category-editor#addCategory" class="text-sm text-white font-bold bg-white/10 hover:bg-white/20 px-3 py-1.5 rounded-lg transition-colors flex items-center gap-1.5 border border-white/10">
          <%= lucide_icon('plus', class: "w-4 h-4", "aria-hidden": true) %>
          Add Category
        </button>
      </div>

      <!-- Bulk Import -->
      <details class="mb-6 bg-white/5 rounded-xl border border-white/10 group overflow-hidden" data-category-editor-target="bulkSection">
        <summary class="list-none flex justify-between items-center p-4 cursor-pointer hover:bg-white/10 transition-colors">
          <span class="font-bold text-blue-200 flex items-center gap-2">
            <%= lucide_icon('file-plus', class: "w-4 h-4", "aria-hidden": true) %>
            Bulk Import
          </span>
          <%= lucide_icon('chevron-down', class: "w-4 h-4 text-blue-300 group-open:rotate-180 transition-transform", "aria-hidden": true) %>
        </summary>
        <div class="p-4 border-t border-white/10">
          <p class="text-xs text-blue-200/70 mb-3 font-medium">Paste your categories below, one per line.</p>
          <textarea data-category-editor-target="bulkText" rows="6" class="block w-full rounded-xl bg-white/5 border-2 border-white/10 focus:border-orange-500 focus:ring focus:ring-orange-500/20 text-sm font-medium text-white placeholder-white/20 resize-y mb-3 p-3" placeholder="Mammals&#10;Birds&#10;Reptiles" aria-label="Bulk categories input"></textarea>
          <button type="button" data-action="category-editor#bulkAdd" class="w-full py-2 bg-blue-600 hover:bg-blue-700 text-white font-bold rounded-lg text-sm shadow-md transition-all active:scale-95">
            Import Categories
          </button>
        </div>
      </details>

      <div data-category-editor-target="categoryList" class="space-y-3">
        <%= form.fields_for :categories do |cat_form| %>
          <div class="category-field-wrapper flex gap-3 items-center group" data-new-record="<%= cat_form.object.new_record? %>">
            <%= cat_form.text_field :name,
              class: "block w-full rounded-xl bg-white/5 border-2 border-white/10 focus:border-orange-500 focus:ring focus:ring-orange-500/20 text-sm font-medium text-white placeholder-white/20 transition-all px-4 py-3",
              data: { category_editor_target: "categoryField" },
              placeholder: "Category name..." %>
            <%= cat_form.hidden_field :_destroy %>
            <button type="button" data-action="category-editor#removeCategory" class="text-white/20 hover:text-red-400 p-1 opacity-0 group-hover:opacity-100 transition-all transform hover:scale-110 shrink-0" aria-label="Remove category">
              <%= lucide_icon('trash-2', class: "w-5 h-5", "aria-hidden": true) %>
            </button>
          </div>
        <% end %>
      </div>
    </div>
  </div>

  <!-- Hidden Template for New Category Fields -->
  <template data-category-editor-target="categoryTemplate">
    <div class="category-field-wrapper flex gap-3 items-center group" data-new-record="true">
      <input type="text"
             name="category_pack[categories_attributes][NEW_RECORD][name]"
             data-category-editor-target="categoryField"
             placeholder="Category name..."
             class="block w-full rounded-xl bg-white/5 border-2 border-white/10 focus:border-orange-500 focus:ring focus:ring-orange-500/20 text-sm font-medium text-white placeholder-white/20 transition-all px-4 py-3">
      <input type="hidden" name="category_pack[categories_attributes][NEW_RECORD][_destroy]" value="false">
      <button type="button" data-action="category-editor#removeCategory" class="text-white/20 hover:text-red-400 p-1 opacity-0 group-hover:opacity-100 transition-all transform hover:scale-110 shrink-0" aria-label="Remove category">
        <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/></svg>
      </button>
    </div>
  </template>
<% end %>
```

**Step 5: Run request specs**

```bash
bin/rspec spec/requests/category_packs_spec.rb
```

Expected: all pass.

**Step 6: Commit**

```bash
git add app/views/category_packs/
git commit -m "feat: add CategoryPack views (index, show, new, edit, form, card)"
```

---

### Task 3: category-editor Stimulus controller

**Files:**
- Create: `app/javascript/controllers/category_editor_controller.js`

**Step 1: Create the controller**

```javascript
// app/javascript/controllers/category_editor_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["categoryList", "categoryTemplate", "categoryField", "bulkText", "bulkSection"]

  addCategory(event) {
    event.preventDefault()
    this.createCategoryField("")
  }

  bulkAdd(event) {
    event.preventDefault()
    const text = this.bulkTextTarget.value
    if (!text.trim()) return

    const lines = text.split(/\r?\n/).map(line => line.trim()).filter(line => line.length > 0)
    lines.forEach(line => this.createCategoryField(line))

    this.bulkTextTarget.value = ""
    this.bulkSectionTarget.open = false
  }

  createCategoryField(value) {
    const timestamp = new Date().getTime() + Math.floor(Math.random() * 1000)
    const content = this.categoryTemplateTarget.innerHTML.replace(/NEW_RECORD/g, timestamp)

    this.categoryListTarget.insertAdjacentHTML('afterbegin', content)

    const newField = this.categoryListTarget.firstElementChild.querySelector("input[type=text]")
    if (newField) {
      newField.value = value
    }
  }

  removeCategory(event) {
    event.preventDefault()
    const wrapper = event.target.closest(".category-field-wrapper")

    if (wrapper.dataset.newRecord === "true") {
      wrapper.remove()
    } else {
      wrapper.style.display = "none"
      wrapper.querySelector("input[name*='_destroy']").value = "1"
    }
  }
}
```

**Step 2: Register the controller**

Open `app/javascript/controllers/index.js` and check if controllers are auto-registered (they should be via `import { application } from "./application"` + `eagerLoadControllersFrom`). If using the standard Rails Stimulus setup, placing the file in the controllers directory is sufficient — no manual registration needed.

Verify by checking the file:

```bash
grep -n "eagerLoad\|registerControllersFrom\|autoload" app/javascript/controllers/index.js
```

If the file uses `eagerLoadControllersFrom` or similar, no changes needed. If it manually imports controllers, add:

```javascript
import CategoryEditorController from "./category_editor_controller"
application.register("category-editor", CategoryEditorController)
```

**Step 3: Verify with a quick smoke test** (navigate to `/category_packs/new` in browser and check "Add Category" works — or trust the system spec in Task 7)

**Step 4: Commit**

```bash
git add app/javascript/controllers/category_editor_controller.js
git commit -m "feat: add category-editor Stimulus controller for category pack form"
```

---

### Task 4: return_to support — ApplicationController + pack controller updates + request specs

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Modify: `app/controllers/prompt_packs_controller.rb`
- Modify: `app/controllers/trivia_packs_controller.rb`
- Modify: `app/views/prompt_packs/_form.html.erb`
- Modify: `app/views/trivia_packs/_form.html.erb`
- Modify: `spec/requests/prompt_packs_spec.rb`
- Modify: `spec/requests/trivia_packs_spec.rb` (or check if it exists — add similar tests)

**Step 1: Write the failing return_to tests in prompt_packs_spec.rb**

Add inside the `describe "POST /create"` block in `spec/requests/prompt_packs_spec.rb`:

```ruby
context "with a valid return_to param" do
  it "redirects back with new_pack_id appended" do
    post prompt_packs_path,
      params: { prompt_pack: valid_attributes, return_to: "/game_templates/new" }
    expect(response).to redirect_to(%r{/game_templates/new\?.*new_pack_id=\d+})
  end
end

context "with an external return_to param" do
  it "falls back to packs index (no open redirect)" do
    post prompt_packs_path,
      params: { prompt_pack: valid_attributes, return_to: "https://evil.com" }
    expect(response).to redirect_to(prompt_packs_path)
  end
end

context "with a protocol-relative return_to param" do
  it "falls back to packs index (no open redirect)" do
    post prompt_packs_path,
      params: { prompt_pack: valid_attributes, return_to: "//evil.com/path" }
    expect(response).to redirect_to(prompt_packs_path)
  end
end
```

**Step 2: Run to confirm failure**

```bash
bin/rspec spec/requests/prompt_packs_spec.rb --format documentation
```

Expected: new redirect tests fail.

**Step 3: Add `valid_return_to?` and `append_new_pack_id` to ApplicationController**

Open `app/controllers/application_controller.rb` and add:

```ruby
private

def valid_return_to?(url)
  return false if url.blank?
  uri = URI.parse(url)
  !uri.host && uri.path.start_with?("/")
rescue URI::InvalidURIError
  false
end

def append_new_pack_id(return_to_url, pack_id)
  uri = URI.parse(return_to_url)
  existing = URI.decode_www_form(uri.query || "")
  existing << ["new_pack_id", pack_id.to_s]
  uri.query = URI.encode_www_form(existing)
  uri.to_s
end
```

**Step 4: Update PromptPacksController**

In `app/controllers/prompt_packs_controller.rb`:

Change `new` to:
```ruby
def new
  @prompt_pack = current_user.prompt_packs.new(game_type: "Write And Vote")
  @prompt_pack.prompts.build
  @return_to = params[:return_to]
end
```

Change `create` success redirect from:
```ruby
redirect_to prompt_packs_path, notice: "Prompt pack created successfully."
```
to:
```ruby
if valid_return_to?(params[:return_to])
  redirect_to append_new_pack_id(params[:return_to], @prompt_pack.id),
              notice: "Prompt pack created. Returning to your game."
else
  redirect_to prompt_packs_path, notice: "Prompt pack created successfully."
end
```

Also add `@return_to = params[:return_to]` to the `create` failure path before `render :new`.

**Step 5: Add hidden return_to field to prompt_packs form**

In `app/views/prompt_packs/_form.html.erb`, add immediately after the `form_with` opening tag (before the errors block):

```erb
<%= hidden_field_tag :return_to, @return_to if @return_to.present? %>
```

**Step 6: Run prompt_packs request specs**

```bash
bin/rspec spec/requests/prompt_packs_spec.rb
```

Expected: all pass including new return_to tests.

**Step 7: Repeat for TriviaPacksController**

Check if `spec/requests/trivia_packs_spec.rb` exists:
```bash
ls spec/requests/trivia_packs_spec.rb
```

If it exists, add the same three `return_to` tests to the `POST /create` describe block. If not, create it with the same structure as `prompt_packs_spec.rb`.

Apply the same controller changes to `app/controllers/trivia_packs_controller.rb`:
- `new`: add `@return_to = params[:return_to]`
- `create` success: replace redirect with return_to logic using `@trivia_pack.id`
- `create` failure: add `@return_to = params[:return_to]`

Add hidden field to `app/views/trivia_packs/_form.html.erb`:
```erb
<%= hidden_field_tag :return_to, @return_to if @return_to.present? %>
```

**Step 8: Note about CategoryPacksController**

CategoryPacksController already includes return_to support from Task 1. The `valid_return_to?` and `append_new_pack_id` helpers are now in ApplicationController so they're available.

**Step 9: Run all pack request specs**

```bash
bin/rspec spec/requests/prompt_packs_spec.rb spec/requests/trivia_packs_spec.rb spec/requests/category_packs_spec.rb
```

Expected: all pass.

**Step 10: Commit**

```bash
git add app/controllers/application_controller.rb \
        app/controllers/prompt_packs_controller.rb \
        app/controllers/trivia_packs_controller.rb \
        app/views/prompt_packs/_form.html.erb \
        app/views/trivia_packs/_form.html.erb \
        spec/requests/prompt_packs_spec.rb \
        spec/requests/trivia_packs_spec.rb
git commit -m "feat: add return_to redirect support to all pack controllers with open redirect protection"
```

---

### Task 5: Game template form — "Create new pack" links

**Files:**
- Modify: `app/views/game_templates/_form.html.erb`

**Step 1: Add "Create new pack" links below each pack dropdown**

The links must be:
1. Shown/hidden in sync with the pack dropdowns (same `data-game-template-form-target` and `data-pack-type` attributes)
2. Have a `data-action` to save form state before navigating
3. Include `?return_to=<current_url>` as a query param — computed in ERB using `request.fullpath`

Find the Content Pack section in `app/views/game_templates/_form.html.erb` (lines 39–64). After each `<div data-game-template-form-target="packSelect" ...>`, add a sibling link div.

Replace the entire Content Pack section:

```erb
<%# Pack Selector %>
<div>
  <label class="block text-sm font-bold text-blue-200 mb-2">Content Pack</label>
  <p class="text-xs text-blue-300/70 mb-3">Leave blank to use the default pack for this game type.</p>

  <div data-game-template-form-target="packSelect" data-pack-type="prompt_pack" class="<%= 'hidden' unless game_template.game_type == Room::WRITE_AND_VOTE %>">
    <%= f.select :prompt_pack_id,
      options_for_select(@prompt_packs.map { |p| [p.name, p.id] }, game_template.prompt_pack_id),
      { include_blank: "(default prompts)" },
      class: "w-full bg-white/10 border border-white/20 rounded-xl px-4 py-3 text-white focus:outline-none focus:ring-2 focus:ring-blue-500" %>
    <div class="mt-2">
      <%= link_to new_prompt_pack_path(return_to: request.fullpath),
        class: "text-sm text-blue-300 hover:text-white font-bold flex items-center gap-1.5 transition-colors w-fit",
        data: { action: "click->game-template-form#saveAndNavigate" } do %>
        <%= lucide_icon('plus-circle', class: "w-4 h-4", "aria-hidden": true) %>
        Create a new prompt pack
      <% end %>
    </div>
  </div>

  <div data-game-template-form-target="packSelect" data-pack-type="trivia_pack" class="<%= 'hidden' unless game_template.game_type == Room::SPEED_TRIVIA %>">
    <%= f.select :trivia_pack_id,
      options_for_select(@trivia_packs.map { |p| [p.name, p.id] }, game_template.trivia_pack_id),
      { include_blank: "(default trivia)" },
      class: "w-full bg-white/10 border border-white/20 rounded-xl px-4 py-3 text-white focus:outline-none focus:ring-2 focus:ring-blue-500" %>
    <div class="mt-2">
      <%= link_to new_trivia_pack_path(return_to: request.fullpath),
        class: "text-sm text-blue-300 hover:text-white font-bold flex items-center gap-1.5 transition-colors w-fit",
        data: { action: "click->game-template-form#saveAndNavigate" } do %>
        <%= lucide_icon('plus-circle', class: "w-4 h-4", "aria-hidden": true) %>
        Create a new trivia pack
      <% end %>
    </div>
  </div>

  <div data-game-template-form-target="packSelect" data-pack-type="category_pack" class="<%= 'hidden' unless game_template.game_type == Room::CATEGORY_LIST %>">
    <%= f.select :category_pack_id,
      options_for_select(@category_packs.map { |p| [p.name, p.id] }, game_template.category_pack_id),
      { include_blank: "(default categories)" },
      class: "w-full bg-white/10 border border-white/20 rounded-xl px-4 py-3 text-white focus:outline-none focus:ring-2 focus:ring-blue-500" %>
    <div class="mt-2">
      <%= link_to new_category_pack_path(return_to: request.fullpath),
        class: "text-sm text-blue-300 hover:text-white font-bold flex items-center gap-1.5 transition-colors w-fit",
        data: { action: "click->game-template-form#saveAndNavigate" } do %>
        <%= lucide_icon('plus-circle', class: "w-4 h-4", "aria-hidden": true) %>
        Create a new category pack
      <% end %>
    </div>
  </div>
</div>
```

**Step 2: Commit**

```bash
git add app/views/game_templates/_form.html.erb
git commit -m "feat: add 'Create new pack' links to game template form"
```

---

### Task 6: game-template-form Stimulus controller — saveAndNavigate + restore

**Files:**
- Modify: `app/javascript/controllers/game_template_form_controller.js`

**Step 1: Extend the controller**

Replace the entire content of `app/javascript/controllers/game_template_form_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["packSelect", "settingsGroup"]

  connect() {
    this.restoreFromSession()
  }

  gameTypeChanged(event) {
    const selectedType = event.target.value
    const packTypeMap = {
      "Write And Vote": "prompt_pack",
      "Speed Trivia": "trivia_pack",
      "Category List": "category_pack"
    }

    this.packSelectTargets.forEach(el => {
      el.classList.toggle("hidden", el.dataset.packType !== packTypeMap[selectedType])
    })

    this.settingsGroupTargets.forEach(el => {
      el.classList.toggle("hidden", el.dataset.gameType !== selectedType)
    })
  }

  saveAndNavigate(event) {
    // Serialize form data to sessionStorage, then let the link navigate naturally
    const form = this.element.closest("form") || this.element.querySelector("form")
    if (!form) return

    const data = {}
    new FormData(form).forEach((value, key) => {
      // Store only non-file fields
      if (typeof value === "string") {
        data[key] = value
      }
    })

    sessionStorage.setItem(this.storageKey(), JSON.stringify(data))
    // Allow the link's natural navigation to proceed (no preventDefault)
  }

  restoreFromSession() {
    const urlParams = new URLSearchParams(window.location.search)
    const newPackId = urlParams.get("new_pack_id")
    const savedData = sessionStorage.getItem(this.storageKey())

    if (!savedData) return

    const data = JSON.parse(savedData)
    this.applyFormData(data)

    if (newPackId) {
      this.selectNewPack(newPackId)
      sessionStorage.removeItem(this.storageKey())
      // Clean the URL param without reloading
      const cleanUrl = window.location.pathname
      window.history.replaceState({}, "", cleanUrl)
    }
  }

  // --- Private helpers ---

  storageKey() {
    return `game_template_draft_${window.location.pathname}`
  }

  applyFormData(data) {
    const form = this.element.closest("form") || this.element.querySelector("form")
    if (!form) return

    Object.entries(data).forEach(([key, value]) => {
      // Handle radio buttons (game_type)
      const radio = form.querySelector(`input[type=radio][name="${key}"][value="${value}"]`)
      if (radio) {
        radio.checked = true
        radio.dispatchEvent(new Event("change", { bubbles: true }))
        return
      }

      // Handle checkboxes
      const checkbox = form.querySelector(`input[type=checkbox][name="${key}"]`)
      if (checkbox) {
        checkbox.checked = (value === "true" || value === "1")
        return
      }

      // Handle selects and text inputs
      const field = form.querySelector(`[name="${key}"]:not([type=radio]):not([type=checkbox])`)
      if (field) {
        field.value = value
      }
    })
  }

  selectNewPack(packId) {
    // Find the visible pack select and choose the new pack
    const visibleSelect = this.packSelectTargets
      .find(el => !el.classList.contains("hidden"))
      ?.querySelector("select")

    if (visibleSelect) {
      const option = Array.from(visibleSelect.options).find(o => o.value === packId)
      if (option) {
        visibleSelect.value = packId
      }
    }
  }
}
```

**Key notes on the implementation:**
- `storageKey()` scopes to the URL path, so `/game_templates/new` and `/game_templates/5/edit` have separate drafts
- `saveAndNavigate` does NOT call `event.preventDefault()` — it saves state but allows the link to navigate naturally
- `applyFormData` dispatches a change event on the radio button to trigger `gameTypeChanged`, which shows the correct pack dropdown before `selectNewPack` runs
- `selectNewPack` runs after `applyFormData` (synchronously), so the correct pack dropdown is already visible

**Step 2: Verify the controller handles the form element correctly**

The `_form.html.erb` uses `<%= form_with(model: game_template, ...) do |f| %>`. The Stimulus controller is attached to the form element (check `app/views/game_templates/new.html.erb` and `edit.html.erb`):

Open `app/views/game_templates/new.html.erb` — the form partial is rendered inside a wrapper div. The controller needs to be on an element that wraps the form. Check if there's a `data-controller="game-template-form"` on a parent div.

If the controller is not on the `<form>` element itself, change `this.element.closest("form")` fallback to just `this.element.querySelector("form")` or attach the Stimulus controller directly to the form element in `_form.html.erb`.

Look at the current attachment in `_form.html.erb` line 1 — the form already has `class="space-y-8"` but no `data-controller`. The radio buttons have `data: { action: "change->game-template-form#gameTypeChanged" }`, which means the controller must be on an ancestor element.

Check the wrapper views:
- `app/views/game_templates/new.html.erb`
- `app/views/game_templates/edit.html.erb`

If there's a parent div with `data-controller="game-template-form"`, `this.element.closest("form")` should work fine since the form is a descendant.

If not found, add `data: { controller: "game-template-form" }` to the `form_with` call in `_form.html.erb` (on line 1 after the `class:` attribute), and change the form find logic to `this.element` (the Stimulus element IS the form).

**Step 3: Commit**

```bash
git add app/javascript/controllers/game_template_form_controller.js
git commit -m "feat: add sessionStorage save/restore to game-template-form Stimulus controller"
```

---

### Task 7: System spec — full round-trip

**Files:**
- Create: `spec/system/game_templates/create_pack_from_template_spec.rb`

**Step 1: Write the system spec**

```ruby
# spec/system/game_templates/create_pack_from_template_spec.rb
require 'rails_helper'

RSpec.describe "Create pack from template form", type: :system do
  let(:user) { create(:user) }

  before do
    driven_by(:selenium_chrome_headless)
    sign_in(user)
  end

  it "saves template state and returns with new trivia pack selected" do
    visit new_game_template_path

    # Fill in partial template state
    fill_in "Game Name", with: "Friday Trivia Night"

    # Select Speed Trivia game type
    choose "Speed Trivia"

    # Verify the trivia pack section is visible and the "Create" link appears
    expect(page).to have_text("Create a new trivia pack")

    # Click the link — should navigate to trivia pack creation
    click_link "Create a new trivia pack"

    expect(page).to have_current_path(%r{/trivia_packs/new})
    expect(page).to have_content("Create Trivia Pack")

    # Create a trivia pack
    fill_in "Name", with: "My Custom Quiz"
    click_button "Save Pack"

    # Should redirect back to the game template form
    expect(page).to have_current_path(%r{/game_templates/new})

    # Template name should be restored
    expect(find_field("Game Name").value).to eq("Friday Trivia Night")

    # Speed Trivia should still be selected
    expect(find("input[type=radio][value='Speed Trivia']")).to be_checked

    # New pack should be auto-selected in the trivia pack dropdown
    expect(page).to have_select(find("select[name='game_template[trivia_pack_id]']")[:id],
                                 selected: "My Custom Quiz")
  end
end
```

**Note on the select assertion:** Capybara's `have_select` matcher takes the label text or field id. Since the select doesn't have an explicit label, use the element directly:

```ruby
trivia_select = find("select[name='game_template[trivia_pack_id]']")
expect(trivia_select.value).to eq(TriviaPack.last.id.to_s)
```

**Step 2: Run the system spec**

```bash
bin/rspec spec/system/game_templates/create_pack_from_template_spec.rb
```

Work through any failures. Common issues:
- Stimulus controller not finding the form (see Task 6 Step 2 note)
- `return_to` URL in the link not matching (the `request.fullpath` in the link generates `/game_templates/new`, but after restoring, `window.location.pathname` is used as the storage key — confirm these match)
- The `Save Pack` button on the trivia pack form requires at least one trivia question — the trivia pack form may have validation requiring questions. If so, add a question before saving.

**Step 3: Run full test suite**

```bash
bin/rspec spec/requests/ spec/system/game_templates/
```

Expected: all pass.

**Step 4: Final commit**

```bash
git add spec/system/game_templates/
git commit -m "test: add system spec for create-pack-from-template round-trip flow"
```

---

## Summary of Changes

| Task | Files Changed | Type |
|------|--------------|------|
| 1 | `config/routes.rb`, `category_packs_controller.rb`, `spec/requests/category_packs_spec.rb` | New controller + routes |
| 2 | `app/views/category_packs/**` (6 files) | New views |
| 3 | `app/javascript/controllers/category_editor_controller.js` | New Stimulus controller |
| 4 | `application_controller.rb`, `prompt_packs_controller.rb`, `trivia_packs_controller.rb`, 2 form partials, 2 request specs | return_to support |
| 5 | `app/views/game_templates/_form.html.erb` | Form UI |
| 6 | `app/javascript/controllers/game_template_form_controller.js` | Stimulus controller |
| 7 | `spec/system/game_templates/create_pack_from_template_spec.rb` | System spec |
