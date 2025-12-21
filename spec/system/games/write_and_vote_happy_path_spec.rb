require 'rails_helper'

RSpec.describe "Write and Vote Game Happy Path", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, game_type: "Write And Vote") }

  before do
    # Ensure sufficient prompts exist for the game
    FactoryBot.create_list(:prompt, 5)
  end

  it "allows players to join, start game, answer prompts, and reach voting" do
    # --- PHASE 1: LOBBY & START ---

    # 1. Host Joins
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
      expect(page).to have_button("Waiting for players (1/3)...", disabled: true)
    end

    # 2. Player 2 Joins
    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Player 2"
      click_on "Join Game"
      expect(page).to have_content("Waiting for players to join...")
    end

    # 3. Player 3 Joins
    Capybara.using_session(:player3) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Player 3"
      click_on "Join Game"
      expect(page).to have_content("Waiting for players to join...")
    end

    # 4. Host Starts Game
    Capybara.using_session(:host) do
      expect(page).to have_button("Start Game")
      click_on "Start Game"

      # Verify Game Started
      expect(page).to have_content("Game started!")
      expect(page).to have_content("Your Prompts")
      expect(page).to have_selector('[data-test-id="player-prompt"]', count: 2)
    end

    # --- PHASE 2: WRITING ---

    # Verify all players see prompts
    [ :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        expect(page).to have_content("Your Prompts")
        expect(page).to have_selector('[data-test-id="player-prompt"]', count: 2)
      end
    end

    # Submit Answers for ALL players
    [
      [ :host, "Host" ],
      [ :player2, "Player 2" ],
      [ :player3, "Player 3" ]
    ].each do |session, player_name|
      Capybara.using_session(session) do
        # Wait for the forms to appear
        expect(page).to have_selector('form[action^="/responses"]', count: 2, wait: 10)

        # Fill in both prompt responses using the forms on page
        # The forms have actions like /responses/123, so we match on the prefix
        forms = all('form[action^="/responses"]')
        expect(forms.count).to eq(2)

        forms.each_with_index do |form, index|
          within form do
            fill_in "response[body]", with: "#{player_name} Answer #{index + 1}"
            click_on "Submit"
          end
        end

        # After submitting, we expect success message OR immediate transition to voting
        # verifying either is sufficient to prove submission worked
        expect(page).to have_content("Your answer has been submitted!").or have_content("Vote for the best answer!")
      end
    end

    # --- PHASE 3: VOTING ---

    # After all answers submitted, everyone should transition to Voting
    # We verify this transition occurs to prove the game loop proceeded.

    [ :host, :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        expect(page).to have_content("Vote for the best answer!", wait: 10)
        # Should see a voting prompt
        expect(page).to have_selector(".voting-screen")
      end
    end

    # Success! We've proven the loop works up to voting.
  end
end
