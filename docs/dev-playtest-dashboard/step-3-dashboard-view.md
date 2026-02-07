# Step 3: Build the Playtest Dashboard View (Use Opus)

## Goal

Transform `show_test_game.html.erb` into a playtest dashboard — a single page where you can control the entire game, see the stage, and trigger bot actions. This is the main UI you'll use for manual testing.

## File to Modify

`app/views/dev_testing/show_test_game.html.erb`

## Layout

Split into two panels side by side:

### Left Panel (narrow, ~350px) — Control Panel

From top to bottom:

1. **Room Info**
   - Room code (large, prominent)
   - Game type

2. **Game State Indicator**
   - Show current status: `lobby`, `instructions`, `writing`, `voting`, `waiting`, `answering`, `reviewing`, `finished`
   - Use a colored badge (green for active states, gray for waiting, blue for finished)
   - Show round number for Write And Vote (`Round X of 2`)
   - Show question number for Speed Trivia (`Question X of Y`)

3. **Action Buttons** (context-aware based on game state)
   - **Lobby:** "Start Game" button → POSTs to `dev_start_game_path(@room)`
   - **Instructions:** "Advance" button (labeled "Skip Instructions") → POSTs to `dev_advance_path(@room)`
   - **Writing:** "Bots: Submit Responses" button → POSTs to `dev_bot_act_path(@room)`
   - **Voting:** "Bots: Cast Votes" button → POSTs to `dev_bot_act_path(@room)`
   - **Waiting (trivia):** "Advance" button (labeled "Start Question") → POSTs to `dev_advance_path(@room)`
   - **Answering (trivia):** "Bots: Answer" button → POSTs to `dev_bot_act_path(@room)`, then "Close Round" → POSTs to `dev_advance_path(@room)`
   - **Reviewing (trivia):** "Advance" button (labeled "Next Question") → POSTs to `dev_advance_path(@room)`
   - **Finished:** "Game Complete!" text, maybe a "Create Another" link

   Use `button_to` helper for POST links with CSRF protection.

4. **Auto-play Button**
   - "Auto-play to End" button → POSTs to `dev_auto_play_path(@room)`
   - Show in all states except finished
   - Style it differently (secondary/outline) to distinguish from step-by-step controls

5. **Player Links**
   - List each player with:
     - Name
     - "Open Hand" link → `set_player_session_path(player)` with `target: "_blank"`
   - Indicate which player is you (Player 1 / host)

6. **Quick Links**
   - "Open Stage (full)" → `room_stage_path(@room)` in new tab
   - "Open Backstage" → `room_backstage_path(@room)` in new tab
   - "Create Another Game" → `dev_testing_path`

### Right Panel (wide, fills remaining space) — Stage View

An iframe showing the stage view:

```erb
<iframe src="<%= room_stage_path(@room) %>" class="w-full h-full border-0"></iframe>
```

The iframe auto-updates via Turbo Streams (the stage page already subscribes to the room's Action Cable channel), so as you click buttons on the left panel, the stage view updates in real-time on the right.

## Styling

Use Tailwind CSS classes. The page should be full-height (`min-h-screen`) with the two panels using flexbox:

```erb
<div class="flex min-h-screen">
  <!-- Left panel -->
  <div class="w-[350px] flex-shrink-0 bg-white border-r border-gray-200 p-6 overflow-y-auto">
    <!-- controls -->
  </div>
  <!-- Right panel -->
  <div class="flex-1">
    <iframe src="..." class="w-full h-full border-0"></iframe>
  </div>
</div>
```

## Dynamic State Display

The controller's `show_test_game` action already loads `@room` and `@players`. Add to the controller (or compute in the view):

```ruby
# In the view or controller:
@game = @room.current_game
@game_status = @game&.status || "lobby"
```

The action buttons should conditionally render based on `@game_status`. Use simple `if/case` in the ERB — no Stimulus needed since the page refreshes after each action (the controller redirects back to the dashboard).

## Important Notes

- All action buttons use `button_to` which generates POST forms with CSRF tokens
- The iframe for the stage view will connect to Action Cable and receive Turbo Stream updates automatically — you don't need to do anything special for real-time updates in the stage
- The left panel (controls) does NOT auto-update — it refreshes when you click a button (redirect). This is fine for a dev tool.
- Make sure the iframe has no padding/margin and fills the right panel completely
- The existing `show_test_game` view will be completely replaced

## Reference Files

- `app/views/dev_testing/show_test_game.html.erb` — current view to replace
- `app/views/dev_testing/index.html.erb` — reference for the create form styling
- `app/controllers/dev_testing_controller.rb` — provides `@room` and `@players`
- Route helpers: `dev_start_game_path(@room)`, `dev_bot_act_path(@room)`, `dev_advance_path(@room)`, `dev_auto_play_path(@room)`, `set_player_session_path(player)`, `room_stage_path(@room)`, `room_backstage_path(@room)`

## Verification

1. Start `bin/dev`
2. Visit `/dev/testing`
3. Create a Write And Vote game with 4 players
4. Dashboard should load with stage iframe on right, controls on left
5. Click "Start Game" → stage shows instructions, controls show "Skip Instructions"
6. Click "Skip Instructions" → stage shows writing phase
7. Click "Bots: Submit Responses" → all responses submitted, stage shows voting
8. Click "Bots: Cast Votes" repeatedly → votes cast, prompts advance
9. Continue through round 2 → game finishes
10. Test "Auto-play to End" from a fresh game — should complete hands-free
11. Repeat for Speed Trivia
