# Design: Create Content Pack from Game Template Form

**Date:** 2026-02-20
**Status:** Approved

## Problem

Users creating a game template must select from existing content packs, but there is no path to create a new pack from that screen. They must navigate away, losing any in-progress form state, create the pack, and return to re-enter everything.

Additionally, `CategoryPack` has a model but no controller, routes, or views — users cannot create category packs at all today.

## Solution Overview

1. Add a `+ Create a new [pack type]` link below each pack dropdown on the game template form
2. Clicking the link saves current form state to `sessionStorage` then navigates to pack creation with a `return_to` param
3. After the pack is created, the pack controller redirects back to the template form with `?new_pack_id=<id>` appended
4. The Stimulus controller restores saved form state and auto-selects the new pack
5. Build the missing `CategoryPacksController` with full CRUD and views

## Components

### 1. Game Template Form (`_form.html.erb`)

Below each pack `<select>`, add a "Create a new X" link:

```
[ Select a trivia pack ▾ ]
+ Create a new trivia pack
```

The link is shown/hidden in sync with the game type selector (same as the dropdown). The link includes:
- `href` pointing to the relevant pack creation URL with `?return_to=<current_url>`
- `data-action="click->game-template-form#saveAndNavigate"`

### 2. Stimulus Controller (`game_template_form_controller.js`)

Extend the existing controller with two behaviors:

**`saveAndNavigate(event)`** — called when a "Create new pack" link is clicked:
- Serialize all form field values (name, game_type, all pack IDs, all settings)
- Store in `sessionStorage` under key `game_template_draft_<url_path>` (path-scoped to avoid cross-template bleed)
- Allow the link's natural navigation to proceed

**`connect()` — restore on return:**
- Check URL params for `new_pack_id` and `new_pack_type`
- Check `sessionStorage` for a draft matching the current path
- If draft found: restore all form field values
- If `new_pack_id` found: after restoring, select that pack in the appropriate dropdown
- Clear sessionStorage after successful restore

### 3. Pack Controllers: `return_to` Support

Add to `PromptPacksController`, `TriviaPacksController`, and new `CategoryPacksController`:

**`new` action:** store `params[:return_to]` in `@return_to` for use in the form.

**Form:** include a hidden field `<input type="hidden" name="return_to" value="<%= @return_to %>">` so the param survives form submission on validation errors.

**`create` action:** after successful save, check `params[:return_to]`:
```ruby
if valid_return_to?(params[:return_to])
  uri = URI.parse(params[:return_to])
  existing_params = URI.decode_www_form(uri.query || "")
  existing_params << ["new_pack_id", @pack.id.to_s]
  uri.query = URI.encode_www_form(existing_params)
  redirect_to uri.to_s, notice: "Pack created."
else
  redirect_to packs_path, notice: "Pack created."
end
```

**Security validation:**
```ruby
def valid_return_to?(url)
  uri = URI.parse(url)
  !uri.host && uri.path.start_with?("/")
rescue URI::InvalidURIError
  false
end
```

- `!uri.host` ensures the URL is always relative (no external host — not even our own domain in absolute form, which is unnecessary and restricts attack surface)
- `uri.path.start_with?("/")` rejects empty strings and fragment-only values
- Together these make an open redirect impossible

### 4. CategoryPacksController (new)

Full CRUD controller modeled on `PromptPacksController`:

```ruby
class CategoryPacksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_owned_category_pack, only: %i[edit update destroy]

  def index    # user's packs + global system packs
  def show
  def new      # CategoryPack.new + build one category
  def create   # with return_to support
  def edit
  def update   # with return_to support
  def destroy
end
```

Permitted params: `name`, `status`, `categories_attributes: [:id, :name, :_destroy]`

### 5. CategoryPack Views

Two-column layout (matching prompt_packs style):

- **Left column:** pack name, status (draft/live), Save + Cancel buttons
- **Right column:** list of category name fields, "Add Category" button, remove per item, bulk import (one name per line)

Reuses the existing `content-editor` Stimulus controller — categories use `name` field instead of `body`.

Files to create:
- `app/views/category_packs/index.html.erb`
- `app/views/category_packs/new.html.erb`
- `app/views/category_packs/edit.html.erb`
- `app/views/category_packs/show.html.erb`
- `app/views/category_packs/_form.html.erb`
- `app/views/category_packs/_card.html.erb`

### 6. Routes

Add to `config/routes.rb`:
```ruby
resources :category_packs
```

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| User clicks "Create new pack" with no name entered | Form state saved as-is (empty name). Template form restores with empty name on return — user must fill it in before saving. |
| Pack creation fails validation | Hidden `return_to` field persists in the re-rendered form. sessionStorage remains. User fixes errors and resubmits. |
| User abandons pack creation (hits Cancel/back) | sessionStorage only cleared on successful return (when `?new_pack_id=` is present). Draft is restored if they return manually. |
| User has multiple tabs open | sessionStorage is tab-scoped in most browsers. Each tab has independent draft state. No cross-tab interference. |
| Invalid or external `return_to` | `valid_return_to?` rejects it. Pack controller falls back to normal packs index redirect. |
| URL already has query params | `new_pack_id` is appended using `URI.encode_www_form` — not string concatenation. |

## Testing

### Request Specs (`spec/requests/`)

**`CategoryPacksController`:** standard CRUD coverage — new, create (success + validation failure), edit, update, destroy, index.

**`return_to` redirect behavior** (applies to all three pack controllers):
- Valid `return_to` → redirects with `?new_pack_id=` appended
- External URL → redirects to pack index (no open redirect)
- Protocol-relative URL (`//evil.com`) → rejected, redirects to pack index
- Malformed URI → rescued, redirects to pack index

### System Spec (`spec/system/game_templates/`)

**`create_pack_from_template_spec.rb`** — full round-trip:
1. User visits new template form, selects game type, fills in name
2. Clicks "Create a new trivia pack"
3. Creates the pack with a name
4. Lands back on template form with name restored and new pack auto-selected
5. Submits and verifies template saved correctly

## What's Out of Scope

- Draft/live status for game templates (separate feature)
- The `CategoryPacks` index is not linked from the main nav yet (same as `PromptPacks` / `TriviaPacks` — users reach it via the "manage" link once that exists)
