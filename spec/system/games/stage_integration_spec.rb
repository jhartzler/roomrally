require "rails_helper"

RSpec.describe "Stage View Game Integration", type: :system do
  let!(:room) { Room.create!(game_type: "Write And Vote") }

  before do
    10.times { |i| Prompt.create!(body: "Prompt #{i}") }
  end

  it "updates stage view through game phases" do
    # 1. Open Stage View
    stage_window = open_new_window
    within_window stage_window do
      visit room_stage_path(room)
      expect(page).to have_content("Join via your phone")
    end

    # 2. Join Players and Start Game
    # We need 3 players to start
    players = []
    3.times do |i|
      using_session "player_#{i}" do
        visit join_room_path(room.code)
        fill_in "What's your name?", with: "Player #{i}"
        click_on "Join Game"
        players << "Player #{i}"
      end
    end

    # Check lobby updates
    within_window stage_window do
      players.each { |name| expect(page).to have_content(name) }
    end

    # Host starts the game (Player 0 is host)
    using_session "player_0" do
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
      click_on "Start Game"
    end

    # 3. Verify Writing Phase on Stage
    within_window stage_window do
      expect(page).to have_content("Look at your device!")
      expect(page).to have_content("Writing Phase: Round 1")
    end

    # 4. Submit Responses to trigger Voting
    room.reload.current_game.prompt_instances.where(round: 1).each do |pi|
      # Simulate response submission directly to speed up test
      # or go through UI if we want full integration testing
      # Direct model creation is faster and less flaky for this purpose
      # assuming we trust the game logic (which is tested elsewhere)
      # BUT we need to trigger the broadcast which happens in the controller or service
      # let's use the service method `check_all_responses_submitted`

      # We have to create responses for all players
      # Wait, prompt instances are assigned to pairs of players.
      # Let's iterate players and submit for their assigned prompts
    end

    # Actually, simpler to just simulate the service calls if we want to test JUST the stage view
    # But this is a system test so we should probably drive the UI or use the Service.

    # Let's use the UI for one player to ensure flow, but maybe shortcuts for others?
    # Or just use `Games::WriteAndVote` service to forcefully advance state?

    # Force state transition to Voting for test speed/reliability
    # We want to verified the Stage View *REACTS*, not re-test the whole game loop logic.

    game = room.current_game

    # Update responses
    game.prompt_instances.where(round: 1).each do |pi|
       # Find the player who was assigned this prompt
       # Actually responses are created blank. We update them.
       pi.responses.update_all(body: "Funny Answer")
    end

    # Trigger voting phase transition manually via Service to ensure broadcast
    Games::WriteAndVote.check_all_responses_submitted(game:)

    # 5. Verify Voting Phase on Stage
    within_window stage_window do
      expect(page).to have_content("Cast your votes now!")
      expect(page).to have_content("Prompt")
      # Expect to see the prompt body. We need to fetch it from DB
      expect(page).to have_content(game.current_round_prompts.first.body)
    end

    # 6. Verify Game Over
    # Force finish game
    game.update!(status: :voting, round: 2, current_prompt_index: 99) # Hack to ensure next step is finish

    # Call process_vote to trigger finish (simulated)
    # Actually, easy way: just manually broadcast the finished state to verify the view

    # But let's try to be slightly more integration-y
    game.update!(status: :finished)
    GameBroadcaster.broadcast_stage(room:)

    within_window stage_window do
      expect(page).to have_content("Game Over!")
      # Verify leaderboard
      expect(page).to have_content("Player 0")
    end
  end
end
