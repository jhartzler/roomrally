require "rails_helper"

RSpec.describe "Speed Trivia with variable option counts", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, game_type: "Speed Trivia", user: nil) }

  before do
    pack = FactoryBot.create(:trivia_pack, :default)
    # Position 1: 2-option poll
    FactoryBot.create(:trivia_question,
      trivia_pack: pack,
      body: "Who will change more diapers?",
      options: [ "John", "Janice" ],
      correct_answers: [ "John", "Janice" ],
      position: 1
    )
    # Position 2: 4-option trivia
    FactoryBot.create(:trivia_question,
      trivia_pack: pack,
      body: "What is the capital of France?",
      options: [ "Paris", "London", "Berlin", "Madrid" ],
      correct_answers: [ "Paris" ],
      position: 2
    )
  end

  it "plays through a 2-option poll question then a 4-option trivia question" do
    # Host joins and claims host
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby")
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
    end

    # Player joins
    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      click_on "Join Game"
      expect(page).to have_content("The crowd is gathering...")
    end

    # Start game via service (skip instructions, 2 questions, sorted by position)
    Games::SpeedTrivia.game_started(room:, question_count: 2, show_instructions: false, timer_enabled: false)
    game = room.reload.current_game

    # Start question 1 (2-option poll)
    Games::SpeedTrivia.start_question(game: game.reload)

    # Stage should show 2-option question
    Capybara.using_session(:host) do
      visit room_stage_path(room)
      expect(page).to have_content("Who will change more diapers?", wait: 5)
      expect(page).to have_content("John", wait: 5)
      expect(page).to have_content("Janice", wait: 5)
    end

    # Player hand should show exactly 2 options (not 3 or 4)
    Capybara.using_session(:player2) do
      visit current_path
      expect(page).to have_css('[data-test-id="answer-option-0"]', wait: 5)
      expect(page).to have_css('[data-test-id="answer-option-1"]', wait: 5)
      expect(page).not_to have_css('[data-test-id="answer-option-2"]')
      find('[data-test-id="answer-option-0"]', match: :first).click
      expect(page).to have_content("Locked in!", wait: 5)
    end

    Capybara.using_session(:host) do
      visit room_hand_path(room)
      find('[data-test-id="answer-option-0"]', match: :first).click
      expect(page).to have_content("Locked in!", wait: 5)
    end

    # Close round — results should show percentage breakdown
    Games::SpeedTrivia.close_round(game: game.reload)

    Capybara.using_session(:host) do
      visit room_stage_path(room)
      # Both players voted for option A — 100% on John, 0% on Janice
      expect(page).to have_content("100%", wait: 5)
      expect(page).to have_content(/2 votes/i, wait: 5)
      expect(page).to have_content("0%", wait: 5)
    end

    # Advance to question 2 (4-option question)
    Games::SpeedTrivia.next_question(game: game.reload)

    # Stage should show 4-option question
    Capybara.using_session(:host) do
      visit room_stage_path(room)
      expect(page).to have_content("What is the capital of France?", wait: 5)
      expect(page).to have_content("Paris", wait: 5)
      expect(page).to have_content("Madrid", wait: 5)
    end

    # Player hand should show 4 options (including the 4th)
    Capybara.using_session(:player2) do
      visit current_path
      expect(page).to have_css('[data-test-id="answer-option-0"]', wait: 5)
      expect(page).to have_css('[data-test-id="answer-option-3"]', wait: 5)
    end
  end
end
