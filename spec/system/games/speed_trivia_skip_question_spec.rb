require 'rails_helper'

RSpec.describe "Speed Trivia Skip Question", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, game_type: "Speed Trivia", user: nil) }

  before do
    default_pack = FactoryBot.create(:trivia_pack, :default)
    5.times do |i|
      FactoryBot.create(:trivia_question,
        trivia_pack: default_pack,
        body: "Question #{i + 1} body?",
        correct_answers: [ "Answer #{i + 1}" ],
        options: [ "Answer #{i + 1}", "Wrong A", "Wrong B", "Wrong C" ])
    end
  end

  it "host skips a question and it is never shown to players" do
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
    Capybara.using_session(:player1) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      click_on "Join Game"
      expect(page).to have_content("The crowd is gathering...")
    end

    # Host starts game
    Capybara.using_session(:host) do
      expect(page).to have_button("Start Game", wait: 5)
      click_on "Start Game"
      expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
      find("#start-from-instructions-btn").click
      expect(page).to have_button("Start First Question", wait: 5)
    end

    # Play through question 1: start, answer, close
    game = room.reload.current_game
    Games::SpeedTrivia.start_question(game:)

    Capybara.using_session(:host) do
      expect(page).to have_content("Question 1 body?", wait: 5)
    end

    # Stage shows question 1
    Capybara.using_session(:stage) do
      visit room_stage_path(room)
      expect(page).to have_content("Question 1 body?", wait: 5)
    end

    # Player answers
    Capybara.using_session(:player1) do
      expect(page).to have_selector('[data-test-id="answer-option-0"]', wait: 5)
      find('[data-test-id="answer-option-0"]', match: :first).click
    end

    # Close the round
    Games::SpeedTrivia.close_round(game: game.reload)

    # Host is now in reviewing state — should see skip button
    Capybara.using_session(:host) do
      visit current_path
      expect(page).to have_content("Reviewing", wait: 5)
      expect(page).to have_button("Next Question", wait: 5)
      expect(page).to have_button("Skip Next Question")

      # Preview shows next question
      expect(page).to have_content("Up next:")
      expect(page).to have_content("Question 2 body?")

      # Skip question 2
      click_on "Skip Next Question"

      # Now preview shows question 3 (question 2 was skipped)
      expect(page).to have_content("Question 3 body?", wait: 5)
    end

    # Advance to the next question (should be question 3, not 2)
    game.reload
    Games::SpeedTrivia.next_question(game:)

    # Stage should show question 3, never question 2
    Capybara.using_session(:stage) do
      expect(page).to have_content("Question 3 body?", wait: 5)
      expect(page).not_to have_content("Question 2 body?")
    end

    # Verify question counter shows objective numbering (3 of 5)
    Capybara.using_session(:host) do
      expect(page).to have_content("Question 3 of 5", wait: 5)
    end
  end

  it "host skips multiple questions in a row" do
    # Host joins, claims host, starts game
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      click_on "Claim Host"
      expect(page).to have_button("Start Game", wait: 5)
      click_on "Start Game"
      expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
      find("#start-from-instructions-btn").click
      expect(page).to have_button("Start First Question", wait: 5)
    end

    # Play through question 1
    game = room.reload.current_game
    Games::SpeedTrivia.start_question(game:)
    Games::SpeedTrivia.close_round(game: game.reload)

    # Skip questions 2, 3, and 4
    Capybara.using_session(:host) do
      visit current_path
      expect(page).to have_button("Skip Next Question", wait: 5)
      click_on "Skip Next Question"
      expect(page).to have_content("Question 3 body?", wait: 5)

      click_on "Skip Next Question"
      expect(page).to have_content("Question 4 body?", wait: 5)

      click_on "Skip Next Question"
      expect(page).to have_content("Question 5 body?", wait: 5)

      # No more questions after 5 — skip button should be gone
      expect(page).not_to have_button("Skip Next Question")
      expect(page).to have_button("Next Question")
    end
  end

  it "skip button disappears when on the last question" do
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      click_on "Claim Host"
      expect(page).to have_button("Start Game", wait: 5)
      click_on "Start Game"
      expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
      find("#start-from-instructions-btn").click
      expect(page).to have_button("Start First Question", wait: 5)
    end

    # Fast-forward to the last question via service calls
    game = room.reload.current_game

    # Play questions 1-4
    4.times do
      Games::SpeedTrivia.start_question(game: game.reload)
      Games::SpeedTrivia.close_round(game: game.reload)
      Games::SpeedTrivia.next_question(game: game.reload) if game.reload.questions_remaining?
    end

    # Now on question 5 (last), close it
    Games::SpeedTrivia.close_round(game: game.reload) if game.reload.answering?

    Capybara.using_session(:host) do
      visit current_path
      expect(page).to have_button("Finish Game", wait: 5)
      expect(page).not_to have_button("Skip Next Question")
    end
  end
end
