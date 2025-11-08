# Ticket 04: Setup Action Cable Channel for Real-Time Communication

## Description
Create the `GameChannel` that will handle all real-time WebSocket communication for a specific game room. This is the backbone of the real-time updates.

- **Channel Generation:**
  - Generate a `GameChannel` using `bin/rails generate channel`.

- **Subscription Logic:**
  - In the `subscribed` method of `GameChannel`, find the `Game` using the `room_code` from the incoming params.
  - If the game is found, subscribe the client to a unique stream for that game (e.g., `stream_for @game`).
  - If the game is not found, reject the subscription.

- **Client-Side Connection:**
  - Create a Stimulus controller (`game-connection-controller.js`) to handle the client-side logic of connecting to the channel.
  - This controller should be placed on both the TV and Phone view layouts.
  - It should read the `room_code` from a data attribute and use it to initialize the Action Cable subscription.

## Acceptance Criteria
- A `GameChannel.rb` file exists.
- A `game-connection-controller.js` Stimulus controller exists.
- When a user loads a game page (TV or Phone), the client successfully subscribes to the `GameChannel` for that specific room.
- The Rails server log shows a successful subscription for the client.
- An integration test (RSpec) is written to verify that a client can successfully subscribe to the channel.
