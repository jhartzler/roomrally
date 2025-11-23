require "rails_helper"

RSpec.describe "WriteAndVote game flow: Player Submission", :js, type: :system do
  it "allows a player to submit an answer to a prompt" do
    room = FactoryBot.create(:room, game_type: "Write And Vote")
    FactoryBot.create_list(:prompt, 5)

    # 1. Host joins
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host Player"
      click_on "Join Game"
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
    end

    # 2. Player 2 joins
    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Player 2"
      click_on "Join Game"
      expect(page).to have_content("Waiting for players to join...")
    end

    # 3. Host starts game
    Capybara.using_session(:host) do
      expect(page).to have_content("Host Player", wait: 10)
      click_on "Start Game"
      expect(page).to have_content("Game started!")
      expect(page).to have_selector('[data-test-id="player-prompt"]', count: 2)

      host_player = Player.find_by(name: "Host Player")
      prompt_instance = host_player.responses.first.prompt_instance

      within "#prompt-instance-#{prompt_instance.id}" do
        fill_in "response[body]", with: "42, of course."
        click_on "Submit"
      end
      sleep 2
      expect(page).to have_content("Your answer has been submitted!")
      expect(page).not_to have_selector("#prompt-instance-#{prompt_instance.id} form")

      response = host_player.responses.find_by(prompt_instance:)
      expect(response.body).to eq("42, of course.")
    end
  end
end
