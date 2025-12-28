# Room Rally

Room Rally is an open-source, real-time party game engine inspired by Jackbox Games. It allows multiple players to connect using their phones (Hand clients) to a central screen (Stage client) to play various interactive games.

## Features

-   **Real-time Multiplayer:** Players connect and interact in real-time via WebSockets.
-   **Room-Based Sessions:** Games are accessed via simple 4-letter codes.
-   **HTML-Over-The-Wire:** Leverages Hotwire (Turbo + Stimulus) for a dynamic frontend experience with a Rails backend.
-   **Extensible Game Architecture:** Designed to easily add new game types.

## Core Technology Stack

-   **Backend:** Ruby on Rails 8+
-   **Real-time:** Action Cable (WebSockets)
-   **Frontend:** Hotwire (Turbo + Stimulus)
-   **Background Jobs:** Sidekiq
-   **Database:** PostgreSQL
-   **Testing:** RSpec, Capybara (with Playwright driver)

## Getting Started

### Prerequisites

-   Ruby (see `.ruby-version`)
-   Node.js (for JavaScript dependencies)
-   PostgreSQL
-   Redis

### Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/openjokemachine.git
    cd openjokemachine
    ```
2.  **Install dependencies:**
    ```bash
    bin/setup
    ```
3.  **Run tests:**
    ```bash
    bin/rspec
    ```
4.  **Start the development server:**
    ```bash
    bin/dev
    ```
    This will start the Rails server, Sidekiq, and any other necessary processes.

## Detailed Documentation

For more in-depth information on the project's architecture, data models, game logic, and development guidelines, please refer to the `docs/` directory:

-   [Architecture](docs/architecture.md)
-   [Client Guide](docs/client_guide.md)
-   [Data Models](docs/data_models.md)
-   [Development Guide](docs/development_guide.md)
-   [Roadmap](docs/roadmap.md)
-   And more...

## Contributing

We welcome contributions! Please see our [Development Guide](docs/development_guide.md) for more information.

## License

[TODO: Add license information]