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
end
