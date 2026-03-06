# Open Core Architecture Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Split the RoomRally codebase into an open core structure — migrate credentials to ENV vars, create the pro features directory structure, build a sync script, and draft a public README.

**Architecture:** All pro-only code lives in `app/features/pro/` (two subdirs: `gates/` for capability limits, `features/` for additive features). The public repo is a generated subset of the private repo, filtered via `.gitignore-public`. Credentials move from `Rails.application.credentials` to `ENV.fetch` so self-hosters don't need a master key.

**Tech Stack:** Ruby on Rails 8+, Bash (sync script)

---

## Task 1: Migrate Credentials to ENV Vars

**Files:**
- Modify: `app/services/llm_client.rb:3-6`
- Modify: `config/initializers/omniauth.rb:2`
- Modify: `config/initializers/posthog.rb:3`
- Modify: `config/initializers/sentry.rb:2`
- Modify: `config/environments/development.rb:35`
- Modify: `config/environments/production.rb:64-65`
- Modify: `config/storage.yml:11-15`
- Modify: `lib/tasks/r2.rake:6-14`
- Create: `.env.example`

### Step 1: Update `app/services/llm_client.rb`

Replace credentials with ENV vars:

```ruby
class LlmClient
  def self.generate(system_prompt:, user_prompt:)
    client = OpenAI::Client.new(
      access_token: ENV.fetch("OPENAI_API_KEY")
    )
    model = ENV.fetch("OPENAI_MODEL", "gpt-4.1-mini")
```

### Step 2: Update `config/initializers/omniauth.rb`

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV.fetch("GOOGLE_CLIENT_ID"), ENV.fetch("GOOGLE_CLIENT_SECRET")
end
```

### Step 3: Update `config/initializers/posthog.rb`

Already has ENV fallback. Remove the credentials fallback:

```ruby
require "posthog"

api_key = ENV["POSTHOG_API_KEY"]

if api_key.present? && (Rails.env.production? || ENV["POSTHOG_FORCE_ENABLE"].present?)
  $posthog = PostHog::Client.new(
    api_key:,
    host: ENV.fetch("POSTHOG_HOST", "https://us.i.posthog.com"),
    on_error: ->(status, msg) { Rails.logger.warn("[PostHog] #{status}: #{msg}") }
  )
end
```

### Step 4: Update `config/initializers/sentry.rb`

Already has ENV fallback. Remove the credentials fallback:

```ruby
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.enabled_environments = %w[production]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.traces_sample_rate = 1.0
end
```

### Step 5: Update `config/environments/development.rb` (line 35)

```ruby
  config.x.r2_assets_url = ENV.fetch("R2_DEV_ASSETS_URL", "")
```

### Step 6: Update `config/environments/production.rb` (lines 64-65)

These are already commented out. Update the comments to reference ENV vars:

```ruby
  # Specify outgoing SMTP server.
  #   user_name: ENV.fetch("SMTP_USER_NAME"),
  #   password: ENV.fetch("SMTP_PASSWORD"),
```

### Step 7: Update `config/storage.yml`

```yaml
r2:
  service: S3
  access_key_id: <%= ENV.fetch("R2_ACCESS_KEY_ID") %>
  secret_access_key: <%= ENV.fetch("R2_SECRET_ACCESS_KEY") %>
  region: auto
  bucket: <%= "roomrally-uploads-#{Rails.env == 'production' ? 'prod' : 'dev'}" %>
  endpoint: <%= "https://#{ENV.fetch("R2_ACCOUNT_ID")}.r2.cloudflarestorage.com" %>
  force_path_style: true
```

### Step 8: Update `lib/tasks/r2.rake`

Replace `Rails.application.credentials.r2` with individual ENV fetches:

```ruby
namespace :r2 do
  desc "Upload static assets (hero image, OG image) to the R2 assets bucket"
  task upload_assets: :environment do
    require "aws-sdk-s3"

    bucket_name = Rails.env.production? ? "roomrally-assets-prod" : "roomrally-assets-dev"

    client = Aws::S3::Client.new(
      access_key_id: ENV.fetch("R2_ACCESS_KEY_ID"),
      secret_access_key: ENV.fetch("R2_SECRET_ACCESS_KEY"),
      endpoint: "https://#{ENV.fetch("R2_ACCOUNT_ID")}.r2.cloudflarestorage.com",
      region: "auto",
      force_path_style: true
    )
    # ... rest of task unchanged ...
```

### Step 9: Create `.env.example`

```bash
# --- Required for core app ---
# Google OAuth (for host login)
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# --- Required for file uploads (Active Storage → Cloudflare R2) ---
R2_ACCESS_KEY_ID=your_r2_access_key_id
R2_SECRET_ACCESS_KEY=your_r2_secret_access_key
R2_ACCOUNT_ID=your_r2_account_id

# --- Required for AI features ---
OPENAI_API_KEY=your_openai_api_key
OPENAI_MODEL=gpt-4.1-mini  # optional, defaults to gpt-4.1-mini

# --- Optional services ---
# Error tracking
SENTRY_DSN=https://your_sentry_dsn

# Analytics
POSTHOG_API_KEY=your_posthog_api_key
POSTHOG_HOST=https://us.i.posthog.com  # optional, defaults to this

# R2 static asset CDN (development only)
R2_DEV_ASSETS_URL=https://your-dev-assets-url

# SMTP (not currently active)
# SMTP_USER_NAME=your_smtp_user
# SMTP_PASSWORD=your_smtp_password
```

### Step 10: Run tests

Run: `bin/rspec`
Expected: All tests pass (credentials aren't loaded in test env)

### Step 11: Run code quality checks

Run: `rubocop -A && brakeman -q`
Expected: No new issues

### Step 12: Commit

```bash
git add app/services/llm_client.rb config/initializers/omniauth.rb config/initializers/posthog.rb config/initializers/sentry.rb config/environments/development.rb config/environments/production.rb config/storage.yml lib/tasks/r2.rake .env.example
git commit -m "refactor: migrate credentials to ENV vars for open core self-hosting"
```

---

## Task 2: Create Pro Features Directory Structure

**Files:**
- Create: `app/features/pro/gates/plan.rb`
- Create: `app/features/pro/features/authorization.rb`
- Create: `app/features/plan_defaults.rb` (public-side defaults)

### Step 1: Ensure Rails autoloads `app/features/`

Check `config/application.rb` for autoload paths. If `app/features/` isn't autoloaded by default, add it:

```ruby
# In config/application.rb, inside the Application class:
config.autoload_paths << Rails.root.join("app/features")
```

Rails 8 autoloads everything under `app/` by default, so this step may be unnecessary — verify first.

### Step 2: Create `app/features/pro/gates/plan.rb`

```ruby
# frozen_string_literal: true

module Pro
  module Gates
    class Plan
      FREE_LIMITS = {
        audience_size: 25,
        storage_gb: 1,
        ai_requests: 10
      }.freeze

      PRO_LIMITS = {
        audience_size: 500,
        storage_gb: 20,
        ai_requests: nil # nil = unlimited
      }.freeze

      attr_reader :limits

      def initialize(tier = :free)
        @limits = tier == :pro ? PRO_LIMITS : FREE_LIMITS
      end

      # Check if a value is within the plan's limit for a given feature.
      # Returns true if the limit is nil (unlimited) or value <= limit.
      def within_limit?(feature, value)
        limit = limits.fetch(feature)
        limit.nil? || value <= limit
      end
    end
  end
end
```

### Step 3: Create `app/features/pro/features/authorization.rb`

```ruby
# frozen_string_literal: true

module Pro
  module Features
    # Concern for authorizing access to pro-only features.
    # Currently returns true for all features (no Stripe integration yet).
    # Will eventually check the user's Stripe entitlements.
    module Authorization
      extend ActiveSupport::Concern

      # Known pro feature keys:
      #   :photo_scavenger_hunt — first planned pro-gated game type
      def authorized_for?(feature_key)
        true # Stub — all features authorized until Stripe integration
      end
    end
  end
end
```

### Step 4: Create `app/features/plan_defaults.rb`

This is the public-side fallback so the app works without the pro layer:

```ruby
# frozen_string_literal: true

# Default plan limits for the open core (free tier).
# When the pro layer is present (app/features/pro/), Pro::Gates::Plan
# provides both free and pro tiers. Without it, these defaults apply.
module PlanDefaults
  FREE_LIMITS = {
    audience_size: 25,
    storage_gb: 1,
    ai_requests: 10
  }.freeze

  def self.within_limit?(feature, value)
    limit = FREE_LIMITS.fetch(feature)
    limit.nil? || value <= limit
  end
end
```

### Step 5: Create directory `.keep` files

```bash
touch app/features/pro/gates/.keep
touch app/features/pro/features/.keep
```

### Step 6: Verify autoloading

Run: `bin/rails runner "puts Pro::Gates::Plan.new.within_limit?(:audience_size, 10)"`
Expected: `true`

Run: `bin/rails runner "puts PlanDefaults.within_limit?(:ai_requests, 5)"`
Expected: `true`

### Step 7: Run tests

Run: `bin/rspec`
Expected: All tests still pass

### Step 8: Commit

```bash
git add app/features/
git commit -m "feat: add pro features directory structure with plan gates and feature authorization"
```

---

## Task 3: Update `.gitignore` Files

**Files:**
- Create: `.gitignore-public`

### Step 1: Create `.gitignore-public`

Copy the existing `.gitignore` and add the pro exclusion:

```gitignore
# See https://help.github.com/articles/ignoring-files for more about ignoring files.
#
# Temporary files generated by your text editor or operating system
# belong in git's global ignore instead:
# `$XDG_CONFIG_HOME/git/ignore` or `~/.config/git/ignore`

# macOS metadata
.DS_Store

# Ignore bundler config.
/.bundle

# Ignore all environment files.
/.env*

# Ignore user's local gemini setup
/.gemini

# Ignore all logfiles and tempfiles.
/log/*
/tmp/*
!/log/.keep
!/tmp/.keep

# Ignore pidfiles, but keep the directory.
/tmp/pids/*
!/tmp/pids/
!/tmp/pids/.keep

# Ignore storage (uploaded files in development and any SQLite databases).
/storage/*
!/storage/.keep
/tmp/storage/*
!/tmp/storage/
!/tmp/storage/.keep

/public/assets

# Ignore key files for decrypting credentials and more.
/config/*.key

# Node modules
node_modules


/app/assets/builds/*
!/app/assets/builds/.keep

.byebug_history

/worktrees/
/.claude/
app/assets/images/Room Rally Logo Pack/

# --- Open Core: exclude pro features layer ---
/app/features/pro/
```

### Step 2: Verify the private `.gitignore` does NOT ignore `app/features/pro/`

Read `.gitignore` and confirm — it should NOT contain `app/features/pro/`. (Already verified: it doesn't.)

### Step 3: Commit

```bash
git add .gitignore-public
git commit -m "feat: add .gitignore-public for open core sync script"
```

---

## Task 4: Write the Sync Script

**Files:**
- Create: `bin/sync-to-public`

### Step 1: Create `bin/sync-to-public`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Sync private RoomRally repo to public open core repo.
# Usage: bin/sync-to-public /path/to/roomrally-public

PRIVATE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
PUBLIC_REPO="${1:-}"

if [ -z "$PUBLIC_REPO" ]; then
  echo "Usage: bin/sync-to-public /path/to/roomrally-public"
  exit 1
fi

if [ ! -d "$PUBLIC_REPO/.git" ]; then
  echo "Error: $PUBLIC_REPO is not a git repository"
  exit 1
fi

echo "Syncing $PRIVATE_REPO → $PUBLIC_REPO"
echo ""

# Rsync private → public, excluding .git and any files the public repo shouldn't have
rsync -av --delete \
  --exclude='.git/' \
  --exclude='.env*' \
  --exclude='config/*.key' \
  "$PRIVATE_REPO/" "$PUBLIC_REPO/"

# Replace .gitignore with the public version
cp "$PRIVATE_REPO/.gitignore-public" "$PUBLIC_REPO/.gitignore"

echo ""
echo "Sync complete. Reviewing changes..."
echo ""

cd "$PUBLIC_REPO"

# Stage everything (the public .gitignore will filter pro features)
git add -A

# Show what changed
if git diff --cached --quiet; then
  echo "No changes to commit."
  exit 0
fi

git diff --cached --stat
echo ""

read -r -p "Commit and push these changes? [y/N] " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  read -r -p "Commit message: " message
  git commit -m "$message"
  git push
  echo "Pushed to public repo."
else
  echo "Aborted. Changes are staged in $PUBLIC_REPO."
fi
```

### Step 2: Make it executable

```bash
chmod +x bin/sync-to-public
```

### Step 3: Commit

```bash
git add bin/sync-to-public
git commit -m "feat: add sync script for private → public repo"
```

---

## Task 5: Audit Migrations

**Files:**
- None to modify (audit only)

### Step 1: Review migration audit results

Based on the research, **no migrations are candidates for `# PRO MIGRATION`**. All 58 migrations are core game/room/player infrastructure. There are no billing, subscription, organization, or pro-specific migrations.

**Potential future pro-gated items** (note for reference, no action needed now):
- `ai_generation_requests` — could be rate-limited per plan
- `prompt_packs`, `trivia_packs`, `category_packs` — could be quantity-limited per plan
- `game_templates` — could be limited to pro users

### Step 2: No commit needed

This task is audit-only. No migrations need the `# PRO MIGRATION` comment.

---

## Task 6: Draft Public README

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
- **Hosted version:** Adds pro features like larger group support, organization accounts, and additional game types

The hosted version relaxes capability limits (audience size, storage, AI requests) and adds features gated behind a subscription. Self-hosters get the full open core with sensible free-tier defaults.

## Architecture

See the `docs/` directory for detailed guides:

- [Architecture](docs/architecture.md) — Request flow, core patterns, concurrency
- [Data Models](docs/data_models.md) — Schema and relationships
- [Client Guide](docs/client_guide.md) — Stage and Hand client architecture
- [Development Guide](docs/development_guide.md) — Contributing, testing, conventions

## License

MIT
```

### Step 2: Run rubocop (in case any Ruby files trigger)

Run: `rubocop -A`

### Step 3: Commit

```bash
git add README.md
git commit -m "docs: rewrite README for open core public repo"
```

---

## Summary of All ENV Vars

| ENV Variable | Required | Description |
|---|---|---|
| `GOOGLE_CLIENT_ID` | Yes | Google OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | Yes | Google OAuth client secret |
| `R2_ACCESS_KEY_ID` | Yes | Cloudflare R2 / S3-compatible access key |
| `R2_SECRET_ACCESS_KEY` | Yes | Cloudflare R2 / S3-compatible secret key |
| `R2_ACCOUNT_ID` | Yes | R2 account ID (for endpoint URL) |
| `OPENAI_API_KEY` | Yes | OpenAI API key |
| `OPENAI_MODEL` | No | OpenAI model name (default: `gpt-4.1-mini`) |
| `SENTRY_DSN` | No | Sentry error tracking DSN |
| `POSTHOG_API_KEY` | No | PostHog analytics API key |
| `POSTHOG_HOST` | No | PostHog host (default: `https://us.i.posthog.com`) |
| `R2_DEV_ASSETS_URL` | No | R2 asset CDN URL (development only) |
| `SMTP_USER_NAME` | No | SMTP username (not currently active) |
| `SMTP_PASSWORD` | No | SMTP password (not currently active) |
