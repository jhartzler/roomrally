# Host/Join UX Redesign — Design Doc
**Date:** 2026-02-23

## Problem

Alpha users are confused because `/play` combines the host (create room) and player (join room) flows on a single page. Users who create a room on their phone without being logged in get redirected to the stage view — their phone becomes the shared display, which is wrong. There is also no navigation wayfinding on the landing page to help users self-identify as host vs. player.

## Goals

1. Make the host and player entry points unambiguous from the landing page forward
2. Prevent mobile users from accidentally creating a room and becoming the stage
3. Keep the implementation simple — no new auth, no new game logic

## Out of Scope

- `/tv` (stage transfer from phone to TV) — future feature; modal is designed to accommodate it later

---

## Design

### 1. Routes & Controllers

Add a new `/host` route and thin controller. Strip `/play` to join-only.

```
GET  /host  →  hosts#index     (new controller, renders create-room form)
GET  /play  →  home#index      (existing, stripped to join-only)
root        →  pages#landing   (no change)
```

`HostsController` has a single `index` action with no logic — the form still POSTs to `rooms_path` as today. No change to `RoomsController` redirect logic: logged-out creators go to stage (correct for desktop use), logged-in creators go to backstage. The mobile modal is the intervention point.

### 2. Landing Page Nav Bar

Replace the current centered logo header with a full-width sticky nav:

```
[ RoomRally logo ]        [ Join a Game ]  [ Host a Game ]  [ Login / Dashboard ]
```

- Logo left-aligned, action links right-aligned
- "Join a Game" → `/play` (secondary/ghost style)
- "Host a Game" → `/host` (primary, orange-filled)
- Right slot: logged-out → "Login with Google" (small, low-key); logged-in → "Dashboard" + user name
- Sticky on scroll
- On mobile: logo left, "Join" and "Host" buttons always visible (no hamburger hiding the key actions)

The hero section CTA ("Host or Play for Free" → `/play`) is replaced with two side-by-side buttons — **"Host a Game"** and **"Join a Game"** — mirroring nav language so the page reinforces the same mental model top to bottom.

### 3. /play (Join-Only)

Stripped to a single job: entering a room code.

- Remove create-room form entirely
- Remove login/dashboard block (players don't need accounts)
- Keep the logo, megaphone, and welcoming tone
- Room code input auto-focuses on page load
- Quiet "Want to host? → roomrally.app/host" link at the bottom (escape hatch, not a CTA)

### 4. /host (Create Room + Mobile Modal)

The create-room form moves here unchanged. A Stimulus controller (`mobile-warning`) provides a mobile speed bump.

**Modal trigger conditions (both must be true):**
- `window.innerWidth <= 768`
- Server passes `data-mobile-warning-logged-in-value="false"` (user not logged in)

Logged-in mobile users skip the modal — they land on backstage after creating, so the phone-as-stage problem doesn't apply.

**Modal behavior:**
- Shows immediately on `connect()` if conditions met
- Native `<dialog>` element, Stimulus-controlled
- No X button, no backdrop dismiss, no Escape key dismiss — user must make an explicit choice

**Modal copy:**

> **Wait — are you joining or hosting?**
>
> **I want to play**
> [Go to Join Screen] → navigates to `/play`
>
> **I am the host**
> RoomRally is designed to be displayed on a TV or laptop for the room to see. If you create a game here, this phone will become the main display.
> [Continue Anyway] → dismisses modal, user proceeds with form

**Future `/tv` upgrade:** When `/tv` is built, add a third option to the modal — "Transfer to your TV at roomrally.app/tv." The modal structure does not need to change.

---

## What Is Not Changing

- `RoomsController` redirect logic (logged-out → stage, logged-in → backstage)
- Game creation form fields and behavior
- Player join flow beyond stripping it to its own page
- Authentication system

---

## Testing Notes

- System spec: mobile-width browser visits `/host` as logged-out user → modal appears
- System spec: modal "Go to Join Screen" → lands on `/play`
- System spec: modal "Continue Anyway" → modal dismissed, form visible
- System spec: logged-in user visits `/host` on mobile → no modal
- System spec: desktop user visits `/host` as logged-out → no modal
- Unit: `/play` no longer renders create-room form
- Visual: landing page nav renders correctly at mobile and desktop breakpoints
