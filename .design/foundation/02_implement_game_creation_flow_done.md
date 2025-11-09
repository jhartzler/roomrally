# Ticket 02: Implement Room Creation and Homepage

## Description
Create the homepage and the flow for a user to create a new room. This will be the primary entry point for the host.

- **Routing:**
  - The root path (`/`) should route to `home#index`.

- **Homepage (`home#index` view):**
  - Should contain a "Create Room" button.
  - Should contain a form to enter a 4-letter room code to join an existing room.

- **Room Creation (`rooms#create` action):**
  - The "Create Room" button should POST to `rooms#create`.
  - This action will create a new `Room` record, which automatically gets a unique `room_code`.
  - After creation, the user should be redirected to the page where they can join as the first player (the host). A good URL for this would be `/rooms/ABCD/join`, where `ABCD` is the new room code.

## Acceptance Criteria
- A user can visit the root path of the application.
- The homepage displays a "Create Room" button and a form to enter a room code.
- Clicking "Create Room" successfully creates a new `room` record in the database.
- After room creation, the user is redirected to the join page for the newly created game room.
- A system test is written to verify this flow.
