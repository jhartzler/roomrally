# Dev Playtest Dashboard

A single-page dev tool for testing full multiplayer game flows as one person. Creates bot players that auto-respond/vote/answer, with a split-panel dashboard showing game controls + live stage view.

## Steps (execute in order, each in its own chat)

| Step | File | Model | What it does |
|------|------|-------|-------------|
| 1 | [step-1-dev-bot-service.md](step-1-dev-bot-service.md) | **Opus** | Create `DevBotService` — calls existing game service methods to act as bot players |
| 2 | [step-2-controller-and-routes.md](step-2-controller-and-routes.md) | **Sonnet** | Add game control actions to `DevTestingController` + routes |
| 3 | [step-3-dashboard-view.md](step-3-dashboard-view.md) | **Opus** | Build the playtest dashboard UI (split-panel: controls + stage iframe) |

## Architecture

```
DevTestingController (dev-only)
  ├── create_test_game  → creates room + players + auto-assigns host
  ├── start_game        → calls Games::WriteAndVote.game_started or Games::SpeedTrivia.game_started
  ├── advance           → calls the next host action (skip instructions, next question, etc.)
  ├── bot_act           → calls DevBotService.act(game:) to submit responses/votes/answers
  └── auto_play         → loops advance + bot_act until game finishes

DevBotService (dev-only)
  └── act(game:, exclude_player: nil)
      ├── WriteAndVoteGame + writing  → submits responses for bot players
      ├── WriteAndVoteGame + voting   → casts votes for bot players
      ├── SpeedTriviaGame + answering → submits answers for bot players
      └── other statuses              → no-op

All bot actions call existing game service methods (same code path as real players).
No production code is modified.
```

## Usage

1. Start `bin/dev`
2. Visit `/dev/testing`, pick game type + player count
3. Dashboard loads: stage view on right, controls on left
4. Step through the game manually, or click "Auto-play to End"
5. Optionally open your hand view in a new tab to test the player experience
