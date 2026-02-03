require 'rails_helper'

RSpec.describe "Speed Trivia Game Happy Path", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, game_type: "Speed Trivia", user: nil) }

  before do
    # Ensure sufficient trivia questions exist (need at least 10 for default game)
    default_pack = FactoryBot.create(:trivia_pack, :default)
    12.times do |i|
      FactoryBot.create(:trivia_question,
        trivia_pack: default_pack,
        body: "Test Question #{i + 1}?",
        correct_answer: "Answer #{i + 1}",
        options: [ "Answer #{i + 1}", "Wrong A", "Wrong B", "Wrong C" ])
    end
  end

  it "allows players to join, answer trivia questions, and see results" do
    # Host joins and claims host
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby")
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
    end

    # Other players join
    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      click_on "Join Game"
      expect(page).to have_content("Waiting for players to join...")
    end

    Capybara.using_session(:player3) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Bob"
      click_on "Join Game"
      expect(page).to have_content("Waiting for players to join...")
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
      find("#start-from-instructions-btn").click

      # Now in waiting state
      expect(page).to have_content("Get Ready!", wait: 5)
    end

    # All players should see "Get Ready" state
    [ :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        expect(page).to have_content("Get Ready!", wait: 5)
      end
    end

    # Host starts first question
    game = room.reload.current_game
    Games::SpeedTrivia.start_question(game:)

    # All players should see the question and answer options
    [ :host, :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        # Refresh to ensure we have the latest state
        visit current_path
        expect(page).to have_content(/question 1/i, wait: 5)
        expect(page).to have_selector('[data-test-id^="answer-option"]', minimum: 4)
      end
    end

    # Players answer the question
    [ :host, :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        # Click the first answer option (which is correct based on our seed data)
        first('[data-test-id="answer-option-0"]').click
        expect(page).to have_content("Answer submitted!", wait: 5)
      end
    end

    # Host closes the round
    Games::SpeedTrivia.close_round(game: game.reload)

    # All players should see their result
    [ :host, :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        visit current_path
        expect(page).to have_content("Correct!", wait: 5).or have_content("Wrong!", wait: 5)
      end
    end

    # Host advances to finish (only had 1 question set up for simplicity)
    # In a real game there would be more questions
    game.update!(current_question_index: game.trivia_question_instances.count - 1)
    Games::SpeedTrivia.next_question(game: game.reload)

    # All players should see game over
    [ :host, :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        visit current_path
        expect(page).to have_content(/game over/i, wait: 5).or have_content("Place", wait: 5)
      end
    end
  end
end
