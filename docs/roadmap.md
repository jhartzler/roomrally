# Implementation Roadmap

## Phase 1: Foundation
**Goal**: Get a basic lobby working with real-time connections.
- **Tasks**:
  1. Project setup (Rails, gems, RSpec, RuboCop).
  2. Core models (`Room`, `Player`) with TDD.
  3. Basic controllers and views for creating/joining a room.
  4. Action Cable `GameChannel` setup.
  5. Lobby views for Stage and Hand.
  6. System test for multiple players joining a lobby.
- **Definition of Done**: Two people can join a room and see each other in real-time.

## Phase 2: First Complete Game Loop
**Goal**: Play one round of WriteAndVote from start to finish.
- **Tasks**:
  1. `Round` and `Prompt` models.
  2. `WriteAndVote::Answer` and `WriteAndVote::Vote` models.
  3. `WriteAndVote::Logic` to handle submissions and votes.
  4. Event system setup (Wisper) with `ScoreListener` and `BroadcastListener`.
  5. `TimerService` using Sidekiq.
  6. Views for all game phases (prompting, voting, results).
  7. System test for a complete round with scoring.
- **Definition of Done**: A single round of WriteAndVote can be played, and scores are awarded correctly.

## Phase 3: Multiple Rounds & Game Completion
**Goal**: Play a complete, multi-round game.
- **Tasks**:
  1. Logic for transitioning between rounds and ending the game.
  2. Final scores screen showing the winner.
  3. Polish UI, add loading states and error messages.
  4. System test for a full 3-round game.
- **Definition of Done**: A complete 3-round game can be played from start to finish.

## Phase 4: Polish & Edge Cases
**Goal**: Handle edge cases and improve UX.
- **Tasks**:
  1. Handle timer expirations, player disconnections.
  2. Implement player reconnection.
  3. Add host controls (e.g., skip phase).
  4. Improve mobile views and add Stage fullscreen mode.
  5. Seed more prompts.
- **Definition of Done**: The game is robust and handles common edge cases gracefully.

## Phase 5: Second Game Type
**Goal**: Prove the architecture is extensible by adding a new game.
- **Ideas for future games**:
  - **WriteAndVote**: The initial game (formerly QuipKit).
  - **DrawAndWrite**: A "telephone" game with drawing and writing.
  - **GuessTheSpy**: A social deduction game.
  - **GuessTheAnswer**: A trivia/facts game.
- **Tasks**:
  1. Design the second game type (e.g., DrawAndWrite).
  2. Implement new game logic with TDD.
  3. Add to the game type registry.
  4. Create game-specific views.
  5. System test for the new game type, ensuring WriteAndVote still works.
- **Definition of Done**: Two distinct game types both work without modifying core components.

## Future Enhancements (Post-MVP)
- Custom prompt packs
- Player accounts (track stats across games)
- Achievements and badges
- Custom room passwords
- Spectator mode
