require "rails_helper"

# Targeted regression test for the cumulative score display bug:
# After Q1 correct answer, Q2 wrong answer should show Q1's points (non-zero)
# in the score panel at reviewing step 1. This spec verifies the score_from
# data attribute is correct — not just that the panel appears.
RSpec.describe "Speed Trivia Score Display", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, game_type: "Speed Trivia", user: nil) }

  before do
    default_pack = FactoryBot.create(:trivia_pack, :default)
    # All questions: option-0 is always correct, option-1 is always wrong
    12.times do |i|
      FactoryBot.create(:trivia_question,
        trivia_pack: default_pack,
        body: "Test Question #{i + 1}?",
        correct_answers: [ "Answer #{i + 1}" ],
        options: [ "Answer #{i + 1}", "Wrong A", "Wrong B", "Wrong C" ])
    end
  end

  it "shows cumulative Q1 score (non-zero) in score panel at Q2 step 1 after a wrong answer" do
    # Join all 3 players (room requires 3 to start)
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby")
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
    end

    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      click_on "Join Game"
      expect(page).to have_content("The crowd is gathering...")
    end

    Capybara.using_session(:player3) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Bob"
      click_on "Join Game"
      expect(page).to have_content("The crowd is gathering...")
    end

    # Host starts the game
    Capybara.using_session(:host) do
      unless page.has_button?("Start Game", wait: 3)
        visit current_path
      end
      expect(page).to have_button("Start Game", wait: 5)
      click_on "Start Game"
      expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
      find("#start-from-instructions-btn").click
      expect(page).to have_content("Get Ready!", wait: 5)
    end

    [ :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        expect(page).to have_content("Get Ready!", wait: 5)
      end
    end

    game = room.reload.current_game

    # --- Q1: All players answer CORRECTLY (option-0 is always correct) ---
    Games::SpeedTrivia.start_question(game:)

    [ :host, :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        visit current_path
        expect(page).to have_selector('[data-test-id="answer-option-0"]', wait: 5)
        find('[data-test-id="answer-option-0"]', match: :first).click
        expect(page).to have_content("Locked in!", wait: 5)
      end
    end

    # Close Q1 — calculate_scores! now runs immediately in close_round
    Games::SpeedTrivia.close_round(game: game.reload)

    host_player = room.reload.players.find_by(name: "Host")
    q1_score = host_player.score
    expect(q1_score).to be > 0, "Setup: Q1 correct answer should give >0 points, got #{q1_score}"

    # --- Q2: All players answer WRONG (option-1 is "Wrong A", always incorrect) ---
    Games::SpeedTrivia.next_question(game: game.reload)

    [ :host, :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        visit current_path
        expect(page).to have_selector('[data-test-id="answer-option-1"]', wait: 5)
        find('[data-test-id="answer-option-1"]', match: :first).click
        expect(page).to have_content("Locked in!", wait: 5)
      end
    end

    # Close Q2 round — step 1 should show Q1 cumulative (non-zero)
    Games::SpeedTrivia.close_round(game: game.reload)

    # Test via Turbo Stream (no page reload) — this is the real-browser path
    [ :host, :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        # Wait for Turbo Stream DOM update (no visit current_path)
        expect(page).to have_content("Not quite.", wait: 5)
        expect(page).to have_css("[data-controller='score-tally']", wait: 5)

        score_tally_el = find("[data-controller='score-tally']")
        from_value = score_tally_el["data-score-tally-from-value"].to_i
        to_value   = score_tally_el["data-score-tally-to-value"].to_i

        # Key assertion: score_from must be non-zero (Q1 correct carries over)
        expect(from_value).to be > 0,
          "score_from was 0 via Turbo Stream — cumulative score from Q1 was not carried over. " \
          "Expected at least #{SpeedTriviaGame::MINIMUM_POINTS} (minimum score)."
        # score_to must equal score_from (wrong answer adds 0 points)
        expect(to_value).to eq(from_value),
          "score_to (#{to_value}) != score_from (#{from_value}). Wrong answer should add 0 pts."
      end
    end
  end
end
