# Implementation Roadmap

> **Note**: This document reflects the original planning from project inception. The implementation evolved from these plans - some features were built differently than described here (e.g., no separate Round model, no event bus). See `architecture.md` for how the system actually works.

## Completed

### Phase 1: Foundation
- Room and Player models with real-time lobby
- Turbo Streams for real-time updates
- System tests for multiplayer flows

### Phase 2-3: First Complete Game
- WriteAndVote game with multiple rounds
- Timer system via Sidekiq
- Scoring and results display
- Host controls and moderation

### Phase 4: Polish
- Player reconnection via session
- Timer expiration handling
- Mobile-responsive UI
- Dark glassmorphism design system

## Current State

The MVP is complete with one game type (WriteAndVote). The architecture supports adding new game types via the Strategy Pattern.

## Future Ideas

- Additional game types (drawing games, trivia, social deduction)
- Custom prompt packs (user-created)
- Player accounts and stats tracking
- Spectator mode
- Room passwords
