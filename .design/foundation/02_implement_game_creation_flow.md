# Ticket 02: Implement Game Creation and Homepage

## Description
Create the homepage and the flow for a user to create a new game. This will be the primary entry point for the host.

- **Routing:**
  - The root path (`/`) should route to `home#index`.

- **Homepage (`home#index` view):**
  - Should contain a "Create Game" button.
  - Should contain a form to enter a 4-letter room code to join an existing game.

- **Game Creation (`games#create` action):**
  - The "Create Game" button should POST to `games#create`.
  - This action will create a new `Game` record, which automatically gets a unique `room_code`.
  - After creation, the user should be redirected to the page where they can join as the first player (the host). A good URL for this would be `/games/ABCD/join`, where `ABCD` is the new room code.

## Acceptance Criteria
- A user can visit the root path of the application.
- The homepage displays a "Create Game" button and a form to enter a room code.
- Clicking "Create Game" successfully creates a new `Game` record in the database.
- After game creation, the user is redirected to the join page for the newly created game room.
- A system test is written to verify this flow.
