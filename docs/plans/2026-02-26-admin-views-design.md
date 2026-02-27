# Admin Views Design

**Date:** 2026-02-26
**Status:** Approved

## Problem

As Room Rally gains users, occasional manual interventions are needed from a phone (e.g. resetting a user's AI prompt limit). No admin infrastructure currently exists.

## Decisions

- **Simple `/admin` namespace** — no gem dependencies, follows existing Rails patterns, full control over mobile UX
- **Boolean `admin` flag on User** — YAGNI; roles array unnecessary until there are distinct admin roles
- **Preserve AI request audit trail on reset** — set `counts_against_limit = false` on the user's current-window requests rather than deleting records

## Architecture

### Auth

Add `admin: boolean, default: false` to `users` table.

`Admin::BaseController < ApplicationController`:
```ruby
before_action :authenticate_user!
before_action :require_admin!

private

def require_admin!
  redirect_to root_path, alert: "Not authorized" unless current_user&.admin?
end
```

### Routes

```ruby
namespace :admin do
  root to: "users#index"
  resources :users, only: [:index, :show] do
    member do
      post :reset_ai_limit
    end
  end
end
```

### Layout

`layouts/admin.html.erb` — inherits Tailwind base, no game chrome. Simple mobile-first header with "Admin" badge and back link. Admin views use normal `px`/`rem` sizing (not vh-based) since they scroll like a regular web page on phone.

## Screens

### `/admin/users` — User List

Mobile-first card layout. Each card shows:
- Name + email
- AI requests used this window (e.g. "7 / 10 used")
- "Reset AI Limit" inline button (visible only when used > 0)
- Tap → user detail page

Ordered by most recent signup or most AI usage (most actionable first).

### `/admin/users/:id` — User Detail

Three stat cards:

**AI Usage**
- Requests used this window / 10
- Remaining requests
- Window resets at [time]
- Grace failures used
- Prominent "Reset AI Limit" button (POST, redirects back with flash)

**Engagement**
- Signup date
- Rooms created (total)
- Last room created at

**Packs**
- Prompt packs: X (Y live, Z draft)
- Trivia packs: X (Y live, Z draft)
- Category packs: X (Y live, Z draft)

*Note: Games "played as player" cannot be tracked — the Player model is session-based with no user association.*

## Reset AI Limit Implementation

```ruby
# Admin::UsersController
def reset_ai_limit
  @user = User.find(params[:id])
  @user.ai_generation_requests
       .where(counts_against_limit: true)
       .where("created_at > ?", User::AI_WINDOW_HOURS.hours.ago)
       .update_all(counts_against_limit: false)
  redirect_to admin_user_path(@user), notice: "AI limit reset for #{@user.name}"
end
```

This reuses the existing `counts_against_limit` flag already respected by `ai_requests_remaining`. No model changes needed beyond the migration.

## Stats Queries

All computable from existing associations — no new columns needed:

```ruby
# AI usage
user.ai_generation_requests.where("created_at > ?", 8.hours.ago).where(counts_against_limit: true).count

# Rooms created
user.rooms.count
user.rooms.maximum(:created_at)  # last activity proxy

# Pack counts
user.prompt_packs.count
user.trivia_packs.where(status: :live).count
# etc.
```

Use `includes` where needed to avoid N+1 on the index page.

## Out of Scope (Future)

- Active rooms monitor / live game view
- Pack moderation (flag/promote user packs to global)
- AI request audit log
- Analytics dashboard
- Disabling user accounts
