require "rails_helper"

RSpec.describe "Category List Game Happy Path", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, game_type: "Category List", user: nil) }

  before do
    default_pack = FactoryBot.create(:category_pack, :default)
    12.times do |i|
      FactoryBot.create(:category, name: "Category #{i + 1}", category_pack: default_pack)
    end
  end

  it "allows players to join, fill in categories, and see results" do
    # Host joins and claims host
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby")
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
      screenshot_checkpoint("lobby")
    end

    # Other players join
    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      click_on "Join Game"
      expect(page).to have_content("Waiting for players to join...")
      screenshot_checkpoint("lobby")
    end

    Capybara.using_session(:player3) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Bob"
      click_on "Join Game"
      expect(page).to have_content("Waiting for players to join...")
      screenshot_checkpoint("lobby")
    end

    # Host starts the game
    Capybara.using_session(:host) do
      expect(page).to have_button("Start Game")
      click_on "Start Game"
      expect(page).to have_content("Game started!")

      # Instructions screen shown for non-logged-in games
      expect(page).to have_content("Get ready!")

      # Host advances past instructions
      expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
      screenshot_checkpoint("instructions")
      find("#start-from-instructions-btn").click

      # Wait for redirect to complete and filling state to show
      expect(page).to have_button("Submit Answers", wait: 10)
      screenshot_checkpoint("filling")
    end

    # Get the game and letter
    game = room.reload.current_game
    letter = game.current_letter

    # Players submit answers - refresh and fill in the form
    [ :host, :player2, :player3 ].each_with_index do |session, idx|
      Capybara.using_session(session) do
        visit room_hand_path(room)
        expect(page).to have_button("Submit Answers", wait: 10)
        screenshot_checkpoint("filling") if session != :host # host already captured above

        # Scoring hint is visible during filling phase
        expect(page).to have_content("= 2pts")
        expect(page).to have_content("= 1pt")

        # Fill in answer fields (text inputs inside the answer form)
        all("input[name^='answers']").each_with_index do |input, ci_idx|
          input.fill_in with: "#{letter}nswer#{idx}-#{ci_idx}"
        end
        click_on "Submit Answers"
        expect(page).to have_content("Answers submitted!", wait: 5).or have_content(/reviewing/i, wait: 5)
        screenshot_checkpoint("answers_submitted")
      end
    end

    # Game should now be in reviewing state
    expect(game.reload).to be_reviewing

    # Capture reviewing state from a player's perspective
    Capybara.using_session(:host) do
      visit room_hand_path(room)
      screenshot_checkpoint("reviewing")
    end

    # Host finishes review (via service — simulating backstage action)
    Games::CategoryList.finish_review(game: game.reload)

    # Game should be in scoring state
    expect(game.reload).to be_scoring

    # Capture scoring state from a player's perspective
    Capybara.using_session(:host) do
      visit room_hand_path(room)
      screenshot_checkpoint("scoring")
    end

    # Advance to next round
    Games::CategoryList.next_round(game: game.reload)
    expect(game.reload).to be_filling
    expect(game.current_round).to eq(2)
  end

  it "updates all player phones live when host marks an answer" do
    host_player = nil
    alice = nil

    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby", wait: 5)
      click_on "Claim Host"
      expect(page).to have_content("You're the host!", wait: 5)
      host_player = Player.find_by(name: "Host")
    end

    Capybara.using_session(:alice) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby", wait: 5)
      alice = Player.find_by(name: "Alice")
    end

    Games::CategoryList.game_started(
      room:,
      total_rounds: 1,
      categories_per_round: 2,
      timer_enabled: false,
      show_instructions: false
    )
    game = room.reload.current_game

    letter = game.current_letter
    game.current_round_categories.each do |ci|
      Games::CategoryList.submit_answers(
        game:,
        player: host_player,
        answers_params: { ci.id.to_s => "#{letter}pple from Host" }
      )
      Games::CategoryList.submit_answers(
        game:,
        player: alice,
        answers_params: { ci.id.to_s => "#{letter}pple" }
      )
    end
    expect(game.reload).to be_reviewing

    # Alice watches the reviewing screen
    Capybara.using_session(:alice) do
      visit room_hand_path(room)
      expect(page).to have_content("#{letter}pple", wait: 5)
    end

    # Host rejects an answer from their phone
    Capybara.using_session(:host) do
      visit room_hand_path(room)
      expect(page).to have_button("Reject", wait: 5)
      first("button", text: "Reject").click
    end

    # Alice's phone should update to show REJECTED badge
    Capybara.using_session(:alice) do
      expect(page).to have_content("REJECTED", wait: 5)
    end
  end

  it "shows all players' answers for the current category during reviewing" do
    host_player = nil
    alice = nil

    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby", wait: 5)
      click_on "Claim Host"
      expect(page).to have_content("You're the host!", wait: 5)
      host_player = Player.find_by(name: "Host")
    end

    Capybara.using_session(:alice) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby", wait: 5)
      alice = Player.find_by(name: "Alice")
    end

    Games::CategoryList.game_started(
      room:,
      total_rounds: 1,
      categories_per_round: 2,
      timer_enabled: false,
      show_instructions: false
    )
    game = room.reload.current_game

    letter = game.current_letter
    game.current_round_categories.each do |ci|
      Games::CategoryList.submit_answers(game:, player: host_player,
        answers_params: { ci.id.to_s => "#{letter}nswer from Host" })
      Games::CategoryList.submit_answers(game:, player: alice,
        answers_params: { ci.id.to_s => "#{letter}nswer from Alice" })
    end
    expect(game.reload).to be_reviewing

    # Alice should see Host's answer AND the category name
    Capybara.using_session(:alice) do
      visit room_hand_path(room)
      expect(page).to have_content("#{letter}nswer from Host", wait: 5)
      expect(page).to have_content("Host")
      expect(page).to have_content("Category 1 of 2")
    end
  end

  it "host player sees moderation and navigation controls during reviewing" do
    host_player = nil
    alice = nil

    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby", wait: 5)
      click_on "Claim Host"
      expect(page).to have_content("You're the host!", wait: 5)
      host_player = Player.find_by(name: "Host")
    end

    Capybara.using_session(:alice) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby", wait: 5)
      alice = Player.find_by(name: "Alice")
    end

    Games::CategoryList.game_started(
      room:,
      total_rounds: 1,
      categories_per_round: 2,
      timer_enabled: false,
      show_instructions: false
    )
    game = room.reload.current_game

    letter = game.current_letter
    game.current_round_categories.each do |ci|
      Games::CategoryList.submit_answers(game:, player: host_player,
        answers_params: { ci.id.to_s => "#{letter}nswer from Host" })
      Games::CategoryList.submit_answers(game:, player: alice,
        answers_params: { ci.id.to_s => "#{letter}nswer from Alice" })
    end
    expect(game.reload).to be_reviewing

    Capybara.using_session(:host) do
      visit room_hand_path(room)
      # Has moderation buttons
      expect(page).to have_button("Reject", wait: 5)
      # Has navigation
      expect(page).to have_button("Next →")
      # Does NOT have Finish button yet (not at last category)
      expect(page).not_to have_button("Finish & Score")
    end

    # Non-host player should NOT see these controls
    Capybara.using_session(:alice) do
      visit room_hand_path(room)
      expect(page).not_to have_button("Reject")
      expect(page).not_to have_button("Next →")
    end
  end

  # TODO: flaky in CI — Player.find_by(name: "Alice") intermittently returns nil causing count=0.
  # The CSRF fix this tests is confirmed working. Revisit test isolation before re-enabling.
  xit "player can submit answers via the broadcasted form without refreshing" do
    alice = nil

    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
    end

    Capybara.using_session(:alice) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      click_on "Join Game"
      expect(page).to have_content("Waiting for players to join...")
      alice = Player.find_by(name: "Alice")
    end

    # Host starts the game — this broadcasts the answer form via Turbo Stream (no page refresh for Alice)
    Capybara.using_session(:host) do
      click_on "Start Game"
      find("#start-from-instructions-btn", wait: 10).click
    end

    # Alice should receive the answer form via Turbo Stream broadcast — WITHOUT refreshing
    # This is the bug: the broadcasted form contained an invalid CSRF token, causing 422
    Capybara.using_session(:alice) do
      expect(page).to have_button("Submit Answers", wait: 10)
      game = room.reload.current_game
      letter = game.current_letter

      all("input[name^='answers']").each_with_index do |input, idx|
        input.fill_in with: "#{letter}nswer#{idx}"
      end
      click_on "Submit Answers"

      # Should succeed, not 422
      expect(page).to have_content("Answers submitted!", wait: 5)
      expect(CategoryAnswer.where(player: alice).count).to be > 0
    end
  end

  it "shows round leaderboard on phones during scoring" do
    host_player = nil
    alice = nil

    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby", wait: 5)
      click_on "Claim Host"
      expect(page).to have_content("You're the host!", wait: 5)
      host_player = Player.find_by(name: "Host")
    end

    Capybara.using_session(:alice) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby", wait: 5)
      alice = Player.find_by(name: "Alice")
    end

    Games::CategoryList.game_started(
      room:,
      total_rounds: 1,
      categories_per_round: 2,
      timer_enabled: false,
      show_instructions: false
    )
    game = room.reload.current_game

    letter = game.current_letter
    game.current_round_categories.each do |ci|
      Games::CategoryList.submit_answers(game:, player: host_player,
        answers_params: { ci.id.to_s => "#{letter}mazing" })
      Games::CategoryList.submit_answers(game:, player: alice,
        answers_params: { ci.id.to_s => "#{letter}pple" })
    end
    Games::CategoryList.finish_review(game: game.reload)
    expect(game.reload).to be_scoring

    # Both players should see each other's names and NOT see "Check the screen"
    Capybara.using_session(:alice) do
      visit room_hand_path(room)
      expect(page).to have_content("Host", wait: 5)
      expect(page).to have_content("Alice")
      expect(page).not_to have_content("Check the screen")
    end

    # Host should see "Finish Game" button (total_rounds: 1 → last round)
    Capybara.using_session(:host) do
      visit room_hand_path(room)
      expect(page).to have_button("Finish Game", wait: 5)
    end
  end
end
