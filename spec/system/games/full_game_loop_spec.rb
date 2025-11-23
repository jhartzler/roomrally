require 'rails_helper'

RSpec.describe "Full Game Loop", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, game_type: "Write And Vote") }

  before do
    # Ensure we have enough prompts for the game logic
    FactoryBot.create_list(:prompt, 10)
  end

  it "allows a host and players to play through the Write and Vote game" do
    # 1. Host joins and claims host
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host Player"
      click_on "Join Game"
      expect(page).to have_content("Host Player")

      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
      expect(page).to have_button("Start Game")
    end

    # 2. Player 2 joins
    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Player 2"
      click_on "Join Game"
      expect(page).to have_content("Player 2")
      expect(page).to have_content("Waiting for players to join...")
    end

    # 3. Host sees Player 2 and starts game
    Capybara.using_session(:host) do
      expect(page).to have_content("Player 2")
      click_on "Start Game"
      expect(page).to have_content("Game started!")
      expect(page).to have_selector('[data-test-id="player-prompt"]', count: 2)
    end

    # 4. Player 2 sees game started
    Capybara.using_session(:player2) do
      expect(page).to have_content("Your Prompts")
      expect(page).to have_selector('[data-test-id="player-prompt"]', count: 2)
    end

    # 5. Host submits answers
    Capybara.using_session(:host) do
      host_player = Player.find_by(name: "Host Player")
      prompt_instance = host_player.responses.first.prompt_instance

      within "#prompt-instance-#{prompt_instance.id}" do
        fill_in "response[body]", with: "Host Answer 1"
        click_on "Submit"
      end
      expect(page).to have_content("Your answer has been submitted!")
      expect(page).not_to have_selector("#prompt-instance-#{prompt_instance.id} form")
    end

    # 6. Player 2 submits answers
    Capybara.using_session(:player2) do
      player2 = Player.find_by(name: "Player 2")
      prompt_instance = player2.responses.first.prompt_instance

      within "#prompt-instance-#{prompt_instance.id}" do
        fill_in "response[body]", with: "Player 2 Answer 1"
        click_on "Submit"
      end
      expect(page).to have_content("Your answer has been submitted!")
    end
  end
end
