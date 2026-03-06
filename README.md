# Room Rally

A real-time multiplayer party game engine for in-person play. A host projects the Stage on a shared screen while players join on their phones via 4-letter room codes. Built for classrooms, youth groups, living rooms, and parties.

## Game Types

All game engines are fully open source:

- **Comedy Clash** (Write & Vote) — Players write funny responses to prompts, then vote on favorites
- **Think Fast** (Speed Trivia) — Timed trivia rounds where speed matters
- **A-List** (Category List) — Name items in a category before time runs out

## Tech Stack

- **Backend:** Ruby on Rails 8+ (Ruby 3.4)
- **Real-time:** Turbo Streams over Action Cable (HTML-Over-The-Wire)
- **Frontend:** Hotwire (Turbo + Stimulus), Tailwind CSS
- **Background Jobs:** Sidekiq
- **Database:** PostgreSQL
- **File Storage:** Active Storage (configurable — local disk, S3, Cloudflare R2, etc.)
- **Deployment:** Kamal
- **Testing:** RSpec, Capybara with Playwright

## Self-Hosting

### Prerequisites

- Ruby (see `.ruby-version`)
- Node.js
- PostgreSQL
- Redis

### Setup

```bash
git clone https://github.com/jackhartzler/roomrally.git
cd roomrally
cp .env.example .env  # Fill in your values
bin/setup
```

### Environment Variables

Copy `.env.example` and fill in your values. Required:

| Variable | Description |
|----------|-------------|
| `GOOGLE_CLIENT_ID` | Google OAuth client ID (for host login) |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret |
| `R2_ACCESS_KEY_ID` | S3-compatible storage access key |
| `R2_SECRET_ACCESS_KEY` | S3-compatible storage secret key |
| `R2_ACCOUNT_ID` | Storage account ID (for endpoint URL) |
| `OPENAI_API_KEY` | OpenAI API key (for AI content generation) |

Optional: `SENTRY_DSN`, `POSTHOG_API_KEY`, `OPENAI_MODEL`

### Storage

Active Storage is configured in `config/storage.yml`. The default uses Cloudflare R2 (S3-compatible). To use a different backend, update `storage.yml` and set `config.active_storage.service` in your environment config.

### Running

```bash
bin/dev  # Starts Rails, Sidekiq, and Tailwind CSS watcher
```

### Testing

```bash
bin/rspec              # All tests
bin/rspec spec/system  # End-to-end multiplayer tests
```

## Open Core Model

Room Rally uses an open core model:

- **Open (this repo):** All game engines, core platform, self-hosting support
- **Hosted version:** Adds pro features like larger group support, higher AI generation limits, and additional game types

The hosted version relaxes capability limits (audience size, AI requests, pack images) and adds features gated behind a subscription. Self-hosters get the full open core with sensible free-tier defaults.

## Architecture

See the `docs/` directory for detailed guides:

- [Architecture](docs/architecture.md) — Request flow, core patterns, concurrency
- [Data Models](docs/data_models.md) — Schema and relationships
- [Client Guide](docs/client_guide.md) — Stage and Hand client architecture
- [Development Guide](docs/development_guide.md) — Contributing, testing, conventions

## License

MIT
