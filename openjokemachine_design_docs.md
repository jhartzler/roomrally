# OpenJokeMachine Design Documentation

## Table of Contents
1. [Project Overview](#01-project-overview)
2. [Architecture Principles](#02-architecture-principles)
3. [Data Models](#03-data-models)
4. [Communication Layer](#04-communication-layer)
5. [Game Logic Layer](#05-game-logic)
6. [Client Architecture](#06-client-architecture)
7. [Timer Service](#07-timer-service)
8. [Development Practices](#08-development-practices)
9. [Implementation Roadmap](#09-implementation-roadmap)

---

## 01-project-overview

# Project Overview

## Goal
Create a Rails-based, open-source, real-time party game platform inspired by Jackbox Games.

## Core Technology Stack
- **Backend**: Ruby on Rails 8+
- **Real-time**: Action Cable (WebSockets)
- **Frontend**: Hotwire (Turbo + Stimulus)
- **Background Jobs**: Sidekiq
- **Database**: PostgreSQL
- **Cache/Pub-Sub**: Redis
- **Testing**: RSpec, Capybara
- **Code Quality**: RuboCop

## Core Experience
- **Main Screen (TV)**: Displays the game state to all players
- **Controllers (Phones/Tablets/Laptops)**: Players use personal devices to join a room and interact
- **Room-Based**: Games are accessed via 4-letter room codes (e.g., "ABCD")
- **Session Length**: 10-15 minutes per game
- **Target Audience**: Groups of friends playing together in the same physical space

## MVP Features

### Game Creation & Lobby
- Generate unique 4-letter room codes
- Players join via room code
- Display waiting players on TV and phones
- Minimum 2 players to start
- First player is host who can start game

### QuipKit Game Flow
1. **Prompting Phase**: Display a prompt, players submit text answers (60s)
2. **Voting Phase**: Display all answers anonymously, players vote for favorites (30s)
3. **Results Phase**: Show votes received and update scores (5s display)
4. **Repeat**: 3-5 rounds total
5. **Final Scores**: Display winner

### Scoring System
- 100 points per vote received
- Players cannot vote for their own answers
- Cumulative scoring across rounds

## Success Metrics (MVP)
- Can 4 friends join a room with their phones?
- Does the TV show what's happening?
- Can they play one complete round and see scores?
- **Is it fun?**

---

## 02-architecture-principles

# Architecture Principles

## Core Design Principles

### 1. Message-Driven Design
The system is built around **messages** (WebSocket actions) as the primary verbs:
- `join_game`
- `submit_data`
- `submit_vote`
- `start_game`

All architecture decisions support clean routing and handling of these messages.

### 2. Extensibility via Strategy Pattern
**Problem**: Need to support multiple game types without modifying core infrastructure.

**Solution**: Use the Strategy Pattern
- Each game type (QuipKit, DrawKit, etc.) is a separate module
- Game model has a `game_type` column (e.g., "QuipKit")
- A registry maps game types to their logic modules
- GameChannel routes messages to the appropriate strategy based on `game_type`

**Key Insight**: Adding a new game requires zero changes to GameChannel or other games.

### 3. Loose Coupling via Events
**Problem**: Game logic needs to trigger scoring, broadcasting, achievements, etc. without becoming a "god object."

**Solution**: Internal event bus (Wisper or ActiveSupport::Notifications)
- Game logic publishes events (e.g., `:round_complete`)
- Separate listeners subscribe to events
- ScoreListener handles scoring
- BroadcastListener handles UI updates
- Each concern is isolated and testable

**Key Insight**: Follows Law of Demeter - game logic doesn't know scoring exists.

### 4. Server-Authoritative
**Decision**: Server is single source of truth for all game state and timing.

**Rationale**: 
- Prevents cheating
- Simplifies synchronization
- Clients are "dumb terminals" that display state

**Implication**: All game decisions happen server-side; clients only send input and display output.

### 5. HTML-Over-The-Wire
**Decision**: Server renders all UI as HTML sent via Turbo Streams.

**Rationale**:
- Keeps rendering logic in one place (Rails views)
- No client-side templating needed
- Easier to test (system tests with Capybara)
- Smaller client-side codebase

**Trade-off**: More server rendering load, but Action Cable handles this well at target scale.

### 6. Pragmatic Simplicity
**Principle**: Build the simplest thing that works. Add complexity only when forced by real problems.

**Applications**:
- No timer synchronization until it's proven necessary
- No user authentication for MVP
- No anti-cheat measures (it's a party game)
- No complex state machines until state transitions become problematic

**When to Add Complexity**: After first playtest with real users reveals actual pain points.

## Three-Layer Architecture

```
Communication Layer (Action Cable)
    ↓ routes messages
Application Core (Game Logic Strategies)
    ↓ publishes events
Event System (Listeners)
```

### Communication Layer
- Single generic GameChannel
- Game-agnostic
- Routes messages to appropriate game logic
- Provides broadcast interface

### Application Core
- Game-specific logic modules (e.g., QuipKit::Logic)
- Implements common interface
- Manages state transitions
- Publishes events

### Event System
- Listeners subscribe to events
- Handle cross-cutting concerns (scoring, broadcasting, etc.)
- Independently testable

## Actor Model

### Server (Rails)
- **Role**: Director and authority
- **Responsibilities**: Game state, rule enforcement, timing
- **Communication**: Receives messages, broadcasts state changes

### TV (Main Screen)
- **Role**: Display-only subscriber
- **Responsibilities**: Show game state to all players
- **Communication**: Receives broadcasts only
- **Interaction**: Minimal or none

### Phone (Player Controller)
- **Role**: Input device and personal display
- **Responsibilities**: Send player actions, show player-specific UI
- **Communication**: Sends messages, receives targeted broadcasts
- **Interaction**: Forms, buttons, voting interfaces

---

## 03-data-models

# Data Models

## Design Principles

### Generic Core, Specific Extensions
- Core models (Game, Player, Round) are generic
- Game-specific models are namespaced (QuipKit::Answer)
- This allows different games to have different data needs

### Start Concrete, Refactor When Needed
- Don't create polymorphic associations prematurely
- If the Round model works for 3 games, keep it
- Refactor only when a new game doesn't fit the pattern

### Anticipate Common Needs
- Session-based reconnection (no auth required)
- Timer recovery after server restart
- Cumulative scoring

## Core Models

### Game
Represents an instance of a game session.

**Key Attributes**:
- `room_code` (string, unique, indexed): 4-letter join code
- `game_type` (string): Maps to logic module (e.g., "QuipKit")
- `status` (string): Current game phase (lobby, prompting, voting, results, complete)
- `current_round_id` (integer): Reference to active round
- `timer_expires_at` (datetime): For timer recovery
- `timer_event` (string): What happens when timer expires

**Responsibilities**:
- Owns players and rounds
- Tracks overall game state
- Provides interface to current game logic

**Future Considerations**:
- Add state machine gem (aasm) when state transitions become complex
- Add `host_player_id` if host permissions expand beyond "first player"

### Player
Represents a participant in a game.

**Key Attributes**:
- `game_id` (integer): Which game they're in
- `name` (string): Display name
- `score` (integer, default: 0): Cumulative points
- `session_id` (string, indexed): For reconnection without auth

**Responsibilities**:
- Owns game-specific data (answers, votes)
- Tracks cumulative score

**Future Considerations**:
- `player_index` for consistent ordering in UI
- `is_host` boolean if host concept expands
- `connected_at` and `disconnected_at` for connection tracking

### Round
Represents a single turn/question in a game.

**Key Attributes**:
- `game_id` (integer): Which game this belongs to
- `prompt_id` (integer): The question being asked
- `round_number` (integer): 1, 2, 3, etc.
- `status` (string): Phase of this round (prompting, voting, complete)

**Responsibilities**:
- Owns game-specific submissions (answers, drawings)
- Links to a specific prompt

**Design Question**: Should Round be generic or game-specific?
- **Start Generic**: Works for most Jackbox-style games
- **Refactor Later**: If a game needs radically different structure

### Prompt
Stores questions/prompts for games.

**Key Attributes**:
- `text` (string): The actual prompt
- `game_type` (string): Which game this is for
- `game_pack_id` (integer, optional): For grouping themed prompts

**Seeding Strategy**:
- Start with 50-100 prompts in seeds.rb
- Mark prompts as "used" in game session to avoid repeats
- Add admin interface later for user-generated prompts

## Game-Specific Models

### QuipKit::Answer
Player-submitted text answers.

**Key Attributes**:
- `round_id`: Which round this is for
- `player_id`: Who submitted it
- `text` (string, max 140 chars): The answer

**Relationships**:
- Has many votes

### QuipKit::Vote
Player votes for favorite answers.

**Key Attributes**:
- `round_id`: Which round this is for
- `player_id`: Who voted (the voter)
- `answer_id`: What they voted for

**Constraints**:
- One vote per player per round (unique index on player_id + round_id)
- Players cannot vote for their own answers (enforced in logic)

## Future Models

### Score (if granular scoring needed)
Track individual scoring events rather than just cumulative totals.

**When to Add**: If you need to display "this round you earned..." breakdowns.

### GameEvent (for debugging/replay)
Persist all significant events for debugging and analytics.

**When to Add**: When bugs are hard to reproduce or you want analytics.

### Achievement (gamification)
Track player achievements across games.

**When to Add**: Post-MVP, if engagement needs boosting.

---

## 04-communication-layer

# Communication Layer

## Design Decisions

### Single Generic Channel
**Decision**: One `GameChannel` handles all game types.

**Rationale**:
- Different games share the same verbs (join, submit, vote)
- Routing logic is simple: delegate to game-specific strategy
- Avoids channel proliferation

**Alternative Considered**: Separate channel per game type
- **Rejected**: Would duplicate connection/subscription logic

### Game Type Registry
**Decision**: Use explicit registry instead of `constantize` on user input.

**Rationale**:
- Security: Never constantize unvalidated strings
- Explicitness: Clear what games exist
- Error handling: Fail fast on invalid game types

**Implementation Hint**: Hash mapping strings to classes.

### Stream Naming Convention
**Decision**: 
- Broadcast to all in game: stream the Game model
- Broadcast to specific player: stream "#{game_id}_#{player_id}"

**Rationale**:
- TV sees game-wide stream only
- Phones see both game-wide and player-specific streams
- Simple to target broadcasts

## Channel Responsibilities

### What GameChannel Does
1. Authenticate/identify connecting clients
2. Subscribe them to appropriate streams
3. Validate they have permission (e.g., player exists in game)
4. Route incoming messages to game logic
5. Provide broadcast interface to application

### What GameChannel Doesn't Do
- Any game-specific logic
- Score calculation
- State validation (delegates to game logic)
- Rendering (delegates to GameBroadcaster)

## Message Flow

```
Client sends message
  ↓
GameChannel receives action (e.g., submit_data)
  ↓
Channel identifies game and player
  ↓
Channel delegates to game logic strategy
  ↓
Game logic handles message, publishes event
  ↓
Listeners react to event
  ↓
BroadcastListener renders and sends Turbo Streams
  ↓
Clients receive and display updated UI
```

## Security Considerations (MVP)

### What's Protected
- Room codes are secret (456,976 possible combinations)
- Session-based player identity
- Server validates all actions (can't vote twice, can't vote for own answer)

### What's Not Protected (Acceptable for MVP)
- No CAPTCHA (could be spammed, but low stakes)
- No rate limiting (friends won't DDoS each other)
- No encryption (WebSockets already over wss:// in production)

### Future Hardening (Post-MVP)
- Rate limiting on message submission
- Room passwords for private games
- Input validation on all client data
- Disconnect detection and cleanup

## Common Interface for Game Logic

All game logic modules must respond to these messages:
- `handle_start(player, data)` - Start the game
- `handle_submission(player, data)` - Player submits answer/drawing
- `handle_vote(player, data)` - Player votes (if applicable)

Optional messages games can implement:
- `handle_skip(player, data)` - Skip current phase
- `handle_kick(player, data)` - Remove player (host only)

**Design Principle**: Keep interface minimal. Add methods only when multiple games need them.

## Turbo Streams vs Custom Messages

### Use Turbo Streams For
- Updating UI (replacing divs, showing new screens)
- Most game state changes

### Use Custom Messages For
- Timer ticks (lightweight, frequent)
- Error messages
- Non-UI data (analytics, debug info)

---

## 05-game-logic

# Game Logic Layer

## Design Principles

### Single Responsibility
Each game logic module has one job: manage the rules and state transitions for its specific game type.

**Does**:
- Validate player actions
- Create/update game-specific models
- Determine when to transition states
- Publish events when significant things happen

**Does Not**:
- Calculate scores (ScoreListener does this)
- Broadcast to clients (BroadcastListener does this)
- Handle timers directly (TimerService does this)
- Know about other games

### Event-Driven Side Effects
**Pattern**: Game logic publishes events, listeners handle consequences.

**Events QuipKit Might Publish**:
- `:round_started` - New round begins
- `:answer_submitted` - Player submitted answer
- `:all_answers_in` - All players have answered
- `:voting_started` - Voting phase begins
- `:vote_cast` - Player voted
- `:all_votes_in` - All players have voted
- `:round_complete` - Round finished
- `:game_complete` - Game over

**Why**: Each event has a single responsibility. Listeners can be tested independently.

### State Transitions
**Current Approach (MVP)**: String status column, manual checks in logic.

**When to Add State Machine**: 
- When you find yourself with complex nested if statements about valid transitions
- When bugs appear from invalid state changes
- After 2-3 games are implemented and patterns are clear

**State Machine Benefits Later**:
- Explicit valid transitions
- Callbacks on state entry/exit
- Easy to visualize game flow

## QuipKit Game Flow

### States
1. **Lobby**: Waiting for players to join
2. **Prompting**: Players submit text answers
3. **Voting**: Players vote for favorite answers
4. **Results**: Show votes and update scores
5. **Complete**: Game over

### Transitions
- Lobby → Prompting: Host starts game (min 2 players)
- Prompting → Voting: All players answered OR timer expires
- Voting → Results: All players voted OR timer expires
- Results → Prompting: After 5s delay (next round) OR go to Complete if final round
- Any → Complete: Manual end game OR all rounds complete

### Timing
- Prompting phase: 60 seconds
- Voting phase: 30 seconds
- Results display: 5 seconds
- Total rounds: 3-5 (configurable)

## Event System Setup

### Event Publishing
Use Wisper gem (or ActiveSupport::Notifications as fallback).

**Rationale for Wisper**:
- Clean syntax for publishing
- Explicit subscriber registration
- Good testing support
- Synchronous by default (simple)

**Alternative**: ActiveSupport::Notifications
- Built into Rails
- Slightly more verbose
- Same conceptual model

### Listener Types

#### ScoreListener
**Subscribes to**: `:round_complete`

**Responsibilities**:
- Calculate points earned this round
- Update player scores
- Publish `:scores_calculated` when done

**Scoring Logic (QuipKit)**:
- 100 points per vote received
- No points for voting (prevents strategic voting patterns)

#### BroadcastListener
**Subscribes to**: Multiple events

**Responsibilities**:
- Render appropriate partial for game state
- Broadcast to TV, phones, or specific player
- Keep clients in sync with server state

**Key Events**:
- `:round_started` → Show prompt on TV and phones
- `:answer_submitted` → Show checkmark next to player on TV
- `:voting_started` → Show answers on TV, voting UI on phones
- `:scores_calculated` → Show results screen

#### Future: AchievementListener
**Subscribes to**: Various events

**Responsibilities**:
- Track streaks, first place, funny achievements
- Award badges or special scores

**When to Add**: Post-MVP for engagement.

## Error Handling

### Validation Strategy
**Where to validate**:
1. Game logic validates business rules (can't vote for yourself)
2. Model validations catch data integrity issues
3. Channel does basic authorization (player exists)

**What to do with errors**:
- MVP: Log error, broadcast error message to player who caused it
- Future: More sophisticated error recovery

### Example Error Scenarios
- Player submits answer twice → Ignore second submission
- Player votes after timer expired → Reject, send "too late" message
- Player votes for own answer → Reject silently
- Invalid answer_id in vote → Broadcast error to player

## Testing Strategy

### What to Test in Game Logic
1. **State transitions**: Given state X, action Y leads to state Z
2. **Event publishing**: Action causes correct event with correct data
3. **Validation**: Invalid actions are rejected
4. **Completion detection**: Correctly identifies when phase is complete

### What NOT to Test in Game Logic
- Actual scoring math (that's ScoreListener's job)
- Broadcast rendering (that's BroadcastListener's job)
- Timer mechanics (that's TimerService's job)

### Testing Approach
- Test game logic in isolation (no real Channel, no real broadcasts)
- Stub event publishing
- Verify correct events are published with correct data
- Test edge cases (empty votes, all same votes, etc.)

---

## 06-client-architecture

# Client Architecture

## Technology Choices

### Hotwire (Turbo + Stimulus)
**Decision**: Use Hotwire instead of React/Vue/separate frontend.

**Rationale**:
- Keep all code in Rails ecosystem (single skill set)
- No build pipeline (faster development)
- Server renders all HTML (simpler architecture)
- Turbo Streams work perfectly with Action Cable
- Stimulus provides enough interactivity for party games

**Trade-offs**:
- Complex animations harder than in React
- Client-side game logic not possible (but we don't want that anyway)
- More server rendering load (acceptable at target scale)

### Importmap
**Decision**: Use importmap for JavaScript dependencies.

**Rationale**:
- No webpack/vite/esbuild needed
- HTTP/2 makes multiple requests efficient
- Simpler deployment (no asset compilation)

**Limitation**: 
- Can't use npm packages that need transpilation
- Acceptable because we're using minimal JavaScript

## Client Types

### TV Client
**Purpose**: Display-only screen showing game state to all players.

**Characteristics**:
- Large screen (actual TV or laptop)
- Receive-only (or minimal interaction like "Start")
- Shows all players, current phase, scores
- Requests fullscreen mode
- Uses Wake Lock API to prevent sleep

**Views Needed**:
- Lobby (show room code, player list)
- Prompting (show question, player status)
- Voting (show all answers)
- Results (show votes, scores)

**Stimulus Controllers**:
- `tv_controller` - Fullscreen, wake lock
- `game_connection_controller` - WebSocket connection
- `timer_controller` - Countdown display

### Phone Client
**Purpose**: Personal controller for submitting answers, voting, seeing your score.

**Characteristics**:
- Mobile-first design (but works on laptops too)
- Interactive (forms, buttons)
- Shows player-specific state
- Receives both game-wide and player-specific broadcasts

**Views Needed**:
- Join game (enter name)
- Lobby (wait for game start)
- Prompting (answer form)
- Waiting (submitted, waiting for others)
- Voting (vote buttons)
- Results (your score, leaderboard)

**Stimulus Controllers**:
- `phone_controller` - Form submission, interactions
- `game_connection_controller` - WebSocket connection
- `timer_controller` - Countdown display

## Turbo Streams Architecture

### Broadcast Pattern
Server renders partial → Wraps in Turbo Stream action → Broadcasts via Action Cable → Client receives and applies.

**Key Insight**: Server controls exactly what UI changes and when. Client just displays it.

### Target IDs
**Convention**: Use consistent target IDs across client types.

- `#game_screen` - Main TV display area
- `#phone_screen` - Main phone display area
- `#timer` - Timer countdown
- `#player_list` - List of players
- `#scoreboard` - Current scores

### Broadcast Granularity
**Decision**: Broadcast entire screens, not tiny fragments.

**Rationale**:
- Simpler reasoning about state
- Prevents partial update bugs
- HTML is small enough that full screen updates are fast

**Exception**: Player-specific updates (e.g., "you submitted") can be targeted.

## Stimulus Controllers Design

### Controller Responsibilities

#### game_connection_controller
- Establish WebSocket connection
- Handle connection/disconnection states
- Provide API for other controllers to send messages
- Handle non-Turbo-Stream messages (timer ticks, errors)

#### phone_controller / tv_controller
- Handle client-specific interactions
- Form submissions (phone)
- Fullscreen requests (TV)
- Access game_connection to send messages

#### timer_controller
- Display countdown
- Visual feedback (warnings at 10s)
- Optionally sync with server
- Works from either expires_at timestamp or simple duration

### Stimulus Best Practices
- Use targets for DOM elements
- Use values for configuration
- Use actions for event handling
- Keep controllers small and focused
- One controller per concern

## Routing Strategy

### URL Structure
- `/` - Home page (create or join game)
- `/games/:room_code` - Choose TV or Phone
- `/games/:room_code/tv` - TV display
- `/games/:room_code/phone` - Phone controller (redirects to join if no player)
- `/players` - Join game (create player)

### Session Management
- Use Rails session to store `session_id` (UUID)
- Player model stores `session_id` for reconnection
- No authentication required for MVP
- Session persists across page refreshes

### Reconnection Handling (Future)
- If player disconnects and reconnects with same session_id, resume
- Show "reconnecting..." UI during brief disconnects
- Allow explicit "new player" flow if needed

## Mobile Considerations

### Viewport Settings
Set proper viewport meta tag for mobile devices.

### Touch-Friendly
- Large tap targets (minimum 44x44px)
- Avoid hover states (use tap/click only)
- Prevent zoom on form inputs

### Offline Handling
- Show connection status indicator
- Queue actions when offline (future enhancement)
- Clear error messages when connection lost

## Testing Strategy

### System Tests (Capybara)
Test full user flows:
- Create game, join as two players, submit answers, vote, see results
- Test both TV and phone views in same test
- Use multiple sessions to simulate multiple players

### Stimulus Tests (Optional)
- Test controllers in isolation using @hotwired/stimulus-testing
- Focus on complex logic (timer calculations, form validation)
- Most behavior is simple enough to skip unit tests

---

## 07-timer-service

# Timer Service

## Design Philosophy

### Pragmatic Approach for Party Games
**Reality Check**: This is a casual party game with friends in a room, not competitive eSports.

**Acceptable**:
- ±3 seconds variance between players
- Countdown starts slightly late due to network latency
- Timer shows slightly different values on different devices

**Unacceptable**:
- Server accepting submissions after timer ends
- Timer wildly inaccurate (off by 20+ seconds)

**Key Insight**: Server enforces deadline; client timer is just for UX.

### Problems We're Actually Solving

#### 1. Clock Skew (Real, Common)
**Problem**: Player's phone clock is 30 seconds off.
**Impact**: Their countdown shows wrong time.
**Solution**: Send server timestamp with duration, client counts down from that.
**Priority**: Medium (can add later if needed).

#### 2. Network Latency (Real, Common)
**Problem**: Player's phone gets timer start message 2 seconds late.
**Impact**: They have 2 seconds less to answer.
**Solution**: Accept this as reality, or sync at end of timer.
**Priority**: Low (acceptable for party game).

#### 3. Malicious Manipulation (Imaginary, Irrelevant)
**Problem**: Player changes system clock to cheat.
**Impact**: None - server enforces deadline regardless.
**Solution**: Ignore entirely.
**Priority**: Zero.

## MVP Timer Design

### Simple Approach (Start Here)
1. Server broadcasts timer start with duration (e.g., 60 seconds)
2. Clients count down locally from duration
3. Server schedules job to execute at deadline
4. Server enforces deadline regardless of what clients display

**No synchronization. No per-second broadcasts. No complexity.**

### What Timer Service Needs to Do
- Start a timer (with duration and event to fire)
- Track timer expiration
- Execute action when time expires
- Survive server restarts (via Sidekiq)
- Support multiple concurrent games

### What Timer Service Doesn't Need to Do
- Broadcast every second
- Sync with clients
- Handle pausing (just cancel and restart)
- Sub-second precision

## Implementation Approaches

### Option 1: Sidekiq Jobs (Recommended for MVP)
**How it works**:
- Store `timer_expires_at` and `timer_event` on Game model
- Schedule a job to run at expiration time
- Job publishes timer_expired event when it runs

**Pros**:
- Simple, uses existing infrastructure
- Sidekiq handles persistence (survives restarts)
- Easy to test (Sidekiq testing helpers)

**Cons**:
- ~1 second scheduling variance (acceptable for party games)

### Option 2: Redis + Polling (Future)
**How it works**:
- Store expiration timestamp in Redis
- Clients poll for time remaining
- Or send timestamp once, client counts down locally

**When to use**: If per-second broadcasts become needed.

### Option 3: Hybrid (Future Optimization)
**How it works**:
- Send timer start with server timestamp
- Clients count down locally
- Optional: Broadcast at 10s mark to re-sync

**When to use**: After playtesting shows timing issues.

## Reconnection Handling

### Problem
Player disconnects and reconnects mid-timer. What do they see?

### Solution (MVP)
- Store `timer_expires_at` on Game model
- When player reconnects, calculate remaining time
- Show countdown from remaining time

**Pseudocode**:
```
remaining = max(0, game.timer_expires_at - Time.current)
broadcast timer with remaining seconds
```

### Solution (Future)
- Send both duration and expires_at timestamp
- Client can calculate remaining time without server help

## Testing Strategy

### What to Test
- Timer starts and schedules job correctly
- Job fires event at expiration
- Game state transitions when timer expires
- Multiple games can have independent timers

### What NOT to Test
- Exact timing (use time mocking, not real waits)
- Client-side countdown accuracy (that's Stimulus controller's job)

### Test Approach
- Use `perform_enqueued_jobs` to run timer jobs immediately
- Use `travel_to` to manipulate time
- Verify correct events are published

## When to Add Complexity

### Wait for These Signals from Playtesting
- "The timer ended but I had 5 seconds left!" (sync issue)
- "My timer started way late" (latency issue)
- "The timer shows different times for everyone" (skew issue)

### Then Add
- Send server timestamp with timer start
- Optional 10-second warning broadcast to re-sync
- Client-side skew detection and warnings

### Don't Add Until Necessary
- Per-second broadcasts (wasteful)
- Complex synchronization (YAGNI)
- Pause/resume functionality (just restart timer)

---

## 08-development-practices

# Development Practices

## Test-Driven Development

### Red-Green-Refactor Cycle
**Mandatory approach for this project.**

#### 1. Red - Write a Failing Test
- Write the test for the behavior you want
- Run the test and watch it fail
- Failure should be for the right reason (not syntax error)

#### 2. Green - Make It Pass
- Write the minimum code to make the test pass
- Don't worry about elegance yet
- Get to green as quickly as possible

#### 3. Refactor - Improve the Code
- Now that tests pass, improve the implementation
- Extract methods, remove duplication, clarify names
- Run tests after each change to ensure they still pass

### Why This Matters
- **Prevents scope creep**: Write only code needed for current test
- **Ensures testability**: If you can't write the test first, design is wrong
- **Documents behavior**: Tests are executable specifications
- **Enables refactoring**: Can improve code fearlessly

### Testing Layers

#### Model Tests (RSpec)
- Test validations
- Test associations
- Test scopes and queries
- Test any business logic in models

#### Service Tests (RSpec)
- Test game logic in isolation
- Stub external dependencies (channels, broadcasts)
- Test event publishing
- Test state transitions

#### System Tests (Capybara)
- Test full user flows
- Test TV and phone interactions together
- Test real-time updates via Action Cable
- Use multiple sessions for multiplayer

#### Integration Tests
- Test event listeners
- Test Action Cable subscriptions
- Test timer service integration

### What to Test
- **All business logic** (game rules, scoring, validations)
- **State transitions** (lobby → prompting → voting)
- **Event publishing** (correct events with correct data)
- **Error handling** (invalid inputs, edge cases)

### What NOT to Test
- **Rails framework** (don't test that `has_many` works)
- **External gems** (don't test that Wisper publishes)
- **Obvious code** (simple getters/setters)
- **Private methods directly** (test via public interface)

## Code Quality Standards

### RuboCop Compliance
**All code must pass RuboCop checks.**

#### Key Rules
- No trailing whitespace
- No extra blank lines
- Consistent indentation (2 spaces)
- Line length maximum 120 characters (configurable)
- Use Ruby idioms (e.g., `unless` instead of `if !`)

#### Configuration
Create `.rubocop.yml` to customize rules:
- Allow longer lines in tests if needed
- Exclude generated files
- Enable/disable specific cops as needed

#### Running RuboCop
```bash
# Check all files
rubocop

# Auto-fix safe violations
rubocop -a

# Auto-fix including unsafe
rubocop -A
```

### Code Organization

#### Follow Rails Conventions
- Models in `app/models`
- Controllers in `app/controllers`
- Views in `app/views`
- Game logic in `app/services` (or `app/game_logic`)
- Listeners in `app/listeners`

#### Namespace Game-Specific Code
```
app/
  models/
    quip_kit/
      answer.rb
      vote.rb
  services/
    quip_kit/
      logic.rb
```

#### Single Responsibility
- Classes do one thing
- Methods are short (aim for 5-10 lines)
- Extract private methods when method does multiple steps

## Object-Oriented Design Principles

### Think About Messages First
**Key Principle from POODR**: Focus on the messages objects send, not the objects themselves.

#### Ask These Questions
1. What messages does this object need to respond to?
2. What messages does this object need to send?
3. Can I minimize the messages between objects?

#### Example: Game Logic
**Bad**: Game logic directly calls ScoreListener, BroadcastListener, etc.
**Good**: Game logic publishes event; listeners subscribe to what they care about.

**Why**: Game logic doesn't need to know who's listening. Listeners can be added/removed without changing game logic.

### Duck Typing - Objects That Quack Alike

**Principle**: If it responds to the right messages, it's the right type.

#### Common Interface for Game Logic
All game logic modules should respond to:
- `handle_start`
- `handle_submission`
- `handle_vote` (if applicable)

**Don't check types**: Never use `is_a?` or `class` checks. Trust that objects respond to messages.

#### Example: Broadcasting
**Bad**: 
```ruby
if broadcaster.is_a?(GameBroadcaster)
  broadcaster.broadcast_to_tv(...)
end
```

**Good**:
```ruby
# Just send the message - trust it responds
broadcaster.broadcast_to_tv(...)
```

### Dependency Injection

**Principle**: Pass dependencies in rather than creating them internally.

#### Why It Matters
- Makes testing easier (inject test doubles)
- Makes dependencies explicit
- Allows flexibility (different implementations)

#### Example: Game Logic
**Bad**: Logic creates its own broadcaster internally
**Good**: Logic receives broadcaster in constructor

### Law of Demeter

**Principle**: Only talk to your immediate neighbors.

**Rule**: Use only one dot (generally).
- `object.method` ✓
- `object.method.method` ✗ (probably)

#### Example
**Bad**: 
```ruby
game.current_round.answers.first.player.name
# Knows too much about internal structure
```

**Good**:
```ruby
game.current_player_name
# Ask the object for what you need
```

### Composition Over Inheritance

**Principle**: Prefer small, composable objects over large inheritance hierarchies.

#### For This Project
- Game logic modules are separate, not inherited from BaseGame
- Listeners are independent, not subclasses of BaseListener
- Share behavior via modules (composition) when needed

**Example**: If multiple games need similar voting logic, extract to module:
```ruby
module Votable
  def handle_vote(player, data)
    # shared voting logic
  end
end

module QuipKit
  class Logic
    include Votable
  end
end
```

### Tell, Don't Ask

**Principle**: Tell objects what to do, don't ask for data and make decisions for them.

**Bad**:
```ruby
if game.status == 'voting' && game.votes.count == game.players.count
  game.status = 'results'
end
```

**Good**:
```ruby
game.complete_voting_if_ready
```

### Isolate External Dependencies

**Principle**: Wrap external APIs so your code doesn't depend directly on them.

#### Example: Event Publishing
**Bad**: Wisper calls throughout codebase
**Good**: Extract to module that can be swapped

```ruby
module Publishable
  def publish(event_name, data)
    Wisper.publish(event_name, data)
  end
end
```

Now if you switch from Wisper to ActiveSupport::Notifications, change one place.

## Naming Conventions

### Be Explicit and Clear
- Methods that return booleans: `all_players_answered?`, `game_complete?`
- Methods that cause changes: `transition_to_voting!`, `complete_round!`
- Variables: Full words, no abbreviations (except common ones like `id`)

### Follow Rails Conventions
- Models: Singular (`Game`, `Player`, not `Games`, `Players`)
- Controllers: Plural (`GamesController`, not `GameController`)
- Tables: Plural (`games`, `players`)

### Game-Specific Naming
- Namespace with game name: `QuipKit::Logic`, `QuipKit::Answer`
- Keep names domain-relevant: Use "answer" not "submission" for QuipKit
- Different games can use different terms: DrawKit might use "drawing"

## Git Workflow

### Commit After Each Green
After each red-green-refactor cycle, commit:
```bash
git add .
git commit -m "Add voting phase to QuipKit"
```

### Commit Message Format
```
Type: Brief description

- Detail about what changed
- Why it changed
- Any important decisions
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`

### Branch Strategy (When Collaborating)
- `main` - always working, tested code
- Feature branches for new games or major features
- Merge only when tests pass and RuboCop is clean

## Documentation

### When to Write Comments
- **Complex algorithms**: Explain the "why", not the "what"
- **Non-obvious decisions**: Why this approach over alternatives
- **External API contracts**: What messages objects must respond to

### When NOT to Write Comments
- **Self-explanatory code**: Good names are better than comments
- **Obvious logic**: Don't comment `i += 1 # increment i`
- **Commented-out code**: Delete it (Git remembers)

### README Updates
Keep README current with:
- How to set up project
- How to run tests
- How to add a new game type
- Technology decisions and why

---

## 09-implementation-roadmap

# Implementation Roadmap

## Phase 1: Foundation (Week 1)

### Goal
Get a basic lobby working with real-time connections.

### Tasks
1. **Setup Project**
   - Create Rails app with PostgreSQL
   - Add gems: Sidekiq, Redis, Wisper, RSpec, Capybara
   - Configure RuboCop
   - Set up GitHub repo

2. **Core Models (TDD)**
   - Game model with room code generation
   - Player model with session-based identity
   - Write model tests first
   - Implement models
   - Run RuboCop

3. **Basic Controllers**
   - Home page (create game, join game)
   - Games controller (TV and phone views)
   - Players controller (join game flow)

4. **Action Cable Setup**
   - GameChannel with subscription logic
   - Basic connection test (can connect, can broadcast)

5. **Lobby Views**
   - TV lobby (show room code, player list)
   - Phone lobby (enter name, see other players)
   - Stimulus controller for WebSocket connection

6. **System Test**
   - Create game
   - Join as two players from different sessions
   - See both players on TV
   - See each other on phones

**Definition of Done**: Two people can join a room and see each other in real-time.

## Phase 2: First Complete Game Loop (Week 2)

### Goal
Play one round of QuipKit from start to finish.

### Tasks
1. **Round and Prompt Models (TDD)**
   - Round model
   - Prompt model
   - Seed 20 prompts for testing

2. **QuipKit Models (TDD)**
   - QuipKit::Answer
   - QuipKit::Vote
   - Associations and validations

3. **QuipKit Logic (TDD)**
   - Start game (create first round)
   - Handle submission (create answer)
   - Detect all players answered
   - Handle vote (create vote)
   - Detect all players voted

4. **Event System**
   - Set up Wisper
   - ScoreListener (basic scoring)
   - BroadcastListener (broadcast after events)

5. **Timer Service (TDD)**
   - Simple Sidekiq job approach
   - Start timer, schedule expiration
   - Handle timer expiration

6. **Views for All Phases**
   - TV: prompting, voting, results
   - Phone: prompting form, voting buttons, waiting screen, results
   - Timer display on both

7. **Stimulus Controllers**
   - Phone controller (form submission, voting)
   - Timer controller (countdown display)

8. **System Test: Complete Round**
   - Start game
   - Two players submit answers
   - Two players vote
   - See results with scores
   - Verify scores are correct

**Definition of Done**: Can play one complete round with scoring.

## Phase 3: Multiple Rounds & Game Completion (Week 3)

### Goal
Play a complete game with multiple rounds.

### Tasks
1. **Game Flow Logic (TDD)**
   - Transition from results to next round
   - Track round numbers
   - Detect final round
   - Transition to game complete

2. **Final Scores Screen**
   - TV: Show winner, final rankings
   - Phone: Your final placement

3. **Game Configuration**
   - Number of rounds (default 3)
   - Timer durations (configurable)

4. **Polish**
   - Loading states
   - Error messages
   - Connection indicators
   - Better styling

5. **System Test: Full Game**
   - Play complete 3-round game
   - Verify round progression
   - Verify cumulative scoring
   - Verify winner display

**Definition of Done**: Can play a complete 3-round game from start to finish.

## Phase 4: Polish & Edge Cases (Week 4)

### Goal
Handle edge cases and improve UX.

### Tasks
1. **Edge Case Handling (TDD)**
   - Timer expires before all answers in
   - Player disconnects mid-game
   - Only one answer submitted
   - All players vote for same answer

2. **Reconnection**
   - Store player session
   - Rejoin game with same session
   - Show correct state when rejoining

3. **Host Controls**
   - Skip phase button (for testing/debugging)
   - End game early button
   - Kick player (if needed)

4. **UI Improvements**
   - Mobile-friendly phone views
   - TV fullscreen mode
   - Better animations between phases
   - Sound effects (optional)

5. **More Prompts**
   - Seed 100+ prompts
   - Prevent prompt reuse in same game

6. **System Tests for Edge Cases**
   - Test all edge cases
   - Test reconnection
   - Test host controls

**Definition of Done**: Game handles edge cases gracefully, UX is smooth.

## Phase 5: Second Game Type (Week 5+)

### Goal
Prove the architecture is extensible.

### Tasks
1. **Design Second Game**
   - Choose game type (DrawKit? Bluff?)
   - Design game-specific models
   - Design game flow

2. **Implement Game Logic (TDD)**
   - Create new game namespace
   - Implement Logic module
   - Test independently of QuipKit

3. **Add to Registry**
   - Register in GAME_TYPE_REGISTRY
   - Game selection on home page

4. **Game-Specific Views**
   - TV views for all phases
   - Phone views for all phases

5. **System Test: Second Game**
   - Play complete game of new type
   - Verify QuipKit still works
   - Verify no cross-contamination

**Definition of Done**: Two distinct game types both work without modifying GameChannel.

## Future Enhancements (Post-MVP)

### User-Requested Features
Wait for real usage to determine priorities.

**Possible Additions**:
- Custom prompt packs
- Player accounts (track stats across games)
- Achievements and badges
- Custom room passwords
- Spect
