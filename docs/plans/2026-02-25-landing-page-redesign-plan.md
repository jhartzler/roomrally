# Landing Page Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the landing page so game modes are visible near the top, scroll depth is reduced ~35–40%, moderation is compact, and How It Works has four meaningful steps.

**Architecture:** Single-file view change to `app/views/pages/landing.html.erb`. No controller, model, or route changes. Section order becomes: Hero (logo + game tiles + CTAs) → Customization → Moderation strip → How It Works → Sign-in CTA → Footer CTA.

**Tech Stack:** Rails ERB, Tailwind CSS (utility classes, `bg-gradient-to-br`, `grid-cols-3`), existing glassmorphism patterns (`bg-white/10 backdrop-blur-md`).

---

## Before You Start: Screenshot Baseline

```bash
cd worktrees/feature_landing-page-redesign
rake screenshots:capture
rake screenshots:approve
```

This saves a visual baseline to compare against after changes. Baselines are ephemeral (not committed).

---

### Task 1: Add landing page request spec

Add coverage for the new content we're about to build. No landing page tests exist today.

**Files:**
- Modify: `spec/requests/pages_spec.rb`

**Step 1: Add the spec block**

Add this inside `spec/requests/pages_spec.rb`, after the existing `describe "GET /terms"` block:

```ruby
describe "GET /" do
  it "returns http success" do
    get root_path
    expect(response).to have_http_status(:success)
  end

  it "displays all three game mode tiles" do
    get root_path
    expect(response.body).to include("Comedy Clash")
    expect(response.body).to include("A-List")
    expect(response.body).to include("Think Fast")
  end

  it "displays the How It Works section with four steps" do
    get root_path
    expect(response.body).to include("How It Works")
    expect(response.body).to include("Pick Your Game Mode")
    expect(response.body).to include("Make It Yours")
    expect(response.body).to include("Launch &amp; Display")
    expect(response.body).to include("Everyone Joins")
  end
end
```

**Step 2: Run tests to confirm they fail**

```bash
bin/rspec spec/requests/pages_spec.rb -e "GET /" --format documentation
```

Expected: 3 failures — the current landing page does not include these strings.

**Step 3: Commit the failing spec**

```bash
git add spec/requests/pages_spec.rb
git commit -m "test: add landing page spec for game tiles and How It Works"
```

---

### Task 2: Redesign hero section with game mode tiles

Replace the oversized hero with a compact version where the three game mode tiles are the visual centerpiece.

**Files:**
- Modify: `app/views/pages/landing.html.erb` (lines 8–24, the entire Hero section)

**Step 1: Replace Section 1 (Hero)**

Replace everything from `<%# Section 1: Hero %>` through the closing `</section>` tag (current lines 8–24) with:

```erb
  <%# Section 1: Hero %>
  <section class="text-center py-6 mb-8 md:mb-10">
    <img src="<%= "#{Rails.configuration.x.r2_assets_url}/logos/full-logo.png" %>" alt="RoomRally Logo" class="h-20 md:h-28 mb-5 mx-auto drop-shadow-2xl object-contain">
    <h1 class="text-2xl md:text-3xl font-black text-white mb-8 leading-tight">
      Where 'you had to be there' begins.
    </h1>

    <%# Game Mode Tiles %>
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8 max-w-4xl mx-auto text-left">
      <div class="bg-gradient-to-br from-purple-600 to-pink-500 rounded-2xl shadow-xl p-6">
        <div class="text-4xl mb-3">🎤</div>
        <h3 class="text-xl font-black text-white mb-1">Comedy Clash</h3>
        <p class="text-white/90 font-semibold text-sm mb-2">Your words, their laughs</p>
        <p class="text-white/70 text-sm">Write funny answers to prompts. The room votes for the best.</p>
      </div>

      <div class="bg-gradient-to-br from-teal-600 to-emerald-500 rounded-2xl shadow-xl p-6">
        <div class="text-4xl mb-3">📋</div>
        <h3 class="text-xl font-black text-white mb-1">A-List</h3>
        <p class="text-white/90 font-semibold text-sm mb-2">Think fast, list faster</p>
        <p class="text-white/70 text-sm">Name as many as you can before time runs out.</p>
      </div>

      <div class="bg-gradient-to-br from-orange-500 to-red-500 rounded-2xl shadow-xl p-6">
        <div class="text-4xl mb-3">⚡</div>
        <h3 class="text-xl font-black text-white mb-1">Think Fast</h3>
        <p class="text-white/90 font-semibold text-sm mb-2">Trivia with a twist</p>
        <p class="text-white/70 text-sm">Answer before the clock does.</p>
      </div>
    </div>

    <div class="flex flex-col sm:flex-row gap-4 justify-center">
      <%= link_to host_path, class: "inline-block bg-orange-500 text-white font-black py-4 px-10 rounded-full hover:bg-orange-600 active:scale-95 transform hover:shadow-2xl shadow-orange-900/40 transition-all duration-200 text-xl" do %>
        Host a Game
      <% end %>
      <%= link_to play_path, class: "inline-block bg-white/20 backdrop-blur text-white font-black py-4 px-10 rounded-full hover:bg-white/30 active:scale-95 transform transition-all duration-200 text-xl border border-white/30" do %>
        Join a Game
      <% end %>
    </div>
  </section>
```

**Step 2: Run specs**

```bash
bin/rspec spec/requests/pages_spec.rb -e "game mode tiles" --format documentation
```

Expected: PASS — "Comedy Clash", "A-List", "Think Fast" now in the page.

**Step 3: Visually inspect in browser**

Start `bin/dev`, open `http://localhost:3000`. Verify tiles appear below the tagline, logo is smaller, three gradient cards are visible.

**Step 4: Commit**

```bash
git add app/views/pages/landing.html.erb
git commit -m "redesign: hero section with game mode tiles"
```

---

### Task 3: Tighten customization section spacing

No content changes — only reduce padding and margins so the section is more compact.

**Files:**
- Modify: `app/views/pages/landing.html.erb` (current Section 2, around lines 26–64)

**Step 1: Update the opening tag of the Customization section**

Find:
```erb
  <section class="bg-white/10 backdrop-blur-md rounded-3xl shadow-2xl p-12 md:p-16 border border-white/20 mb-16 md:mb-24">
    <h2 class="text-3xl md:text-4xl font-bold text-white mb-6">Games Built for Your Group</h2>
```

Replace with:
```erb
  <section class="bg-white/10 backdrop-blur-md rounded-3xl shadow-2xl p-8 md:p-10 border border-white/20 mb-10 md:mb-16">
    <h2 class="text-3xl md:text-4xl font-bold text-white mb-6">Games Built for Your Group</h2>
```

**Step 2: Run all landing page specs**

```bash
bin/rspec spec/requests/pages_spec.rb --format documentation
```

Expected: all PASS (spacing changes don't affect content assertions).

**Step 3: Commit**

```bash
git add app/views/pages/landing.html.erb
git commit -m "redesign: tighten customization section spacing"
```

---

### Task 4: Replace moderation section with compact strip

The current Section 3 is a full card with heading, paragraph, 3 feature cards, and a screenshot (~600px tall). Replace with a lean horizontal strip of 3 icon+text items.

**Files:**
- Modify: `app/views/pages/landing.html.erb` (current Section 3 "The Backstage Advantage", around lines 66–102)

**Step 1: Replace entire Section 3**

Find everything from `<%# Section 3: The Backstage Advantage %>` through its closing `</section>` and replace with:

```erb
  <%# Section 3: Moderation (compact) %>
  <section class="bg-white/10 backdrop-blur-md rounded-2xl p-6 border border-white/20 mb-10 md:mb-16">
    <div class="flex flex-col sm:flex-row gap-6 justify-around">
      <div class="flex items-start gap-3">
        <span class="text-2xl flex-shrink-0">✅</span>
        <div>
          <p class="text-white font-bold text-sm">Approve or reject submissions</p>
          <p class="text-blue-200 text-sm">Filter content before it hits the screen</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <span class="text-2xl flex-shrink-0">🔓</span>
        <div>
          <p class="text-white font-bold text-sm">No player accounts</p>
          <p class="text-blue-200 text-sm">Players join via QR code, no sign-up</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <span class="text-2xl flex-shrink-0">🌐</span>
        <div>
          <p class="text-white font-bold text-sm">Any device, nothing to install</p>
          <p class="text-blue-200 text-sm">Works on any phone, tablet, or laptop</p>
        </div>
      </div>
    </div>
  </section>
```

**Step 2: Run all landing page specs**

```bash
bin/rspec spec/requests/pages_spec.rb --format documentation
```

Expected: all PASS.

**Step 3: Commit**

```bash
git add app/views/pages/landing.html.erb
git commit -m "redesign: collapse moderation section to compact strip"
```

---

### Task 5: Expand How It Works to four steps

Replace the current 3-step thin version with 4 steps in the correct order (Choose → Customize → Launch → Play), each with a real paragraph. The copy below is placeholder — the host will supply final wording before launch.

**Files:**
- Modify: `app/views/pages/landing.html.erb` (current Section 4 "How It Works", around lines 104–144)

**Step 1: Replace entire Section 4**

Find everything from `<%# Section 4: How It Works %>` through its closing `</section>` and replace with:

```erb
  <%# Section 4: How It Works %>
  <section class="bg-white/10 backdrop-blur-md rounded-3xl shadow-2xl p-8 md:p-12 border border-white/20 mb-10 md:mb-16">
    <h2 class="text-3xl md:text-4xl font-bold text-white text-center mb-10">How It Works</h2>
    <div class="space-y-8 max-w-3xl mx-auto">

      <div class="flex gap-6 items-start">
        <div class="flex-shrink-0 w-12 h-12 bg-orange-500 rounded-full flex items-center justify-center text-white font-black text-xl">1</div>
        <div>
          <h3 class="text-2xl font-bold text-white mb-2">Pick Your Game Mode</h3>
          <p class="text-blue-200 text-lg">
            Choose from Comedy Clash, A-List, or Think Fast — each one brings a different kind of fun.
            Comedy Clash is great for friend groups who love to one-up each other. A-List works for any crowd.
            Think Fast keeps things moving fast.
          </p>
        </div>
      </div>

      <div class="flex gap-6 items-start">
        <div class="flex-shrink-0 w-12 h-12 bg-orange-500 rounded-full flex items-center justify-center text-white font-black text-xl">2</div>
        <div>
          <h3 class="text-2xl font-bold text-white mb-2">Make It Yours</h3>
          <p class="text-blue-200 text-lg">
            Add your own prompts or questions — inside jokes, group-specific trivia, whatever fits your event.
            Save it as a template and your next launch is one click.
            RoomRally remembers your setup so you're not starting from scratch every time.
          </p>
        </div>
      </div>

      <div class="flex gap-6 items-start">
        <div class="flex-shrink-0 w-12 h-12 bg-orange-500 rounded-full flex items-center justify-center text-white font-black text-xl">3</div>
        <div>
          <h3 class="text-2xl font-bold text-white mb-2">Launch &amp; Display</h3>
          <p class="text-blue-200 text-lg">
            Start your session and open the Stage view on your shared screen — TV, projector, or laptop.
            It's just a browser tab. No cables, no software installs, no setup headaches.
          </p>
        </div>
      </div>

      <div class="flex gap-6 items-start">
        <div class="flex-shrink-0 w-12 h-12 bg-orange-500 rounded-full flex items-center justify-center text-white font-black text-xl">4</div>
        <div>
          <h3 class="text-2xl font-bold text-white mb-2">Everyone Joins &amp; Plays</h3>
          <p class="text-blue-200 text-lg">
            A QR code appears on the big screen. Players scan it from their phones — that's it.
            No accounts, no downloads, no waiting. When everyone's in, you start the game.
          </p>
        </div>
      </div>

    </div>
  </section>
```

**Step 2: Tighten the remaining sections (Sign-in CTA + Footer CTA)**

While here, reduce their margins to match the new tighter style. Find both remaining `mb-16 md:mb-24` on these sections and change to `mb-10 md:mb-16`.

**Step 3: Run all landing page specs**

```bash
bin/rspec spec/requests/pages_spec.rb --format documentation
```

Expected: all PASS, including the How It Works assertions ("Pick Your Game Mode", "Make It Yours", etc.).

**Step 4: Commit**

```bash
git add app/views/pages/landing.html.erb
git commit -m "redesign: expand How It Works to four steps with real copy"
```

---

### Task 6: Visual verification and final review

**Step 1: Capture new screenshots**

```bash
rake screenshots:capture
rake screenshots:report
```

Open the diff report in the browser. Verify:
- Hero is noticeably shorter/tighter
- Three gradient game tiles are visible near the top
- Moderation is a thin strip (no large screenshot)
- How It Works has 4 numbered steps

**Step 2: Run full test suite**

```bash
bin/rspec spec/requests/pages_spec.rb --format documentation
```

Expected: all 5 tests pass.

**Step 3: Clean up screenshots**

```bash
rake screenshots:clean
```

**Step 4: Final commit if any cleanup tweaks were made**

```bash
git add app/views/pages/landing.html.erb
git commit -m "redesign: landing page visual polish"
```

---

## Copy Note

The "How It Works" section uses placeholder copy. Before launch, the host should review and replace the paragraph text in Steps 1–4 with final wording. The HTML structure (numbered circles, heading, `<p>` tag) won't need to change — just swap the text.

## Future: Draggable Game Tiles

The game tiles in Task 2 are static gradient cards. A future iteration can add the Framer-style stacked/draggable interaction (slight rotation, drag-to-reorder) without changing the card layout — same HTML structure, add `transform: rotate(Ndeg)` and a drag library.
