# Step 2: Enhance DevTestingController + Routes (Use Sonnet)

## Goal

Add game control actions to the dev testing controller so the playtest dashboard can start games, trigger bot actions, and advance game phases — all from one page.

## Files to Modify

- `app/controllers/dev_testing_controller.rb`
- `config/routes.rb`

## New Routes

Add these to `config/routes.rb` alongside the existing dev testing routes:

```ruby
post "dev/testing/:id/start_game", to: "dev_testing#start_game", as: :dev_start_game
post "dev/testing/:id/bot_act", to: "dev_testing#bot_act", as: :dev_bot_act
post "dev/testing/:id/advance", to: "dev_testing#advance", as: :dev_advance
post "dev/testing/:id/auto_play", to: "dev_testing#auto_play", as: :dev_auto_play
```

The `:id` param is the room code (matching `show_test_game` which already uses room code as `:id`).

## Controller Changes

### Modify `create_test_game`

After creating players, automatically:
1. Set Player 1 as host: `room.update!(host: players.first)`
2. Set your session to Player 1: `session[:player_session_id] = players.first.session_id`

### Add `start_game` action

Starts the game by calling the game service directly (bypassing Wisper/RoomsController auth checks):

```ruby
def start_game
  room = Room.find_by!(code: params[:id])
  room.start_game! # AASM transition lobby → playing

  # Call game service directly based on game type
  handler = GameRegistry.handler_for(room.game_type)
  # OR just use a simple conditional:
  case room.game_type
  when "Write And Vote"
    Games::WriteAndVote.game_started(room:, show_instructions: true)
  when "Speed Trivia"
    Games::SpeedTrivia.game_started(room:, show_instructions: true, timer_enabled: false)
  end

  redirect_to show_test_game_path(room)
end
```

Check `config/initializers/game_registry.rb` for the registry pattern — use that if it provides a cleaner dispatch. Otherwise a simple `case` is fine for dev tooling.

### Add `advance` action

Performs the next host/progression action based on current game state:

```ruby
def advance
  room = Room.find_by!(code: params[:id])
  game = room.current_game

  case game
  when WriteAndVoteGame
    case game.status
    when "instructions"
      Games::WriteAndVote.start_from_instructions(game:)
    end
    # Writing → Voting is automatic (when all responses submitted)
    # Voting advancement is automatic (when all votes cast)
  when SpeedTriviaGame
    case game.status
    when "instructions"
      Games::SpeedTrivia.start_from_instructions(game:)
    when "waiting"
      Games::SpeedTrivia.start_question(game:)
    when "answering"
      Games::SpeedTrivia.close_round(game:)
    when "reviewing"
      Games::SpeedTrivia.next_question(game:)
    end
  end

  redirect_to show_test_game_path(room)
end
```

### Add `bot_act` action

Triggers bot actions for the current phase:

```ruby
def bot_act
  room = Room.find_by!(code: params[:id])
  game = room.current_game

  # Exclude Player 1 (the human) from bot actions if desired
  # The exclude_player param is optional — pass nil to have ALL players be bots
  human_player = params[:human_player_id] ? Player.find(params[:human_player_id]) : nil

  DevBotService.act(game:, exclude_player: human_player)

  redirect_to show_test_game_path(room)
end
```

### Add `auto_play` action

Runs the entire game to completion. This chains advance + bot_act repeatedly:

```ruby
def auto_play
  room = Room.find_by!(code: params[:id])
  game = room.current_game

  # Safety limit to prevent infinite loops
  100.times do
    game.reload
    break if game.finished?

    case game
    when WriteAndVoteGame
      auto_play_write_and_vote_step(game)
    when SpeedTriviaGame
      auto_play_speed_trivia_step(game)
    end
  end

  redirect_to show_test_game_path(room)
end

private

def auto_play_write_and_vote_step(game)
  case game.status
  when "instructions"
    Games::WriteAndVote.start_from_instructions(game:)
  when "writing"
    DevBotService.act(game:)
  when "voting"
    DevBotService.act(game:)
  end
end

def auto_play_speed_trivia_step(game)
  case game.status
  when "instructions"
    Games::SpeedTrivia.start_from_instructions(game:)
  when "waiting"
    Games::SpeedTrivia.start_question(game:)
  when "answering"
    DevBotService.act(game:)
    game.reload
    Games::SpeedTrivia.close_round(game:) if game.answering?
  when "reviewing"
    Games::SpeedTrivia.next_question(game:)
  end
end
```

## Important Notes

- No auth checks needed — this is dev-only tooling
- Use `redirect_to show_test_game_path(room)` for all actions so the dashboard refreshes
- The `auto_play` loop needs `game.reload` on each iteration since the game object is modified by service calls
- For Write And Vote, `bot_act` during voting may need to be called multiple times (once per prompt being voted on), since `process_vote` advances one prompt at a time. The `auto_play` loop handles this naturally.

## Reference Files

- `app/controllers/dev_testing_controller.rb` — existing controller to modify
- `config/routes.rb` — existing routes, add new ones near existing dev routes
- `app/services/games/write_and_vote.rb` — service methods to call
- `app/services/games/speed_trivia.rb` — service methods to call
- `config/initializers/game_registry.rb` — game type registry (optional to use)
- `app/services/dev_bot_service.rb` — created in Step 1

## Verification

After Step 3 (dashboard view), the full flow will be testable. But you can verify the controller actions work by:

1. Start `bin/dev`
2. Visit `/dev/testing`, create a game
3. In Rails console, check `Room.last.code` and visit `/dev/testing/show_test_game/XXXX`
4. Use `curl` or browser to POST to the new endpoints
