# Screenshot Checkpoints

Visual regression testing system that captures screenshots of every player-facing and host-facing view during system tests. Screenshots are opt-in and piggyback on existing tests — no extra browser sessions or test files needed (except for gap-filling in `screenshot_coverage_spec.rb`).

## Quick Start

```bash
# Capture screenshots (runs all system tests)
SCREENSHOTS=1 bin/rspec spec/system

# Compare new screenshots against baselines
rake screenshots:report

# Promote new screenshots as the accepted baselines
rake screenshots:approve

# Clean up temporary files
rake screenshots:clean
```

## Typical Workflow

1. Make UI changes
2. Run `SCREENSHOTS=1 bin/rspec spec/system`
3. Run `rake screenshots:report` — opens an HTML diff report in your browser
4. Review side-by-side comparisons (baseline vs new)
5. If the changes look correct, run `rake screenshots:approve` to update baselines

## How It Works

- `screenshot_checkpoint("name")` calls are sprinkled through system tests
- When `SCREENSHOTS=1` is set, each call saves a PNG to `tmp/screenshots_new/`
- Without the env var, the calls are no-ops — zero overhead on normal test runs
- Filenames follow the pattern: `{checkpoint_name}_{capybara_session}.png`
- Screenshots are organized into directories named after the RSpec `describe` block

## File Locations

| Path | Purpose | Git tracked? |
|---|---|---|
| `spec/screenshots/` | Baseline images (the "expected" state) | Yes |
| `tmp/screenshots_new/` | Newly captured images (the "actual" state) | No (gitignored via `/tmp/*`) |
| `tmp/screenshots_report.html` | Side-by-side diff report | No |
| `spec/support/screenshot_checkpoint.rb` | The helper module | Yes |
| `lib/tasks/screenshots.rake` | Rake tasks | Yes |

## Adding a Checkpoint

Add `screenshot_checkpoint("descriptive_name")` after an assertion that confirms the page is in the expected state:

```ruby
expect(page).to have_content("Game Lobby")
screenshot_checkpoint("lobby")
```

The Capybara session name is appended automatically, so in a multi-session test you get `lobby_host.png`, `lobby_player2.png`, etc.

## Running a Subset

You can capture screenshots from specific test files:

```bash
SCREENSHOTS=1 bin/rspec spec/system/games/speed_trivia_happy_path_spec.rb
```

Or use the rake task which wraps this:

```bash
rake screenshots:capture[spec/system/games/speed_trivia_happy_path_spec.rb]
```

## Coverage

~94 screenshots across:

- **All 3 game types** (Write & Vote, Speed Trivia, Category List): lobby, instructions, each game phase, game over — both hand (phone) and stage (TV) views
- **Lobby flows**: join form, host controls, non-host view, stage lobby (empty and with players)
- **Backstage**: empty, with players, moderation queue, after rejection
- **Host experience**: dashboard, customize hub, prompt pack library/show/new/edit/bulk-import, trivia pack library/show/new/edit
- **Static pages**: landing page, play page (logged out and logged in)

## Screenshot-Only Tests

`spec/system/screenshot_coverage_spec.rb` contains tests that exist solely to capture views not exercised by other system tests (e.g., stage views for Speed Trivia and Category List, dashboard, customize page). These tests skip entirely unless `SCREENSHOTS=1` is set.
