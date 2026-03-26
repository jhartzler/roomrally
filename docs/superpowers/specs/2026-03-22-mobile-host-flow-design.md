# Mobile Host Flow Design

## Problem

When a guest user creates a room on their phone (the most common path), they're redirected to the Stage view — a projection-oriented screen designed for TVs and laptops. They see a mobile warning dialog, dismiss it, get stuck on a phone-sized stage, and can't figure out how to start the game because someone needs to "Claim Host" from a separate device's hand view. The game works great once people get in; the entire problem is the setup flow.

## Solution

Rework room creation so that phone users become a player and host automatically, land on the Hand view with clear instructions to open the Stage on a big screen, and can manage the game entirely from their phone.

## Design

### Flow Overview

**Current guest flow (broken on mobile):**
1. User picks game type on `/host`
2. `RoomsController#create` → redirect to Stage (`/rooms/ABCD/stage`)
3. User sees mobile warning, dismisses it
4. User is stuck on phone-sized Stage with no way to start the game
5. Someone must join via hand view and "Claim Host"

**New mobile flow:**
1. User picks game type on `/host`
2. `RoomsController#create` detects mobile UA → redirect to `/rooms/ABCD/mobile_host`
3. `MobileHostsController#show` renders name entry form
4. `MobileHostsController#create` creates Player, assigns as room host, redirects to hand view
5. Hand view lobby shows Stage URL banner: "Open roomrally.app/ABCD on a big screen"
6. Host manages game from hand view (existing host controls work as-is)

**Desktop guest flow (unchanged):**
1. `RoomsController#create` → redirect to Stage (existing behavior)
2. Players join on phones, one claims host

**Logged-in facilitator flow (unchanged):**
1. `RoomsController#create` → redirect to Backstage (existing behavior)

### New Routes

```ruby
# Inside rooms resource block
resources :rooms, param: :code do
  resource :mobile_host, only: [:show, :create]
  # ... existing routes ...
end

# Short URL for easy Stage access — place immediately before the
# *unmatched catch-all route. The regex constraint prevents collisions
# with named routes like /host, /play, /privacy, etc.
get "/:code", to: "shortcodes#show", constraints: { code: /[A-Za-z0-9]{4}/ }
```

The shortcode route uses a regex constraint matching exactly 4 alphanumeric characters (case-insensitive). The controller upcases the code before lookup, so `roomrally.app/abcd` works too. Room codes are `[A-NP-Z0-9]` (4 chars, "O" excluded), so this won't collide with any existing named routes.

### MobileHostsController

```
GET  /rooms/:code/mobile_host  → MobileHostsController#show
POST /rooms/:code/mobile_host  → MobileHostsController#create
```

**`show` action:**
- Looks up room by code
- Guards: redirects away if room already has a host or a facilitator (User)
- Renders a name entry form (similar to `players/new.html.erb` but with "You're hosting!" context)

**`create` action:**
- Looks up room by code
- Guards: same as show — redirects if room already has host or facilitator
- Creates a Player record:
  - `session_id` from `session[:player_session_id]` (generates UUID if not present — must set `session[:player_session_id]` in the same request so the redirect to hand view resolves `current_player` correctly; same pattern as `PlayersController#create` lines 48-49)
  - `status: :active`
  - `name` from form params
- Assigns player as `room.host`
- Broadcasts player joined + host change
- Tracks `player_joined` analytics event with `mobile_host: true` property
- Redirects to `room_hand_path(room)` (room code is in URL via `param: :code`)

**Edge cases:**
- If session already has a player in this room: redirect to hand view (they've already joined)
- If room already has a host by the time they submit: redirect to hand view with alert
- If room has a facilitator: redirect to join page (they shouldn't be on this path)

### ShortcodesController

```
GET /:code → ShortcodesController#show
```

**`show` action:**
- Upcases `params[:code]` before lookup (handles `roomrally.app/abcd`)
- Looks up Room by code
- Redirects to `room_stage_path(room)`
- If room not found: redirects to root with alert

This gives hosts a simple URL to display: `roomrally.app/ABCD`. The route constraint (`/[A-Z0-9]{4}/`) prevents collisions with existing routes like `/host`, `/play`, `/privacy`, etc.

### RoomsController#create Change

```ruby
def create
  room = Room.create!(room_params)
  Analytics.track(...)

  if current_user
    room.update(user: current_user)
    redirect_to room_backstage_path(room)
  elsif mobile_request?
    redirect_to room_mobile_host_path(room)
  else
    redirect_to room_stage_path(room)
  end
end

private

def mobile_request?
  request.user_agent&.match?(/Mobile|Android|iPhone|iPod/i)
end
```

Tablets are intentionally treated as desktop — their screens are large enough for the Stage view. The regex targets phone-specific UA strings only.

If UA detection gets it wrong:
- Desktop user sent to mobile host setup → they enter a name and become host. No harm.
- Mobile user sent to Stage → existing Claim Host flow still works as fallback.

### Hand View — Stage URL Banner

Added to `_lobby.html.erb`, visible when `player == room.host`:

```erb
<% if player == room.host %>
  <div class="..." data-controller="clipboard" data-clipboard-text-value="<%= request.base_url %>/<%= room.code %>">
    <h3>Show the Stage on a big screen</h3>
    <p class="text-2xl font-mono font-bold"><%= request.base_url %>/<%= room.code %></p>
    <button data-action="click->clipboard#copy" data-clipboard-target="button">
      Copy Link
    </button>
    <p class="text-sm">Open this link on a laptop, TV, or any big screen</p>
  </div>
<% end %>
```

**Lifecycle:**
- Visible during lobby phase only
- Disappears naturally when game starts (lobby partial is replaced by game hand partial via Turbo Stream broadcast)
- No manual dismiss button, no connection tracking
- Positioned above existing host controls

**Known limitation:** If host is reassigned during lobby via `reassign_host`, the banner won't update for either player until page refresh. `broadcast_host_change` only updates `player-list` and `host-controls` targets, not the full lobby. This is acceptable for v1 — host reassignment in lobby is rare, and the primary mobile host flow (create room → become host → land on hand view) always gets a fresh page load.

### Clipboard Stimulus Controller

New `clipboard_controller.js`:

```javascript
// data-controller="clipboard"
// data-clipboard-text-value="https://..."
// data-action="click->clipboard#copy"
// data-clipboard-target="button"

static values = { text: String }
static targets = ["button"]

copy() {
  navigator.clipboard.writeText(this.textValue)
  const original = this.buttonTarget.textContent
  this.buttonTarget.textContent = "Copied!"
  setTimeout(() => { this.buttonTarget.textContent = original }, 2000)
}
```

### Mobile Host Setup View

`mobile_hosts/show.html.erb` — A focused name entry form:

- Room code displayed at top for context
- "You're hosting [Game Display Name]!" heading
- Name text field (same validation as player join: required, max length)
- "Let's Go" submit button
- Brief explanation: "You'll be the host — pick a name so players know who's running the show"
- Styled consistently with the existing join page (`players/new.html.erb`)

### What Stays Unchanged

- **Logged-in facilitator flow** — Still redirects to backstage
- **PlayersController** — Untouched; regular players join via `/rooms/ABCD/join`
- **Claim Host** — Stays in `_lobby.html.erb` as fallback for edge cases
- **Stage view** — No changes; already shows room code, QR code, player grid in lobby
- **Game service layer** — No changes; host is just a Player on Room, which already works
- **Hand view host controls** — `_host_controls.html.erb` already handles `player == room.host`
- **GameBroadcaster** — Existing `broadcast_player_joined` and `broadcast_host_change` methods used as-is

**Note:** `MobileHostsController` does NOT include `GameHostAuthorization` or `RendersHand` — it creates a player, it doesn't perform game actions. The mobile host counts toward the player minimum for `enough_players?` checks, which is correct (they're a real player).

### Files Changed

| File | Change |
|------|--------|
| `config/routes.rb` | Add `mobile_host` resource, shortcode route |
| `app/controllers/rooms_controller.rb` | Add `mobile_request?` helper, branch in `create` |
| `app/controllers/mobile_hosts_controller.rb` | New — `show` and `create` actions |
| `app/controllers/shortcodes_controller.rb` | New — `show` action (redirect to stage) |
| `app/views/mobile_hosts/show.html.erb` | New — name entry form |
| `app/views/rooms/_lobby.html.erb` | Add Stage URL banner for host |
| `app/javascript/controllers/clipboard_controller.js` | New — copy-to-clipboard |

### Stretch Goals (not in initial build)

1. **Web Share API** — Add share button alongside copy button using `navigator.share()` for AirDrop/text/email. Feature-detect and hide on unsupported browsers.
2. **Client-side fallback detection** — If server UA check misses a mobile device, a Stimulus controller on the Stage view checks screen width and offers to redirect to mobile host setup.
3. **Live Stage connection indicator** — Hand view banner updates to "Stage is live!" when the Stage view connects via Action Cable. Requires tracking Stage subscriptions.

### Testing Strategy

**System specs (most critical):**
- Mobile room creation → lands on mobile host setup (not Stage)
- Name entry → becomes player + host → lands on hand view with stage URL banner
- Desktop room creation → lands on Stage (existing behavior unchanged)
- Logged-in user → lands on backstage (existing behavior unchanged)
- Shortcode route (`/ABCD`) → redirects to stage
- Edge case: room already has host → mobile host setup redirects away
- Edge case: session already has player → redirects to hand view
- Game start → stage URL banner disappears

**Controller specs:**
- `MobileHostsController` — show/create with various guard conditions
- `ShortcodesController` — valid code, invalid code, nonexistent room
- `RoomsController#create` — UA-based redirect branching
