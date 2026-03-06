# Open Core Engine Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a Rails engine at `engines/pro/` that extends RoomRally with pro-tier plan limits, integrated via a `PlanResolver` service. Refactor existing AI limits to use `PlanResolver`. Clean up superseded `app/features/` directory.

**Architecture:** The main app defines `PlanResolver` with free-tier limits. The engine uses `Module#prepend` to decorate `PlanResolver` with pro-tier limits, keyed off `User#pro?` (a `plan` column on `users`). Without the engine loaded, the app works standalone with free-tier defaults.

**Tech Stack:** Ruby on Rails 8+, Rails Engine (gem)

---

## Task 1: Create PlanResolver Service (Main App)

**Files:**
- Create: `app/services/plan_resolver.rb`
- Create: `spec/services/plan_resolver_spec.rb`

### Step 1: Write the failing test

```ruby
# spec/services/plan_resolver_spec.rb
require "rails_helper"

RSpec.describe PlanResolver do
  describe ".for" do
    it "returns a PlanResolver instance" do
      expect(described_class.for(nil)).to be_a(PlanResolver)
    end

    it "returns free tier for nil user" do
      resolver = described_class.for(nil)
      expect(resolver.tier).to eq(:free)
    end

    it "returns free tier for any user (without engine)" do
      user = create(:user)
      resolver = described_class.for(user)
      expect(resolver.tier).to eq(:free)
    end
  end

  describe "#limits" do
    let(:resolver) { described_class.for(nil) }

    it "returns free-tier AI request limit" do
      expect(resolver.limits[:ai_requests_per_window]).to eq(10)
    end

    it "returns free-tier AI grace failure limit" do
      expect(resolver.limits[:ai_grace_failures]).to eq(3)
    end

    it "returns free-tier audience size" do
      expect(resolver.limits[:audience_size]).to eq(10)
    end

    it "returns free-tier pack image limit" do
      expect(resolver.limits[:pack_image_limit]).to eq(20)
    end
  end

  describe "#within_limit?" do
    let(:resolver) { described_class.for(nil) }

    it "returns true when value is within limit" do
      expect(resolver.within_limit?(:audience_size, 5)).to be true
    end

    it "returns true when value equals limit" do
      expect(resolver.within_limit?(:audience_size, 10)).to be true
    end

    it "returns false when value exceeds limit" do
      expect(resolver.within_limit?(:audience_size, 11)).to be false
    end
  end

  describe "#pro?" do
    it "returns false for free tier" do
      expect(described_class.for(nil).pro?).to be false
    end
  end
end
```

### Step 2: Run test to verify it fails

Run: `bin/rspec spec/services/plan_resolver_spec.rb`
Expected: FAIL — `uninitialized constant PlanResolver`

### Step 3: Write the implementation

```ruby
# app/services/plan_resolver.rb
class PlanResolver
  FREE_LIMITS = {
    audience_size: 10,
    ai_requests_per_window: 10,
    ai_grace_failures: 3,
    pack_image_limit: 20
  }.freeze

  attr_reader :tier

  def self.for(_user)
    new(:free)
  end

  def initialize(tier)
    @tier = tier
  end

  def limits
    FREE_LIMITS
  end

  def within_limit?(feature, value)
    limit = limits.fetch(feature)
    limit.nil? || value <= limit
  end

  def pro?
    false
  end
end
```

### Step 4: Run test to verify it passes

Run: `bin/rspec spec/services/plan_resolver_spec.rb`
Expected: PASS — all examples green

### Step 5: Commit

```bash
git add app/services/plan_resolver.rb spec/services/plan_resolver_spec.rb
git commit -m "feat: add PlanResolver service with free-tier limits"
```

---

## Task 2: Add `plan` Column to User

**Files:**
- Create: `db/migrate/TIMESTAMP_add_plan_to_users.rb` (via generator)
- Modify: `app/models/user.rb:1-2` (add `pro?` method)
- Create: `spec/models/user/plan_spec.rb`

### Step 1: Write the failing test

```ruby
# spec/models/user/plan_spec.rb
require "rails_helper"

RSpec.describe User, "#plan", type: :model do
  describe "#pro?" do
    it "returns false by default" do
      user = create(:user)
      expect(user.pro?).to be false
    end

    it "returns false when plan is free" do
      user = create(:user, plan: "free")
      expect(user.pro?).to be false
    end

    it "returns true when plan is pro" do
      user = create(:user, plan: "pro")
      expect(user.pro?).to be true
    end
  end
end
```

### Step 2: Run test to verify it fails

Run: `bin/rspec spec/models/user/plan_spec.rb`
Expected: FAIL — `unknown attribute 'plan'`

### Step 3: Generate and run migration

Run: `bin/rails generate migration AddPlanToUsers plan:string`

Then edit the generated migration to add the default and null constraint:

```ruby
class AddPlanToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :plan, :string, default: "free", null: false
  end
end
```

Run: `bin/rails db:migrate`

### Step 4: Add `pro?` method to User

Add after line 1 (`class User < ApplicationRecord`):

```ruby
  def pro?
    plan == "pro"
  end
```

### Step 5: Run test to verify it passes

Run: `bin/rspec spec/models/user/plan_spec.rb`
Expected: PASS

### Step 6: Commit

```bash
git add db/migrate/*_add_plan_to_users.rb app/models/user.rb spec/models/user/plan_spec.rb db/schema.rb
git commit -m "feat: add plan column to users with pro? method"
```

---

## Task 3: Refactor User AI Limits to Use PlanResolver

**Files:**
- Modify: `app/models/user.rb:11-13` (replace constants with methods)
- Modify: `app/jobs/ai_generation_job.rb:36,43` (replace constant references)
- Modify: `app/views/ai_generation_requests/_panel.html.erb:11` (replace constant reference)
- Modify: `app/views/admin/users/show.html.erb:8,11,14,29` (replace constant references)
- Modify: `app/views/admin/users/index.html.erb:10` (replace constant reference)
- Modify: `spec/models/user/ai_rate_limiting_spec.rb:15-16` (update expected values to use resolver)

### Step 1: Update User model — replace constants with PlanResolver methods

Replace lines 11-13 of `app/models/user.rb`:

```ruby
  # Old:
  AI_REQUEST_LIMIT = 10
  AI_GRACE_FAILURE_LIMIT = 3
  AI_WINDOW_HOURS = 8

  # New:
  AI_WINDOW_HOURS = 8

  def ai_request_limit
    PlanResolver.for(self).limits[:ai_requests_per_window]
  end

  def ai_grace_failure_limit
    PlanResolver.for(self).limits[:ai_grace_failures]
  end
```

Note: `AI_WINDOW_HOURS` stays as a constant — it's not a plan-gated limit, it's a fixed window size.

### Step 2: Update `ai_requests_remaining` to use instance method

In `app/models/user.rb`, change `ai_requests_remaining`:

```ruby
  def ai_requests_remaining
    used = ai_generation_requests
      .where(counts_against_limit: true)
      .where("created_at > ?", AI_WINDOW_HOURS.hours.ago)
      .count
    [ ai_request_limit - used, 0 ].max
  end
```

### Step 3: Update `app/jobs/ai_generation_job.rb` — replace constant references

Line 36, replace `User::AI_WINDOW_HOURS` → stays the same (constant kept).

Line 43, replace `User::AI_GRACE_FAILURE_LIMIT` with `request.user.ai_grace_failure_limit`:

```ruby
      request.update!(
        status: :failed,
        error_message:,
        raw_response:,
        counts_against_limit: grace_used >= request.user.ai_grace_failure_limit
      )
```

### Step 4: Update views — replace constant references

**`app/views/ai_generation_requests/_panel.html.erb:11`:**

```erb
      <%= remaining %> / <%= current_user.ai_request_limit %> credits
```

**`app/views/admin/users/show.html.erb:11`:**

```ruby
  ai_remaining = [@user.ai_request_limit - ai_used, 0].max
```

**`app/views/admin/users/show.html.erb:29`:**

```erb
        <%= ai_used %> / <%= @user.ai_request_limit %>
```

### Step 5: Update existing AI rate limiting spec

In `spec/models/user/ai_rate_limiting_spec.rb`, line 16:

The test `it "returns 10 when no requests have been made"` still expects `10` — that's fine because `PlanResolver.for(user)` returns free limits by default, and the free limit is `10`. No change needed to the test values.

### Step 6: Run the full test suite

Run: `bin/rspec`
Expected: All tests pass

### Step 7: Run code quality checks

Run: `rubocop -A && brakeman -q`
Expected: No new issues

### Step 8: Commit

```bash
git add app/models/user.rb app/jobs/ai_generation_job.rb app/views/ai_generation_requests/_panel.html.erb app/views/admin/users/show.html.erb app/views/admin/users/index.html.erb
git commit -m "refactor: replace User AI limit constants with PlanResolver methods"
```

---

## Task 4: Refactor TriviaPack Image Limit to Use PlanResolver

**Files:**
- Modify: `app/models/trivia_pack.rb:31-35` (use PlanResolver for limit)
- Modify: `app/views/trivia_packs/_form.html.erb:66` (use dynamic limit)

### Step 1: Update TriviaPack validation

In `app/models/trivia_pack.rb`, replace the `image_count_within_limit` method:

```ruby
  def image_count_within_limit
    limit = PlanResolver.for(user).limits[:pack_image_limit]
    count = trivia_questions.joins(:image_attachment).count
    if count > limit
      errors.add(:base, "cannot have more than #{limit} questions with images")
    end
  end
```

### Step 2: Update the view to show dynamic limit

In `app/views/trivia_packs/_form.html.erb:66`, replace the hardcoded `20 / 20`:

```erb
        Image limit reached. Remove an existing image to add a new one.
```

### Step 3: Run tests

Run: `bin/rspec spec/models/trivia_pack_spec.rb`
Expected: PASS

### Step 4: Run full suite

Run: `bin/rspec`
Expected: All tests pass

### Step 5: Commit

```bash
git add app/models/trivia_pack.rb app/views/trivia_packs/_form.html.erb
git commit -m "refactor: use PlanResolver for trivia pack image limit"
```

---

## Task 5: Create Rails Engine Skeleton

**Files:**
- Create: `engines/pro/roomrally_pro.gemspec`
- Create: `engines/pro/Gemfile`
- Create: `engines/pro/lib/roomrally_pro.rb`
- Create: `engines/pro/lib/roomrally_pro/engine.rb`
- Create: `engines/pro/README.md`
- Modify: `Gemfile` (add engine gem)

### Step 1: Create engine directory structure

```bash
mkdir -p engines/pro/lib/roomrally_pro
mkdir -p engines/pro/app/models/concerns/roomrally_pro
mkdir -p engines/pro/config/initializers
```

### Step 2: Create gemspec

```ruby
# engines/pro/roomrally_pro.gemspec
Gem::Specification.new do |spec|
  spec.name        = "roomrally_pro"
  spec.version     = "0.1.0"
  spec.authors     = ["Jack Hartzler"]
  spec.summary     = "Pro features for Room Rally"
  spec.description = "Adds pro-tier plan limits and feature gating to Room Rally."

  spec.files = Dir["lib/**/*", "app/**/*", "config/**/*", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 8.0"
end
```

### Step 3: Create engine Gemfile

```ruby
# engines/pro/Gemfile
source "https://rubygems.org"
gemspec
```

### Step 4: Create gem entry point

```ruby
# engines/pro/lib/roomrally_pro.rb
require "roomrally_pro/engine"

module RoomrallyPro
end
```

### Step 5: Create engine class

```ruby
# engines/pro/lib/roomrally_pro/engine.rb
module RoomrallyPro
  class Engine < ::Rails::Engine
    # Isolate engine namespace to avoid class conflicts with host app.
    # This means engine classes are accessed as RoomrallyPro::ClassName.
    isolate_namespace RoomrallyPro

    # config.to_prepare runs after autoloading in development (each reload)
    # and once in production. This is the right hook for prepending onto
    # host app classes because those classes must be loaded first.
    config.to_prepare do
      # Load the pro plan limits decoration
      load RoomrallyPro::Engine.root.join("config/initializers/plan_resolver.rb")
    end
  end
end
```

### Step 6: Create engine README

```markdown
# RoomRally Pro

Rails engine that adds pro-tier features to Room Rally.

## What It Does

- Overrides `PlanResolver` to provide pro-tier limits when `user.pro?` is true
- Pro limits: 50 audience, 50 AI requests/window, 10 grace failures, 50 pack images

## Installation

Added to the host app's Gemfile:

```ruby
gem "roomrally_pro", path: "engines/pro"
```

Then `bundle install`.

## Setting a User to Pro

```ruby
user.update!(plan: "pro")
```
```

### Step 7: Add engine to host app Gemfile

Add at the end of the `Gemfile`, before the final newline:

```ruby
# Pro features engine (private — excluded from public repo)
gem "roomrally_pro", path: "engines/pro"
```

### Step 8: Run bundle install

Run: `bundle install`
Expected: Resolves successfully, engine is loaded

### Step 9: Verify engine loads

Run: `bin/rails runner "puts RoomrallyPro::Engine.root"`
Expected: Prints the path to `engines/pro`

### Step 10: Commit

```bash
git add engines/pro/ Gemfile Gemfile.lock
git commit -m "feat: add RoomRally Pro engine skeleton"
```

---

## Task 6: Engine Decorates PlanResolver with Pro Limits

**Files:**
- Create: `engines/pro/app/models/concerns/roomrally_pro/plan_limits.rb`
- Create: `engines/pro/config/initializers/plan_resolver.rb`
- Create: `spec/services/plan_resolver_pro_spec.rb`

### Step 1: Write the failing test

```ruby
# spec/services/plan_resolver_pro_spec.rb
require "rails_helper"

RSpec.describe PlanResolver, "with pro engine" do
  describe ".for" do
    it "returns pro tier for pro user" do
      user = create(:user, plan: "pro")
      resolver = described_class.for(user)
      expect(resolver.tier).to eq(:pro)
    end

    it "returns free tier for free user" do
      user = create(:user, plan: "free")
      resolver = described_class.for(user)
      expect(resolver.tier).to eq(:free)
    end

    it "returns free tier for nil user" do
      resolver = described_class.for(nil)
      expect(resolver.tier).to eq(:free)
    end
  end

  describe "#limits for pro user" do
    let(:resolver) { described_class.for(create(:user, plan: "pro")) }

    it "returns pro audience size" do
      expect(resolver.limits[:audience_size]).to eq(50)
    end

    it "returns pro AI request limit" do
      expect(resolver.limits[:ai_requests_per_window]).to eq(50)
    end

    it "returns pro AI grace failure limit" do
      expect(resolver.limits[:ai_grace_failures]).to eq(10)
    end

    it "returns pro pack image limit" do
      expect(resolver.limits[:pack_image_limit]).to eq(50)
    end
  end

  describe "#pro?" do
    it "returns true for pro user" do
      user = create(:user, plan: "pro")
      expect(described_class.for(user).pro?).to be true
    end

    it "returns false for free user" do
      user = create(:user, plan: "free")
      expect(described_class.for(user).pro?).to be false
    end
  end

  describe "integration: User#ai_request_limit respects plan" do
    it "returns 10 for free user" do
      user = create(:user, plan: "free")
      expect(user.ai_request_limit).to eq(10)
    end

    it "returns 50 for pro user" do
      user = create(:user, plan: "pro")
      expect(user.ai_request_limit).to eq(50)
    end
  end
end
```

### Step 2: Run test to verify it fails

Run: `bin/rspec spec/services/plan_resolver_pro_spec.rb`
Expected: FAIL — pro user still gets free-tier limits

### Step 3: Create the pro plan limits module

```ruby
# engines/pro/app/models/concerns/roomrally_pro/plan_limits.rb
# frozen_string_literal: true

module RoomrallyPro
  module PlanLimits
    PRO_LIMITS = {
      audience_size: 50,
      ai_requests_per_window: 50,
      ai_grace_failures: 10,
      pack_image_limit: 50
    }.freeze

    def limits
      @tier == :pro ? PRO_LIMITS : super
    end

    def pro?
      @tier == :pro
    end
  end
end
```

### Step 4: Create the initializer that wires it up

```ruby
# engines/pro/config/initializers/plan_resolver.rb

# Decorate PlanResolver.for to check user.pro? and return pro tier.
# Uses Module#prepend so the engine's .for runs first, falling through
# to the original via super when the user isn't pro.
PlanResolver.prepend(RoomrallyPro::PlanLimits)

PlanResolver.singleton_class.prepend(
  Module.new do
    def for(user)
      if user&.pro?
        new(:pro)
      else
        super
      end
    end
  end
)
```

### Step 5: Run test to verify it passes

Run: `bin/rspec spec/services/plan_resolver_pro_spec.rb`
Expected: PASS — all examples green

### Step 6: Run full test suite

Run: `bin/rspec`
Expected: All tests pass (free users still get free limits, nothing breaks)

### Step 7: Commit

```bash
git add engines/pro/app/models/concerns/roomrally_pro/plan_limits.rb engines/pro/config/initializers/plan_resolver.rb spec/services/plan_resolver_pro_spec.rb
git commit -m "feat: engine decorates PlanResolver with pro-tier limits"
```

---

## Task 7: Clean Up — Delete `app/features/` and Update `.gitignore-public`

**Files:**
- Delete: `app/features/` (entire directory)
- Modify: `.gitignore-public` (change `app/features/pro/` → `engines/pro/`)

### Step 1: Delete superseded `app/features/` directory

```bash
rm -rf app/features/
```

### Step 2: Update `.gitignore-public`

Replace the last line:

```gitignore
# --- Open Core: exclude pro features layer ---
/engines/pro/
```

### Step 3: Run full test suite

Run: `bin/rspec`
Expected: All tests pass (nothing referenced `app/features/`)

### Step 4: Run code quality checks

Run: `rubocop -A && brakeman -q`
Expected: No new issues

### Step 5: Commit

```bash
git add -A  # stages deletions + .gitignore-public change
git commit -m "chore: delete app/features/ (superseded by engines/pro/) and update .gitignore-public"
```

---

## Task 8: Rewrite README for Public Repo

**Files:**
- Modify: `README.md` (full rewrite)

### Step 1: Rewrite `README.md`

```markdown
# Room Rally

A real-time multiplayer party game engine for in-person play. A host projects the Stage on a shared screen while players join on their phones via 4-letter room codes. Built for classrooms, youth groups, living rooms, and parties.

## Game Types

All game engines are fully open source:

- **Comedy Clash** (Write & Vote) — Players write funny responses to prompts, then vote on favorites
- **Think Fast** (Speed Trivia) — Timed trivia rounds where speed matters
- **A-List** (Category List) — Name items in a category before time runs out

## Tech Stack

- **Backend:** Ruby on Rails 8+ (Ruby 3.4)
- **Real-time:** Turbo Streams over Action Cable (HTML-Over-The-Wire)
- **Frontend:** Hotwire (Turbo + Stimulus), Tailwind CSS
- **Background Jobs:** Sidekiq
- **Database:** PostgreSQL
- **File Storage:** Active Storage (configurable — local disk, S3, Cloudflare R2, etc.)
- **Deployment:** Kamal
- **Testing:** RSpec, Capybara with Playwright

## Self-Hosting

### Prerequisites

- Ruby (see `.ruby-version`)
- Node.js
- PostgreSQL
- Redis

### Setup

```bash
git clone https://github.com/jackhartzler/roomrally.git
cd roomrally
cp .env.example .env  # Fill in your values
bin/setup
```

### Environment Variables

Copy `.env.example` and fill in your values. Required:

| Variable | Description |
|----------|-------------|
| `GOOGLE_CLIENT_ID` | Google OAuth client ID (for host login) |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret |
| `R2_ACCESS_KEY_ID` | S3-compatible storage access key |
| `R2_SECRET_ACCESS_KEY` | S3-compatible storage secret key |
| `R2_ACCOUNT_ID` | Storage account ID (for endpoint URL) |
| `OPENAI_API_KEY` | OpenAI API key (for AI content generation) |

Optional: `SENTRY_DSN`, `POSTHOG_API_KEY`, `OPENAI_MODEL`

### Storage

Active Storage is configured in `config/storage.yml`. The default uses Cloudflare R2 (S3-compatible). To use a different backend, update `storage.yml` and set `config.active_storage.service` in your environment config.

### Running

```bash
bin/dev  # Starts Rails, Sidekiq, and Tailwind CSS watcher
```

### Testing

```bash
bin/rspec              # All tests
bin/rspec spec/system  # End-to-end multiplayer tests
```

## Open Core Model

Room Rally uses an open core model:

- **Open (this repo):** All game engines, core platform, self-hosting support
- **Hosted version:** Adds pro features like larger group support, higher AI generation limits, and additional game types

The hosted version relaxes capability limits (audience size, AI requests, pack images) and adds features gated behind a subscription. Self-hosters get the full open core with sensible free-tier defaults.

## Architecture

See the `docs/` directory for detailed guides:

- [Architecture](docs/architecture.md) — Request flow, core patterns, concurrency
- [Data Models](docs/data_models.md) — Schema and relationships
- [Client Guide](docs/client_guide.md) — Stage and Hand client architecture
- [Development Guide](docs/development_guide.md) — Contributing, testing, conventions

## License

MIT
```

### Step 2: Run rubocop

Run: `rubocop -A`
Expected: No issues

### Step 3: Commit

```bash
git add README.md
git commit -m "docs: rewrite README for open core public repo"
```

---

## Summary of Changes

| Task | What | Files |
|------|------|-------|
| 1 | PlanResolver service (free tier) | `app/services/plan_resolver.rb`, spec |
| 2 | `plan` column on User | migration, `user.rb`, spec |
| 3 | Refactor AI limits → PlanResolver | `user.rb`, `ai_generation_job.rb`, 3 views |
| 4 | Refactor image limit → PlanResolver | `trivia_pack.rb`, 1 view |
| 5 | Engine skeleton | `engines/pro/`, Gemfile |
| 6 | Engine decorates PlanResolver | engine initializer + concern, spec |
| 7 | Clean up `app/features/` | deletions, `.gitignore-public` |
| 8 | Public README | `README.md` |
