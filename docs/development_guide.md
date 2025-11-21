# Development Guide

## Test-Driven Development (TDD)
All new functionality must be developed following the Red-Green-Refactor cycle.

1.  **Red**: Write a failing test that describes the desired behavior.
2.  **Green**: Write the simplest possible code to make the test pass.
3.  **Refactor**: Improve the implementation, confident that the tests will catch any regressions.

### Testing Layers
- **Model Tests (RSpec)**: Test validations, associations, scopes, and simple business logic on models.
- **Service/Logic Tests (RSpec)**: Test game logic modules in isolation. Stub external dependencies and test for correct state transitions and event publishing.
- **System Tests (Capybara + Playwright)**: Test full, end-to-end user flows. Use multiple sessions to simulate multiplayer interactions and verify real-time updates via Action Cable. These are the most important tests.

- **Integration Tests**: Test the integration between components, such as event listeners reacting correctly to published events.

## Code Quality: RuboCop
All code must pass RuboCop checks based on the configuration in `.rubocop.yml`. Run `rubocop -A` before committing.

## Code Organization
- Follow Rails conventions.
- Place game logic modules in `app/services/` or a similar directory.
- Namespace all game-specific code under a module (e.g., `WriteAndVote::Answer`, `WriteAndVote::Logic`).
- Keep classes and methods small and focused on a single responsibility.

## Key OOD Principles
- **Composition Over Inheritance**: Use modules (`concerns`) to share behavior instead of deep inheritance trees.
- **Dependency Injection**: Pass dependencies (like loggers or broadcasters) into constructors to make classes easier to test and more flexible.
- **Law of Demeter (Tell, Don't Ask)**: Tell objects what to do; don't ask them for their state and then make decisions for them. For example, call `game.complete_round!` instead of asking for the game's status and modifying it externally.
- **Isolate Dependencies**: Wrap external libraries (like Wisper) in your own modules. This makes it easy to swap them out later.

## Git Workflow
- Commit after each successful Red-Green-Refactor cycle.
- Use clear, conventional commit messages (e.g., `feat: Add voting phase to WriteAndVote`).
- Develop features on separate branches and merge to `main` only when all tests and quality checks are passing.

## Documentation
- Write comments to explain the "why" of complex or non-obvious code, not the "what".
- Good naming is better than a comment.
- Delete commented-out code. Git history is your backup.
