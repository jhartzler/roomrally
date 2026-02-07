# Step 1: Create DevBotService (Use Opus)

## Goal

Create a service that can perform game actions for "bot" players — submitting responses, casting votes, and answering trivia — by calling existing game service methods directly. This keeps bot logic completely isolated from production code.

## File to Create

`app/services/dev_bot_service.rb`

## How It Works

The service inspects the current game state and performs the appropriate action for all players except an optional "human" player. It calls the same service methods that controllers call, so it exercises the full stack including broadcasting.

## API

```ruby
DevBotService.act(game:, exclude_player: nil)
```

- `game` — the current game record (`WriteAndVoteGame` or `SpeedTriviaGame`)
- `exclude_player` — optional Player to skip (your "human" player, so you can play manually)

## Implementation Details

### Dispatching

Look at `game.class.name` and `game.status` to decide what to do:

- `WriteAndVoteGame` + `writing` → `submit_responses`
- `WriteAndVoteGame` + `voting` → `cast_votes`
- `SpeedTriviaGame` + `answering` → `submit_answers`
- Any other status → no-op (return early)

### Write And Vote: `submit_responses`

1. Get all Response records for the current round that have blank bodies: `game.responses.joins(:prompt_instance).where(prompt_instances: { round: game.round }).where(body: [nil, ""])`
2. Filter out any belonging to `exclude_player`
3. For each response, update it with a fake body and mark as submitted:
   ```ruby
   response.update!(body: "Bot response #{rand(1000)}", status: "submitted")
   response.prompt_instance.update!(status: "submitted")
   ```
4. After all responses submitted, call: `Games::WriteAndVote.check_all_responses_submitted(game:)`
   - This is the same method `ResponsesController#update` calls
   - It will auto-transition to voting if all responses are in

### Write And Vote: `cast_votes`

1. Get the current prompt being voted on: `game.current_round_prompts.order(:id)[game.current_prompt_index]`
2. Get all responses for that prompt: `current_prompt.responses`
3. Get the list of bot players (room players minus `exclude_player`)
4. For each bot player:
   - Skip if they already voted on this prompt (check `Vote.joins(:response).where(player: bot_player, responses: { prompt_instance_id: current_prompt.id }).exists?`)
   - Find eligible responses (not their own): `current_prompt.responses.where.not(player: bot_player)`
   - Pick one at random
   - Create the vote: `vote = Vote.create!(player: bot_player, response: chosen_response)`
   - Call: `Games::WriteAndVote.process_vote(game:, vote:)` — this handles advancement and broadcasting

### Speed Trivia: `submit_answers`

1. Get bot players (room players minus `exclude_player`)
2. Get current question: `game.current_question`
3. For each bot player:
   - Skip if already answered (check `TriviaAnswer.find_by(player: bot_player, trivia_question_instance: current_question)`)
   - Pick a random option from `current_question.options`
   - Call: `Games::SpeedTrivia.submit_answer(game:, player: bot_player, selected_option: random_option)`
   - This is the same method `TriviaAnswersController#create` calls

### Important Notes

- Use `game.reload` before checking status to get fresh state
- The Vote model has validations (can't vote for own response, one vote per prompt) — the bot logic must respect these by filtering eligible responses
- For Write And Vote voting, `process_vote` handles auto-advancement, so after all bots vote the game may transition to the next prompt or next round automatically
- Guard with `Rails.env.development?` or `Rails.env.test?` check at the top of the class

## Reference Files

- `app/services/games/write_and_vote.rb` — `check_all_responses_submitted`, `process_vote`
- `app/services/games/speed_trivia.rb` — `submit_answer`
- `app/models/write_and_vote_game.rb` — AASM states, `current_round_prompts`, `all_responses_submitted?`
- `app/models/speed_trivia_game.rb` — AASM states, `current_question`
- `app/models/response.rb` — status enum (pending/submitted/rejected/published)
- `app/models/vote.rb` — validations to respect
- `app/controllers/responses_controller.rb` — shows the real submission flow
- `app/controllers/votes_controller.rb` — shows the real voting flow

## Verification

Write a quick test or use Rails console:
```ruby
# Create a room with players and start a Write And Vote game
room = Room.create!(game_type: "Write And Vote")
3.times { |i| Player.create!(room: room, name: "Player #{i+1}") }
room.update!(host: room.players.first)
room.start_game!
Games::WriteAndVote.game_started(room: room, show_instructions: false)

# Bot should submit all responses
DevBotService.act(game: room.current_game)
# Game should now be in "voting" status
room.current_game.reload.status # => "voting"
```
