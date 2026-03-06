# Open Core Engine Design

## Context

RoomRally is going open source. The public repo contains the full game platform — all game engines, core infrastructure, self-hosting support. Pro features (higher limits, future game type gating, eventual Stripe billing) live in a private Rails engine at `engines/pro/`, excluded from the public repo via `.gitignore-public`.

This replaces the earlier `app/features/pro/` approach with the industry-standard Rails engine pattern (GitLab EE model).

## Architecture

### How Rails Engines Work

A Rails engine is a mini Rails app inside a gem. When loaded, Rails automatically:
- Autoloads its `app/` directory (models, controllers, concerns, etc.)
- Runs its `config/initializers/`
- Makes its `db/migrate/` migrations available via `rake db:migrate`
- Merges its routes (if any)

The engine lives at `engines/pro/` in the same repo (mono-repo, like GitLab). It's loaded via `gem "roomrally_pro", path: "engines/pro"` in the Gemfile. The public repo's `.gitignore-public` excludes `engines/pro/`, so open-source users never see it. If we ever need repo separation, it's a one-line Gemfile change (`path:` → `git:`).

### Integration Pattern: `PlanResolver`

The main app never hardcodes tier-specific limits. Instead, it asks `PlanResolver`:

```
Main App                          Engine (when loaded)
────────                          ────────────────────
PlanResolver.for(user)  ──────►   prepend overrides .for
  └─ returns free limits          checks user.pro?
                                  returns pro limits if true
                                  calls super (free) if false
```

**Without the engine:** `PlanResolver.for(user)` always returns free-tier limits. The app works standalone.

**With the engine:** The engine prepends onto `PlanResolver` at boot. If `user.pro?`, it returns pro-tier limits. The main app code doesn't change — it always calls `PlanResolver.for(user)` either way.

This uses Ruby's `Module#prepend`, the idiomatic way engines extend core app behavior. The engine's module sits "in front of" the original method — calls hit the engine first, which can call `super` to fall through.

### Plan Limits

| Limit | Free | Pro |
|-------|------|-----|
| `audience_size` | 10 | 50 |
| `ai_requests_per_window` | 10 | 50 |
| `ai_grace_failures` | 3 | 10 |
| `pack_image_limit` | 20 | 50 |

### User Model

A `plan` string column on `users` (default: `"free"`). The main app owns identity and plan status. The engine reads it.

```ruby
# app/models/user.rb
def pro?
  plan == "pro"
end
```

When Stripe comes later, a webhook sets `user.plan = "pro"` and everything downstream just works.

### Engine Structure

```
engines/pro/
├── app/
│   └── models/
│       └── concerns/
│           └── roomrally_pro/
│               └── plan_limits.rb      # Defines pro-tier limits, prepends PlanResolver
├── config/
│   └── initializers/
│       └── plan_resolver.rb            # Overrides PlanResolver.for to check user.pro?
├── lib/
│   ├── roomrally_pro.rb                # Gem entry point
│   └── roomrally_pro/
│       └── engine.rb                   # Rails::Engine subclass
├── roomrally_pro.gemspec
├── Gemfile
└── README.md
```

## What's In Scope

- Engine skeleton with proper Rails engine boilerplate
- `PlanResolver` service in main app (replaces `PlanDefaults`)
- `plan` column on User with `pro?` method
- Refactor existing AI limit constants in User to read from `PlanResolver`
- Delete `app/features/` (superseded by engine)
- Update `.gitignore-public` to exclude `engines/pro/`
- README rewrite for public repo

## What's NOT In Scope

- Game type gating (no pro-only game type exists yet)
- Stripe / billing
- UI changes (upgrade prompts, pricing page)
- Engine routes or controllers
- Audience size enforcement (the concept doesn't exist in the app yet — just defining the limit)

## Decisions

- **Engine in-repo** (`engines/pro/`), not separate repo. Mono-repo allows atomic commits. GitLab does this.
- **Main app owns plan status** (column on User), engine reads it. Industry standard — identity belongs to core.
- **`prepend` for decoration**, not monkey-patching or callbacks. Idiomatic Ruby, traceable call chain.
- **All current users treated as free.** Pro is opt-in via column change. No migration sets anyone to pro.
