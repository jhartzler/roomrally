# Feature Flags Design

**Date:** 2026-04-08  
**Status:** Approved

## Problem

New games and features (pack sharing, new pack editor, etc.) need to ship in iterations. The codebase needs a way to hide in-progress work from users until it's ready, and to soft-launch features without a code deploy. An audit trail of when flags were toggled is also required for operational awareness.

## Scope

- Global on/off toggles (no per-user targeting, no plan gating)
- Runtime control via admin UI (no deploy required to flip a flag)
- Audit log of every toggle
- Works for both whole game types and smaller UI features

## Data Model

### `features` table

| Column    | Type    | Constraints                  |
|-----------|---------|------------------------------|
| `name`    | string  | not null, unique, primary key |
| `enabled` | boolean | not null, default false      |

No timestamps — the `feature_events` table is the historical record.

### `feature_events` table

| Column         | Type     | Constraints  |
|----------------|----------|--------------|
| `feature_name` | string   | not null     |
| `enabled`      | boolean  | not null     |
| `created_at`   | datetime | not null     |

Append-only. Never updated or deleted. Records the new state after each toggle.

## Feature Model

Feature names are declared as constants — not discovered dynamically. This makes every flag visible in one place and catches typos at development time.

```ruby
class Feature < ApplicationRecord
  FEATURES = %i[
    write_and_vote
    speed_trivia
    category_list
  ].freeze

  has_many :feature_events, foreign_key: :feature_name, primary_key: :name

  def self.enabled?(name)
    if Rails.env.local? && !FEATURES.include?(name.to_sym)
      raise ArgumentError, "Unknown feature flag: #{name}. Add it to Feature::FEATURES first."
    end

    Rails.cache.fetch("feature/#{name}", expires_in: 30.seconds) do
      find_by(name: name)&.enabled? || false
    end
  rescue => e
    Rails.logger.error("Feature flag lookup failed for #{name}: #{e.message}")
    false
  end
end
```

**Error handling:**
- Unknown flag name in dev/test → raises `ArgumentError` immediately (catches typos before they ship)
- Unknown flag name in prod → degrades to `false` (feature off, no crash)
- DB/cache unavailability → logs error, degrades to `false`

**Caching:** 30-second TTL via `Rails.cache` (backed by Redis, already in the stack). The admin toggle explicitly expires the cache entry so changes take effect immediately rather than waiting for TTL expiry.

## Boot-Time Sync

An initializer syncs `Feature::FEATURES` to the DB on every boot. Missing rows are created (default disabled). Existing rows are not touched.

```ruby
# config/initializers/features.rb
Rails.application.config.after_initialize do
  next unless ActiveRecord::Base.connection.table_exists?(:features)
  Feature::FEATURES.each do |name|
    Feature.find_or_create_by!(name: name) { |f| f.enabled = false }
  end
end
```

**Workflow for adding a new flag:**
1. Add the symbol to `Feature::FEATURES`
2. Deploy — the initializer creates the DB row (disabled)
3. Toggle it on via the admin UI when ready

## Admin UI

Mounted under the existing `Admin::BaseController` (authentication already handled via `current_user.admin?`).

**Routes:**
```ruby
namespace :admin do
  resources :features, only: [:index] do
    member { patch :toggle }
  end
end
```

**Controller:**
```ruby
class Admin::FeaturesController < Admin::BaseController
  def index
    @features = Feature.order(:name).includes(:feature_events)
  end

  def toggle
    @feature = Feature.find_by!(name: params[:id])
    ActiveRecord::Base.transaction do
      @feature.update!(enabled: !@feature.enabled)
      FeatureEvent.create!(feature_name: @feature.name, enabled: @feature.enabled)
    end
    Rails.cache.delete("feature/#{@feature.name}")
    redirect_to admin_features_path, notice: "#{@feature.name} turned #{@feature.enabled? ? 'on' : 'off'}."
  end
end
```

**Index view** shows per flag:
- Humanized flag name
- Current ON/OFF state (clear visual indicator)
- Toggle button (no confirmation dialog — the audit log is the undo record)
- Last 3–5 events inline: "ON · Apr 3 2:14pm", "OFF · Apr 1 9:00am"

No separate new/edit/delete UI. Flags only exist via the `FEATURES` constant — the admin UI is purely for toggling state and viewing history.

## Usage Patterns

### Gating a game type

Game type flags use underscored versions of the game type string: `write_and_vote`, `speed_trivia`, `category_list`.

```ruby
# Room model
def self.available_game_types
  GAME_TYPES.select { |type| Feature.enabled?(type.underscore.gsub(" ", "_").to_sym) }
end

validates :game_type, inclusion: { in: -> (_) { Room.available_game_types } }
```

The lobby UI uses `Room.available_game_types` to render only enabled options. The model validation enforces this server-side as well.

**Existing games ship enabled by default** — their seed data sets `enabled: true`. New games ship disabled.

> **Note:** Per-game-type flags are pragmatic for now but may become noise as the game catalog grows and most games are permanently enabled. A future alternative is a `released` boolean on the game registry entry itself, which would be less indirection. Revisit when there are 5+ shipped games.

### Gating smaller features

In views:
```erb
<% if Feature.enabled?(:pack_sharing) %>
  <%= render "packs/share_button", pack: @pack %>
<% end %>
```

In controllers:
```ruby
def share
  return head :forbidden unless Feature.enabled?(:pack_sharing)
  # ...
end
```

## What Is Not In Scope

- Per-user targeting (no beta access to specific accounts)
- Plan-based gating (no free vs. pro distinction currently)
- Percentage rollouts
- A/B testing
- Notes on toggle events (adds friction with low value)

These can be layered on later — the `Feature` model is a natural extension point. The most likely migration path if per-user targeting is ever needed is replacing `Feature.enabled?` calls with Flipper (which uses the same boolean-check API), keeping all call sites intact.

## Files to Create/Modify

- `db/migrate/..._create_features.rb`
- `db/migrate/..._create_feature_events.rb`
- `app/models/feature.rb`
- `app/models/feature_event.rb`
- `config/initializers/features.rb`
- `app/controllers/admin/features_controller.rb`
- `app/views/admin/features/index.html.erb`
- `config/routes.rb` — add admin features routes
- `app/models/room.rb` — add `available_game_types` + update validation
- `db/seeds.rb` — enable existing game type flags
