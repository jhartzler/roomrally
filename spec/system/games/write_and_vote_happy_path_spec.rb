require 'rails_helper'

RSpec.describe "Write and Vote Game Happy Path", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, game_type: "Write And Vote", user: nil) }

  before do
    # Ensure sufficient prompts exist for the game in the DEFAULT pack
    default_pack = FactoryBot.create(:prompt_pack, :default)
    FactoryBot.create_list(:prompt, 5, prompt_pack: default_pack)
  end

  it "allows players to join, start game, answer prompts, and reach voting" do
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby")
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
      expect(page).to have_button("Waiting for players (1/3)...", disabled: true)
      screenshot_checkpoint("lobby")
    end

    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Player 2"
      click_on "Join Game"
      expect(page).to have_content("Waiting for players to join...")
      screenshot_checkpoint("lobby")
    end

    Capybara.using_session(:player3) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Player 3"
      click_on "Join Game"
      expect(page).to have_content("Waiting for players to join...")
      screenshot_checkpoint("lobby")
    end

    Capybara.using_session(:host) do
      # Wait for turbo stream to update, or refresh if needed
      unless page.has_button?("Start Game", wait: 3)
        visit current_path
      end
      expect(page).to have_button("Start Game", wait: 5)
      click_on "Start Game"

      # Instructions screen shown for non-logged-in games
      expect(page).to have_content("Get ready!")

      # Host must advance past instructions - wait for and click the button with specific ID
      expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
      screenshot_checkpoint("instructions")
      find("#start-from-instructions-btn").click

      # Wait for turbo stream broadcast to update the page
      expect(page).to have_content("WRITE YOUR BEST ANSWER...", wait: 10)
      expect(page).to have_selector('[data-test-id="player-prompt"]', count: 2)
      screenshot_checkpoint("writing_phase")
    end

    [ :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        expect(page).to have_content("WRITE YOUR BEST ANSWER...")
        expect(page).to have_selector('[data-test-id="player-prompt"]', count: 2)
        screenshot_checkpoint("writing_phase")
      end
    end

    [
      [ :host, "Host" ],
      [ :player2, "Player 2" ],
      [ :player3, "Player 3" ]
    ].each do |session, player_name|
      Capybara.using_session(session) do
        2.times do |index|
          # In sequential mode, we only see the ACTIVE form.
          # We wait for *any* form to appear (the active one).
          expect(page).to have_selector('form[action^="/responses"]', count: 1, wait: 10)

          form = first('form[action^="/responses"]')

          within form do
            fill_in "response[body]", with: "#{player_name} Answer #{index + 1}"
            click_on "Submit"
          end

          # After submission, the next prompt becomes active (or we are done)
          # We wait for the "active" indicator to move or for Success/Vote screen.
          if index == 0
             # Wait for the first one to be marked submitted (or just wait for next form)
             expect(page).to have_content("Your answer has been submitted!", wait: 5)
          end
        end

        expect(page).to have_content("Your answer has been submitted!").or have_content("Vote for the best answer!")
      end
    end

    [ :host, :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        # Wait for broadcast, fallback to refresh if missed (race condition resilience)
        unless page.has_content?("Vote for the best answer!", wait: 2)
          visit current_path
        end

        expect(page).to have_content("Vote for the best answer!", wait: 10)
        expect(page).to have_selector(".voting-screen")
        screenshot_checkpoint("voting_phase")
      end
    end
  end
end
