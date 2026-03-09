require 'rails_helper'

RSpec.describe "Speed Trivia Lobby with 35 Players", :js, type: :system do
  it "displays a lobby with 35 players" do
    # Create default trivia pack (required for game settings form)
    default_pack = FactoryBot.create(:trivia_pack, :default)
    5.times do |i|
      FactoryBot.create(:trivia_question,
        trivia_pack: default_pack,
        body: "Test Question #{i + 1}?",
        correct_answers: [ "Answer #{i + 1}" ],
        options: [ "Answer #{i + 1}", "Wrong A", "Wrong B", "Wrong C" ])
    end

    # Create room
    room = FactoryBot.create(:room, game_type: "Speed Trivia", user: nil)

    # Have first player join via normal flow to establish session
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host Player"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby", wait: 5)

      # Claim host
      click_on "Claim Host"
      expect(page).to have_content("You're the host!", wait: 5)
    end

    # Create 34 additional players directly in the database
    34.times do |i|
      FactoryBot.create(:player,
        name: "Player #{i + 2}",
        room:,
        session_id: SecureRandom.uuid,
        status: :active
      )
    end

    # Refresh and take hand view screenshot
    Capybara.using_session(:host) do
      visit current_path
      expect(page).to have_content("Game Lobby", wait: 5)

      screenshot_checkpoint("lobby_35_players")
    end

    # Take stage view screenshot
    Capybara.using_session(:stage_viewer) do
      visit room_stage_path(room)
      expect(page).to have_content("The crowd is gathering", wait: 5)

      screenshot_checkpoint("stage_lobby_35_players")
    end
  end
end
