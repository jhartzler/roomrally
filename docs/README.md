# Room Rally Documentation

## Goal

A Rails-based, real-time party game platform inspired by Jackbox Games.

## Technology Stack

- **Backend**: Ruby on Rails 8+ with PostgreSQL
- **Real-time**: Turbo Streams over Action Cable
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Background Jobs**: Sidekiq with Redis
- **Testing**: RSpec, Capybara with Playwright

## Core Experience

- **Stage**: Main screen displaying game state to all players
- **Hand**: Personal device for player input (phone/tablet)
- **Room Codes**: 4-letter codes for easy joining
- **Session-based**: No accounts required, players identified by browser session

## Documentation Index

- [Architecture](architecture.md) - System design and request flow
- [Game Logic Guide](game_logic_guide.md) - How to add new game types
- [Client Guide](client_guide.md) - Frontend architecture
- [Real-time Communication](real_time_communication.md) - Turbo Streams broadcasting
- [Background Services](background_services.md) - Timers and Sidekiq
- [Style Guide](STYLE_GUIDE.md) - UI design system
- [Copy Voice](copy-voice.md) - In-game text tone and style
- [Screenshot Checkpoints](screenshot_checkpoints.md) - Visual regression testing
