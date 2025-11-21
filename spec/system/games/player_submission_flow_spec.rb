require "rails_helper"

RSpec.describe "WriteAndVote game flow: Player Submission", :js, type: :system do
  it "allows a player to submit an answer to a prompt" do
    # 1. Setup
    room = FactoryBot.create(:room, game_type: "Write And Vote")
    FactoryBot.create_list(:prompt, 5) # Create 5 master prompts
    player2 = FactoryBot.create(:player, room:, name: "Player 2")

    Capybara.using_session(:host_player) do
      # 2. Action
      # A player joins and becomes the host.
      visit join_room_path(room)
      fill_in "player[name]", with: "Host Player"
      click_on "Join Game"

      # The host clicks the "Start Game" button
      click_on "Start Game"

      # We expect the page to show the prompt text.
      expect(page).to have_selector('[data-test-id="player-prompt"]', count: 2)
      
      # The player fills in their answer and submits it.
      host_player = Player.find_by(name: "Host Player")
      prompt_instance = host_player.responses.first.prompt_instance
      
      within "#prompt-instance-#{prompt_instance.id}" do
        fill_in "response[body]", with: "42, of course."
        click_on "Submit"
      end

      # 3. Assertions
      # The player should see a success message.
      expect(page).to have_content("Your answer has been submitted!")

      # The form should be gone.
      expect(page).not_to have_selector("#prompt-instance-#{prompt_instance.id} form")

      # The response in the database should be updated.
      response = host_player.responses.find_by(prompt_instance:)
      expect(response.body).to eq("42, of course.")
    end
  end
end
