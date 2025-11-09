# OpenJokeMachine

## Goal
Create a Rails-based, open-source, real-time party game platform inspired by Jackbox Games.

## Core Technology Stack
- **Backend**: Ruby on Rails 8+
- **Real-time**: Action Cable (WebSockets)
- **Frontend**: Hotwire (Turbo + Stimulus)
- **Background Jobs**: Sidekiq
- **Database**: PostgreSQL
- **Cache/Pub-Sub**: Redis
- **Testing**: RSpec, Capybara (with Playwright driver)
- **Code Quality**: RuboCop

## Core Experience
- **Main Screen (TV)**: Displays the game state to all players.
- **Controllers (Phones/Tablets/Laptops)**: Players use personal devices to join a room and interact.
- **Room-Based**: Games are accessed via 4-letter room codes (e.g., "ABCD").
- **Session Length**: 10-15 minutes per game.
- **Target Audience**: Groups of friends playing together in the same physical space.

## MVP Features

### Game Creation & Lobby
- Generate unique 4-letter room codes.
- Players join via room code.
- Display waiting players on TV and phones.
- Minimum 2 players to start.
- First player is host who can start the game.

### QuipKit Game Flow (Example MVP Game)
1. **Prompting Phase**: Display a prompt, players submit text answers (60s).
2. **Voting Phase**: Display all answers anonymously, players vote for favorites (30s).
3. **Results Phase**: Show votes received and update scores (5s display).
4. **Repeat**: 3-5 rounds total.
5. **Final Scores**: Display winner.
