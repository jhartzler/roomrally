# Customize-First: Landing Page & Dashboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Pivot the landing page's primary feature section from moderation to game customization, add a Google login callout for customization, and update the dashboard to lead with game template creation rather than content pack management.

**Architecture:** Pure view changes — no controllers, models, routes, or jobs need modification. Three files change: `app/views/pages/landing.html.erb`, `app/views/dashboard/index.html.erb`, and `app/views/home/index.html.erb`. No tests cover landing page copy specifically; run the full suite after each task to ensure no regressions.

**Tech Stack:** ERB, Tailwind CSS, Hotwire/Turbo, Lucide icons, Rails route helpers

---

## Setup: Create Worktree

Before starting, create an isolated worktree:

```bash
# From the project root
git worktree add .claude/worktrees/customize-first -b feature/customize-first
cd .claude/worktrees/customize-first
RAILS_ENV=test bin/rails tailwindcss:build
```

All subsequent work happens inside the worktree.

---

### Task 1: Landing page — insert new primary feature section

**Files:**
- Modify: `app/views/pages/landing.html.erb` (currently lines 35–65, the Backstage Advantage section)

The new "Games Built for Your Group" section replaces the Backstage Advantage section **in position** (Backstage moves below it in Task 2). Insert the new section immediately before the existing Backstage section.

**Step 1: Open the file and locate the insertion point**

Find the line:
```erb
  <%# Section 2: The Main Feature (Safety & Control) %>
```

**Step 2: Insert the new section above it**

```erb
  <%# Section 2: Customize Your Game (primary feature) %>
  <section class="bg-white/10 backdrop-blur-md rounded-3xl shadow-2xl p-10 md:p-16 border border-white/20 mb-16 md:mb-24">
    <h2 class="text-3xl md:text-4xl font-bold text-white mb-6">Games Built for Your Group</h2>
    <p class="text-blue-100 text-lg leading-relaxed mb-8 max-w-3xl">
      Pick a game mode, add your own questions or prompts, and save it as a template for your next event — birthday party, bible study, team meeting. RoomRally remembers your setup so you can launch in seconds.
    </p>

    <div class="grid md:grid-cols-3 gap-8 mt-10">
      <div class="bg-white/5 rounded-2xl p-6 border border-white/10">
        <div class="text-4xl mb-4">🎮</div>
        <h3 class="text-xl font-bold text-white mb-3">Game Templates</h3>
        <p class="text-blue-200">
          Save a game configuration — type, content pack, settings — and reuse it with one click.
        </p>
      </div>
      <div class="bg-white/5 rounded-2xl p-6 border border-white/10">
        <div class="text-4xl mb-4">✍️</div>
        <h3 class="text-xl font-bold text-white mb-3">Custom Prompts</h3>
        <p class="text-blue-200">
          Write Comedy Clash prompts tuned to your group's sense of humor.
        </p>
      </div>
      <div class="bg-white/5 rounded-2xl p-6 border border-white/10">
        <div class="text-4xl mb-4">🧠</div>
        <h3 class="text-xl font-bold text-white mb-3">Custom Trivia</h3>
        <p class="text-blue-200">
          Add questions about topics your group actually cares about.
        </p>
      </div>
    </div>
  </section>

```

**Step 3: Run the test suite**

```bash
bin/rspec spec/system
```

Expected: all passing (no system spec covers landing page copy).

**Step 4: Commit**

```bash
git add app/views/pages/landing.html.erb
git commit -m "feat: add customize-first primary feature section to landing page"
```

---

### Task 2: Landing page — demote the Backstage Advantage section

**Files:**
- Modify: `app/views/pages/landing.html.erb` (the existing Backstage section, now Section 3)

**Step 1: Update the section heading**

Find:
```erb
    <h2 class="text-3xl md:text-4xl font-bold text-white mb-6">The "Backstage" Advantage</h2>
    <p class="text-blue-100 text-lg leading-relaxed mb-8 max-w-3xl">
      Most party games put player answers directly on the big screen. RoomRally gives you a Host Dashboard. You see every submission first. You decide what is funny enough to show, and what needs to be skipped.
    </p>
```

Replace with:
```erb
    <h2 class="text-3xl md:text-4xl font-bold text-white mb-6">Plus, you stay in control</h2>
    <p class="text-blue-100 text-lg leading-relaxed mb-8 max-w-3xl">
      RoomRally gives you a Host Dashboard — you see every player submission before it hits the big screen. Approve the best ones, skip the rest.
    </p>
```

**Step 2: Run the test suite**

```bash
bin/rspec spec/system
```

Expected: all passing.

**Step 3: Commit**

```bash
git add app/views/pages/landing.html.erb
git commit -m "feat: demote backstage section to secondary feature on landing page"
```

---

### Task 3: Landing page — update "How It Works" step 3

**Files:**
- Modify: `app/views/pages/landing.html.erb` (the How It Works section, step 3)

**Step 1: Find the Curate step**

Find:
```erb
      <div class="flex gap-6 items-start">
        <div class="flex-shrink-0 w-12 h-12 bg-orange-500 rounded-full flex items-center justify-center text-white font-black text-xl">
          3
        </div>
        <div>
          <h3 class="text-2xl font-bold text-white mb-2">Curate</h3>
          <p class="text-blue-200 text-lg">
            As answers come in, you approve the best ones from your device to keep the room laughing.
          </p>
        </div>
      </div>
```

Replace with:
```erb
      <div class="flex gap-6 items-start">
        <div class="flex-shrink-0 w-12 h-12 bg-orange-500 rounded-full flex items-center justify-center text-white font-black text-xl">
          3
        </div>
        <div>
          <h3 class="text-2xl font-bold text-white mb-2">Customize</h3>
          <p class="text-blue-200 text-lg">
            Before your event, build a game template with your own questions or prompts. Launch it in seconds when the room is ready.
          </p>
        </div>
      </div>
```

**Step 2: Run the test suite**

```bash
bin/rspec spec/system
```

Expected: all passing.

**Step 3: Commit**

```bash
git add app/views/pages/landing.html.erb
git commit -m "feat: update How It Works step 3 from Curate to Customize"
```

---

### Task 4: Landing page — add Google login callout section

**Files:**
- Modify: `app/views/pages/landing.html.erb` (insert between "How It Works" and footer CTA)

This section only renders for logged-out users.

**Step 1: Find the insertion point**

Find the footer CTA section comment:
```erb
  <%# Section 4: Footer / Call to Action %>
```

**Step 2: Insert the login callout immediately above it**

```erb
  <%# Section 5: Login to Customize callout (logged-out only) %>
  <% unless current_user %>
    <section class="text-center py-10 md:py-12 px-8 bg-white/5 rounded-3xl border border-white/10 mb-16 md:mb-24">
      <h2 class="text-2xl md:text-3xl font-bold text-white mb-3">Ready to make it yours?</h2>
      <p class="text-blue-200 text-lg mb-8">
        Sign in with Google to save game templates and create custom content — free.
      </p>
      <%= form_with url: "/auth/google_oauth2", method: :post, data: { turbo: false }, class: "inline-block" do |f| %>
        <%= f.submit "Sign in with Google", class: "bg-orange-500 text-white font-black py-4 px-12 rounded-full hover:bg-orange-600 active:scale-95 transform hover:shadow-2xl shadow-orange-900/40 transition-all duration-200 text-xl cursor-pointer" %>
      <% end %>
    </section>
  <% end %>

```

Also update the existing footer section comment (cosmetic only, optional):
```erb
  <%# Section 6: Footer / Call to Action %>
```

**Step 3: Run the test suite**

```bash
bin/rspec spec/system
```

Expected: all passing.

**Step 4: Commit**

```bash
git add app/views/pages/landing.html.erb
git commit -m "feat: add Google login callout section to landing page for logged-out users"
```

---

### Task 5: Dashboard — update "Customize Games" card

**Files:**
- Modify: `app/views/dashboard/index.html.erb` (the Customize Games card, lines 99–112)

**Step 1: Find the Customize Games card**

Find:
```erb
    <div class="bg-white/10 backdrop-blur-md rounded-3xl p-8 border border-white/20 hover:bg-white/15 transition-all group relative overflow-hidden">
      <div class="absolute -right-4 -top-4 w-24 h-24 bg-blue-500/20 rounded-full blur-2xl group-hover:bg-blue-500/30 transition-all"></div>

      <div class="relative z-10">
        <div class="w-12 h-12 bg-blue-500/20 rounded-2xl flex items-center justify-center mb-6 border border-blue-400/30">
          <span class="text-2xl">🎨</span>
        </div>
        <h2 class="text-2xl font-black text-white mb-2 tracking-tight">Customize Games</h2>
        <p class="text-blue-200 mb-6 text-sm leading-relaxed">Personalize your games with custom content. Create prompt packs, trivia questions, and more.</p>
        <%= link_to customize_path, class: "inline-flex items-center gap-2 font-bold text-blue-300 hover:text-white transition-colors" do %>
          Customize <%= lucide_icon('arrow-right', class: "w-4 h-4") %>
        <% end %>
      </div>
    </div>
```

**Step 2: Replace with updated card**

```erb
    <div class="bg-white/10 backdrop-blur-md rounded-3xl p-8 border border-white/20 hover:bg-white/15 transition-all group relative overflow-hidden">
      <div class="absolute -right-4 -top-4 w-24 h-24 bg-blue-500/20 rounded-full blur-2xl group-hover:bg-blue-500/30 transition-all"></div>

      <div class="relative z-10">
        <div class="w-12 h-12 bg-blue-500/20 rounded-2xl flex items-center justify-center mb-6 border border-blue-400/30">
          <span class="text-2xl">🎨</span>
        </div>
        <h2 class="text-2xl font-black text-white mb-2 tracking-tight">Customize a Game</h2>
        <p class="text-blue-200 mb-6 text-sm leading-relaxed">Create a game template for your next event — pick a game type, add a custom content pack, and save it for one-click launching.</p>
        <div class="flex flex-col gap-3">
          <%= link_to new_game_template_path, class: "inline-flex items-center gap-2 font-bold text-blue-300 hover:text-white transition-colors" do %>
            Create a game template <%= lucide_icon('arrow-right', class: "w-4 h-4") %>
          <% end %>
          <%= link_to customize_path, class: "inline-flex items-center gap-2 text-sm font-bold text-blue-300/60 hover:text-blue-300 transition-colors" do %>
            Manage content packs <%= lucide_icon('arrow-right', class: "w-3 h-3") %>
          <% end %>
        </div>
      </div>
    </div>
```

**Step 3: Run the test suite**

```bash
bin/rspec spec/system
```

Expected: all passing. The route `new_game_template_path` already exists — confirm by checking `bin/rails routes | grep game_template`.

**Step 4: Commit**

```bash
git add app/views/dashboard/index.html.erb
git commit -m "feat: reorient dashboard Customize card to lead with game templates"
```

---

### Task 6: `/play` page — add customization note near Google login

**Files:**
- Modify: `app/views/home/index.html.erb` (around line 32–34, the logged-out Google login form)

**Step 1: Find the Google login form for logged-out users**

Find:
```erb
        <% else %>
          <%= form_with url: "/auth/google_oauth2", method: :post, data: { turbo: false } do |f| %>
            <%= f.submit "Login with Google", class: "bg-white text-blue-900 font-bold py-2 px-4 rounded-full shadow-sm hover:bg-blue-50 transition-colors text-sm" %>
          <% end %>
        <% end %>
```

**Step 2: Add the callout line below the submit button, inside the form block**

```erb
        <% else %>
          <%= form_with url: "/auth/google_oauth2", method: :post, data: { turbo: false } do |f| %>
            <%= f.submit "Login with Google", class: "bg-white text-blue-900 font-bold py-2 px-4 rounded-full shadow-sm hover:bg-blue-50 transition-colors text-sm" %>
          <% end %>
          <p class="text-blue-300/70 text-xs mt-2">Sign in to save game templates and create custom content.</p>
        <% end %>
```

**Step 3: Run the test suite**

```bash
bin/rspec spec/system
```

Expected: all passing.

**Step 4: Commit**

```bash
git add app/views/home/index.html.erb
git commit -m "feat: add customization note near Google login on play page"
```

---

### Task 7: Visual review

**Step 1: Start the dev server**

```bash
bin/dev
```

**Step 2: Review logged-out landing page**

Visit `http://localhost:3000`. Confirm:
- New "Games Built for Your Group" section appears first (before "Plus, you stay in control")
- "Plus, you stay in control" is still present below it
- "How It Works" step 3 says "Customize" not "Curate"
- "Ready to make it yours?" login callout appears between "How It Works" and the footer CTA
- Footer CTA is unchanged

**Step 3: Review logged-out `/play` page**

Visit `http://localhost:3000/play`. Confirm:
- "Sign in to save game templates and create custom content." appears below the Google login button

**Step 4: Review dashboard (log in first)**

Visit `http://localhost:3000/dashboard`. Confirm:
- "Customize a Game" card says "Create a game template for your next event..."
- Primary link goes to `/game_templates/new`
- Secondary "Manage content packs →" link goes to `/customize`

**Step 5: Review logged-in landing page**

Visit `http://localhost:3000` while logged in. Confirm:
- The "Ready to make it yours?" callout is NOT visible (it's logged-out only)

---

### Task 8: Open PR

```bash
git push -u origin feature/customize-first
gh pr create --title "Pivot landing page and dashboard to lead with game customization" --body "$(cat <<'EOF'
## Why

The landing page led with content moderation as the primary value prop, but the more compelling pitch for new users is that they can tailor games to their specific group (birthday party, bible study, team meeting). New users think in terms of their event, not in terms of a content pack tool.

## What changed

**Landing page:**
- New primary feature section: "Games Built for Your Group" (game templates, custom prompts, custom trivia)
- "Backstage Advantage" demoted to secondary — heading softened to "Plus, you stay in control"
- How It Works step 3: "Curate" → "Customize" with updated copy
- New logged-out-only callout: "Ready to make it yours?" with Google login button

**Dashboard:**
- "Customize Games" card renamed to "Customize a Game"
- Primary link now points to `/game_templates/new` (was `/customize`)
- Secondary sub-link "Manage content packs →" still reaches `/customize`

**`/play` page:**
- One-line note below Google login button: "Sign in to save game templates and create custom content."

## Decisions

- Moderation stayed as a secondary feature — it's still a real differentiator for classrooms/youth groups, just not the lead
- No structural or route changes — pure view edits
- Login callout on landing page is logged-out only; logged-in users already have dashboard access

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
