require 'rails_helper'

RSpec.describe "Write and Vote Game Happy Path", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, game_type: "Write And Vote", user: nil) }

  before do
    # Ensure sufficient prompts exist for the game in the DEFAULT pack
    default_pack = FactoryBot.create(:prompt_pack, :default)
    FactoryBot.create_list(:prompt, 5, prompt_pack: default_pack)
  end

  it "allows players to join, start game, answer prompts, and reach voting" do
    # --- PHASE 1: LOBBY & START ---

    # 1. Host Joins
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby")
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
        # Fill in both prompt responses
        # We re-find the forms each time because submitting one triggers a Turbo update
        # which invalidates the form elements (StaleElementReferenceError)
        2.times do |index|
          # Find the first available form that hasn't been submitted (implied by presence)
          # Assuming submitted forms are removed or replaced.
          # If they remain, we might need more specific selector.
          # But let's assume finding the first one works if we fill it.
          # Wait, if we have 2 forms, we fill first. It submits.
          # If it stays but shows "Submitted", does it still have form tag?
          # If Yes, we must distinguish.
          # But for now, let's try finding the form that contains the visible input.
          form = first('form[action^="/responses"]')

          within form do
            fill_in "response[body]", with: "#{player_name} Answer #{index + 1}"
            click_on "Submit"
          end

          # Wait for submission to complete (form disappears or message appears)
          expect(page).to have_content("Your answer has been submitted!", wait: 2)

          # Wait for the form to effectively disappear from the "active" set if logic allows?
          # Or if we have 2 prompts, and one is submitted, maybe only 1 form remains?
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
