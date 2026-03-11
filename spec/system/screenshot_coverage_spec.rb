require "rails_helper"

RSpec.describe "Screenshot Coverage", :js, type: :system do
  before do
    skip "Screenshot-only spec; run with SCREENSHOTS=1" unless ENV["SCREENSHOTS"] == "1"
  end

  describe "Landing page" do
    it "captures the landing page" do
      visit root_path
      expect(page).to have_content("Join a Game")
      screenshot_checkpoint("landing_page")
    end
  end

  describe "Play page" do
    it "captures the play page" do
      visit play_path
      expect(page).to have_content("Join a Game")
      screenshot_checkpoint("play_page")
    end
  end

  describe "Dashboard" do
    let(:user) { FactoryBot.create(:user) }

    before { sign_in(user) }

    it "captures the empty dashboard" do
      visit dashboard_path
      expect(page).to have_content(user.name)
      screenshot_checkpoint("dashboard_empty")
    end

    it "captures the dashboard with active rooms and packs" do
      room = FactoryBot.create(:room, user:, game_type: "Write And Vote")
      FactoryBot.create(:prompt_pack, user:, name: "My Comedy Pack")
      FactoryBot.create(:prompt_pack, user:, name: "Party Pack")

      visit dashboard_path
      expect(page).to have_content(room.code)
      screenshot_checkpoint("dashboard_with_content")
    end
  end

  describe "Customize page" do
    let(:user) { FactoryBot.create(:user) }

    before { sign_in(user) }

    it "captures the customize hub" do
      visit customize_path
      expect(page).to have_content("Customize")
      screenshot_checkpoint("customize_page")
    end

    it "captures the customize hub with existing packs" do
      FactoryBot.create_list(:prompt_pack, 3, user:)
      FactoryBot.create_list(:trivia_pack, 2, user:)

      visit customize_path
      expect(page).to have_content("3")
      expect(page).to have_content("2")
      screenshot_checkpoint("customize_page_with_packs")
    end
  end

  describe "Speed Trivia stage views" do
    let!(:room) { FactoryBot.create(:room, game_type: "Speed Trivia", user: nil) }

    before do
      default_pack = FactoryBot.create(:trivia_pack, :default)
      12.times do |i|
        FactoryBot.create(:trivia_question,
          trivia_pack: default_pack,
          body: "Test Question #{i + 1}?",
          correct_answers: [ "Answer #{i + 1}" ],
          options: [ "Answer #{i + 1}", "Wrong A", "Wrong B", "Wrong C" ])
      end
    end

    it "captures stage views through all phases" do
      # Open stage view
      stage_window = open_new_window
      within_window stage_window do
        visit room_stage_path(room)
        expect(page).to have_content(room.code)
        screenshot_checkpoint("stage_lobby")
      end

      # Join 3 players
      3.times do |i|
        using_session "player_#{i}" do
          visit join_room_path(room.code)
          fill_in "player[name]", with: "Player #{i}"
          click_on "Join Game"
        end
      end

      within_window stage_window do
        expect(page).to have_content("Player 0")
        screenshot_checkpoint("stage_lobby_with_players")
      end

      # Start game and advance past instructions
      using_session "player_0" do
        click_on "Claim Host"
        expect(page).to have_button("Start Game", wait: 5)
        click_on "Start Game"
        expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
        find("#start-from-instructions-btn").click
      end

      within_window stage_window do
        expect(page).to have_content("Get Ready", wait: 5)
        screenshot_checkpoint("stage_waiting")
      end

      # Start a question
      game = room.reload.current_game
      Games::SpeedTrivia.start_question(game:)

      within_window stage_window do
        expect(page).to have_content(/question 1/i, wait: 5)
        screenshot_checkpoint("stage_answering")
      end

      # Submit answers and close round
      tqi = game.reload.trivia_question_instances[game.current_question_index]
      tqi.trivia_answers.destroy_all
      room.players.each do |player|
        TriviaAnswer.create!(
          player:,
          trivia_question_instance: tqi,
          selected_option: tqi.correct_answers.first,
          correct: true,
          submitted_at: Time.current
        )
      end
      Games::SpeedTrivia.close_round(game: game.reload)

      within_window stage_window do
        expect(page).to have_content("Correct", wait: 5).or have_content("Answer", wait: 5)
        screenshot_checkpoint("stage_reviewing")
        screenshot_animation("stage_podium_animation", duration: 2, fps: 5)
      end

      # Finish game
      game.update!(current_question_index: game.trivia_question_instances.count - 1)
      Games::SpeedTrivia.next_question(game: game.reload)

      within_window stage_window do
        expect(page).to have_content(/game over/i, wait: 5)
        screenshot_checkpoint("stage_finished")
      end
    end
  end

  describe "Category List stage views" do
    let!(:room) { FactoryBot.create(:room, game_type: "Category List", user: nil) }

    before do
      default_pack = FactoryBot.create(:category_pack, :default)
      12.times do |i|
        FactoryBot.create(:category, name: "Category #{i + 1}", category_pack: default_pack)
      end
    end

    it "captures stage views through all phases" do
      # Open stage view
      stage_window = open_new_window
      within_window stage_window do
        visit room_stage_path(room)
        expect(page).to have_content(room.code)
        screenshot_checkpoint("stage_lobby")
      end

      # Join 3 players
      3.times do |i|
        using_session "player_#{i}" do
          visit join_room_path(room.code)
          fill_in "player[name]", with: "Player #{i}"
          click_on "Join Game"
        end
      end

      # Start game
      using_session "player_0" do
        click_on "Claim Host"
        expect(page).to have_button("Start Game", wait: 5)
        click_on "Start Game"
        expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
        find("#start-from-instructions-btn").click
      end

      within_window stage_window do
        expect(page).to have_content(/round 1/i, wait: 10)
        screenshot_checkpoint("stage_filling")
      end

      # Submit answers for all players
      game = room.reload.current_game
      letter = game.current_letter
      room.players.each do |player|
        game.current_round_categories.each do |ci|
          CategoryAnswer.find_or_create_by!(player:, category_instance: ci) do |answer|
            answer.body = "#{letter}nswer"
          end
        end
      end

      # Trigger review transition
      game.with_lock do
        game.begin_review! if game.filling?
      end
      GameBroadcaster.broadcast_stage(room:)

      within_window stage_window do
        expect(page).to have_content(/review/i, wait: 5)
        screenshot_checkpoint("stage_reviewing")
      end

      # Move to scoring
      Games::CategoryList.finish_review(game: game.reload)

      within_window stage_window do
        expect(page).to have_content(/score/i, wait: 5).or have_content(/round 1/i, wait: 5)
        screenshot_checkpoint("stage_scoring")
      end

      # Finish game (set to last round, then next_round triggers finish)
      game.reload.update!(current_round: game.total_rounds)
      Games::CategoryList.next_round(game: game.reload)

      within_window stage_window do
        expect(page).to have_content(/game over/i, wait: 5)
        screenshot_checkpoint("stage_finished")
      end
    end
  end

  describe "Write and Vote stage views" do
    let!(:room) { FactoryBot.create(:room, game_type: "Write And Vote", user: nil) }

    before do
      default_pack = FactoryBot.create(:prompt_pack, :default)
      FactoryBot.create_list(:prompt, 10, prompt_pack: default_pack)
    end

    it "captures stage views through all phases" do
      stage_window = open_new_window
      within_window stage_window do
        visit room_stage_path(room)
        expect(page).to have_content(room.code)
      end

      # Join 3 players
      3.times do |i|
        using_session "player_#{i}" do
          visit join_room_path(room.code)
          fill_in "player[name]", with: "Player #{i}"
          click_on "Join Game"
        end
      end

      # Start game (instructions stage)
      using_session "player_0" do
        click_on "Claim Host"
        expect(page).to have_button("Start Game", wait: 5)
        click_on "Start Game"
      end

      within_window stage_window do
        expect(page).to have_content("How to Play", wait: 5)
        screenshot_checkpoint("stage_instructions")
      end

      # Advance past instructions (writing stage)
      using_session "player_0" do
        expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
        find("#start-from-instructions-btn").click
      end

      within_window stage_window do
        expect(page).to have_content("Look at your device!", wait: 5)
        screenshot_checkpoint("stage_writing")
      end

      # Submit all responses to trigger voting
      game = room.reload.current_game
      game.prompt_instances.where(round: 1).each do |pi|
        pi.responses.update_all(body: "Funny Answer", status: "submitted")
      end
      Games::WriteAndVote.check_all_responses_submitted(game: game.reload)

      within_window stage_window do
        expect(page).to have_content("Cast your votes now!", wait: 5)
        screenshot_checkpoint("stage_voting")
      end

      # Finish game via AASM transition
      game.reload
      game.with_lock { game.finish_game! }
      game.calculate_scores!
      GameBroadcaster.broadcast_stage(room:)

      within_window stage_window do
        expect(page).to have_content("Game Over!", wait: 5)
        screenshot_checkpoint("stage_finished")
        screenshot_animation("stage_finished_celebration", duration: 3, fps: 5)
      end
    end
  end

  describe "Write and Vote hand views" do
    let!(:room) { FactoryBot.create(:room, game_type: "Write And Vote", user: nil) }

    before do
      default_pack = FactoryBot.create(:prompt_pack, :default)
      FactoryBot.create_list(:prompt, 10, prompt_pack: default_pack)
    end

    it "captures hand views through all phases" do
      # Join players
      Capybara.using_session(:host) do
        visit join_room_path(room)
        fill_in "player[name]", with: "Host"
        click_on "Join Game"
        click_on "Claim Host"
      end

      Capybara.using_session(:player2) do
        visit join_room_path(room)
        fill_in "player[name]", with: "Alice"
        click_on "Join Game"
      end

      Capybara.using_session(:player3) do
        visit join_room_path(room)
        fill_in "player[name]", with: "Bob"
        click_on "Join Game"
      end

      # Start game — instructions hand view
      Capybara.using_session(:host) do
        unless page.has_button?("Start Game", wait: 3)
          visit current_path
        end
        click_on "Start Game"
        expect(page).to have_content("Get ready!", wait: 5)
        screenshot_checkpoint("hand_instructions_host")
        find("#start-from-instructions-btn").click
      end

      # Writing phase hand view
      Capybara.using_session(:host) do
        expect(page).to have_selector('[data-test-id="player-prompt"]', wait: 10)
        screenshot_checkpoint("hand_writing")
      end

      Capybara.using_session(:player2) do
        expect(page).to have_selector('[data-test-id="player-prompt"]', wait: 10)
        screenshot_checkpoint("hand_writing")
      end

      # Submit all responses to trigger voting
      game = room.reload.current_game
      game.prompt_instances.where(round: 1).each do |pi|
        pi.responses.update_all(body: "Hilarious Answer", status: "submitted")
      end
      Games::WriteAndVote.check_all_responses_submitted(game: game.reload)

      # Voting — capture both voter and author-waiting states
      [ :host, :player2, :player3 ].each do |session|
        Capybara.using_session(session) do
          unless page.has_content?("Vote for the best answer!", wait: 2) || page.has_content?("Your answer is up for a vote!", wait: 2)
            visit current_path
          end
          expect(page).to have_content("Vote for the best answer!", wait: 10)
                     .or have_content("Your answer is up for a vote!", wait: 10)

          if page.has_content?("Your answer is up for a vote!")
            screenshot_checkpoint("hand_voting_author_waiting")
          else
            screenshot_checkpoint("hand_voting_voter")
          end
        end
      end

      # Finish game via AASM
      game.reload
      game.with_lock { game.finish_game! }
      game.calculate_scores!
      GameBroadcaster.broadcast_hand(room:)

      Capybara.using_session(:host) do
        visit room_hand_path(room)
        expect(page).to have_content(/game over/i, wait: 5)
        screenshot_checkpoint("hand_game_over")
      end
    end
  end

  describe "Speed Trivia hand views" do
    let!(:room) { FactoryBot.create(:room, game_type: "Speed Trivia", user: nil) }

    before do
      default_pack = FactoryBot.create(:trivia_pack, :default)
      12.times do |i|
        FactoryBot.create(:trivia_question,
          trivia_pack: default_pack,
          body: "Test Question #{i + 1}?",
          correct_answers: [ "Answer #{i + 1}" ],
          options: [ "Answer #{i + 1}", "Wrong A", "Wrong B", "Wrong C" ])
      end
    end

    it "captures hand views through all phases" do
      # Join players
      Capybara.using_session(:host) do
        visit join_room_path(room)
        fill_in "player[name]", with: "Host"
        click_on "Join Game"
        click_on "Claim Host"
      end

      Capybara.using_session(:player2) do
        visit join_room_path(room)
        fill_in "player[name]", with: "Alice"
        click_on "Join Game"
      end

      Capybara.using_session(:player3) do
        visit join_room_path(room)
        fill_in "player[name]", with: "Bob"
        click_on "Join Game"
      end

      # Start game — instructions
      Capybara.using_session(:host) do
        unless page.has_button?("Start Game", wait: 3)
          visit current_path
        end
        click_on "Start Game"
        expect(page).to have_content("Get ready!", wait: 5)
        screenshot_checkpoint("hand_instructions_host")
        find("#start-from-instructions-btn").click
      end

      # Waiting / Get Ready
      Capybara.using_session(:host) do
        expect(page).to have_content("Get Ready!", wait: 5)
        screenshot_checkpoint("hand_get_ready_host")
      end

      Capybara.using_session(:player2) do
        expect(page).to have_content("Get Ready!", wait: 5)
        screenshot_checkpoint("hand_get_ready")
      end

      # Start question — answering
      game = room.reload.current_game
      Games::SpeedTrivia.start_question(game:)

      Capybara.using_session(:player2) do
        visit room_hand_path(room)
        expect(page).to have_selector('[data-test-id^="answer-option"]', minimum: 4, wait: 5)
        screenshot_checkpoint("hand_answering")
      end

      # Player answers — locked in
      Capybara.using_session(:player2) do
        find('[data-test-id="answer-option-0"]', match: :first).click
        expect(page).to have_content("Locked in!", wait: 5)
        screenshot_checkpoint("hand_locked_in")
      end

      # Submit remaining answers programmatically (player2 already answered via browser)
      tqi = game.reload.trivia_question_instances[game.current_question_index]

      host_player = room.players.find_by(name: "Host")
      bob = room.players.find_by(name: "Bob")

      # Host answers correctly
      TriviaAnswer.find_or_create_by!(player: host_player, trivia_question_instance: tqi) do |a|
        a.selected_option = tqi.correct_answers.first
        a.correct = true
        a.submitted_at = Time.current
      end
      # Bob answers wrong
      TriviaAnswer.find_or_create_by!(player: bob, trivia_question_instance: tqi) do |a|
        a.selected_option = "Wrong A"
        a.correct = false
        a.submitted_at = Time.current
      end

      Games::SpeedTrivia.close_round(game: game.reload)

      # Reviewing — correct answer
      Capybara.using_session(:host) do
        visit room_hand_path(room)
        expect(page).to have_content("That's the one!", wait: 5)
        screenshot_checkpoint("hand_reviewing_correct")
        screenshot_animation("hand_score_tally", duration: 2, fps: 5)
      end

      # Reviewing — wrong answer
      Capybara.using_session(:player3) do
        visit room_hand_path(room)
        expect(page).to have_content("Not quite.", wait: 5)
        screenshot_checkpoint("hand_reviewing_wrong")
      end

      # Game over
      game.update!(current_question_index: game.trivia_question_instances.count - 1)
      Games::SpeedTrivia.next_question(game: game.reload)

      Capybara.using_session(:host) do
        visit room_hand_path(room)
        expect(page).to have_content(/game over/i, wait: 5)
        screenshot_checkpoint("hand_game_over")
      end
    end
  end

  describe "Category List hand views" do
    let!(:room) { FactoryBot.create(:room, game_type: "Category List", user: nil) }

    before do
      default_pack = FactoryBot.create(:category_pack, :default)
      12.times do |i|
        FactoryBot.create(:category, name: "Category #{i + 1}", category_pack: default_pack)
      end
    end

    it "captures hand views through all phases" do
      # Join players
      Capybara.using_session(:host) do
        visit join_room_path(room)
        fill_in "player[name]", with: "Host"
        click_on "Join Game"
        click_on "Claim Host"
      end

      Capybara.using_session(:player2) do
        visit join_room_path(room)
        fill_in "player[name]", with: "Alice"
        click_on "Join Game"
      end

      Capybara.using_session(:player3) do
        visit join_room_path(room)
        fill_in "player[name]", with: "Bob"
        click_on "Join Game"
      end

      # Start game — instructions
      Capybara.using_session(:host) do
        unless page.has_button?("Start Game", wait: 3)
          visit current_path
        end
        click_on "Start Game"
        expect(page).to have_content("Get ready!", wait: 5)
        screenshot_checkpoint("hand_instructions_host")
        find("#start-from-instructions-btn").click
      end

      # Filling phase — answer form
      Capybara.using_session(:player2) do
        expect(page).to have_button("Submit Answers", wait: 10)
        screenshot_checkpoint("hand_filling")
      end

      # Submit answers for all players
      game = room.reload.current_game
      letter = game.current_letter
      room.players.each do |player|
        game.current_round_categories.each do |ci|
          CategoryAnswer.find_or_create_by!(player:, category_instance: ci) do |answer|
            answer.body = "#{letter}nswer"
          end
        end
      end
      game.with_lock { game.begin_review! if game.filling? }
      GameBroadcaster.broadcast_hand(room:)

      # Reviewing — host sees moderation controls
      Capybara.using_session(:host) do
        visit room_hand_path(room)
        expect(page).to have_button("Reject", wait: 5)
        screenshot_checkpoint("hand_reviewing_host")
      end

      # Reviewing — non-host sees read-only answer list
      Capybara.using_session(:player2) do
        visit room_hand_path(room)
        expect(page).to have_content("Host is judging answers", wait: 5)
        screenshot_checkpoint("hand_reviewing_player")
      end

      # Scoring
      Games::CategoryList.finish_review(game: game.reload)

      Capybara.using_session(:host) do
        visit room_hand_path(room)
        expect(page).to have_content(/Round 1 Scores/i, wait: 5)
        screenshot_checkpoint("hand_scoring_host")
      end

      Capybara.using_session(:player2) do
        visit room_hand_path(room)
        expect(page).to have_content(/Round 1 Scores/i, wait: 5)
        screenshot_checkpoint("hand_scoring")
      end

      # Game over
      game.reload.update!(current_round: game.total_rounds)
      Games::CategoryList.next_round(game: game.reload)

      Capybara.using_session(:host) do
        visit room_hand_path(room)
        expect(page).to have_content(/game over/i, wait: 5)
        screenshot_checkpoint("hand_game_over")
      end
    end
  end

  describe "Backstage during gameplay" do
    let!(:facilitator) { FactoryBot.create(:user) }
    let!(:room) { FactoryBot.create(:room, user: facilitator, game_type: "Write And Vote") }
    let!(:prompt_pack) { FactoryBot.create(:prompt_pack, :default) }

    before do
      room.update!(prompt_pack:)
      FactoryBot.create_list(:prompt, 5, prompt_pack:)
    end

    it "captures backstage with game in progress" do
      # Join players via factory (faster than UI for setup)
      FactoryBot.create(:player, room:, name: "Alice")
      FactoryBot.create(:player, room:, name: "Bob")
      FactoryBot.create(:player, room:, name: "Charlie")

      # Start game (transition room to playing, then start game logic)
      room.start_game!
      Games::WriteAndVote.game_started(room:, show_instructions: false)
      game = room.reload.current_game

      # Submit a response so moderation queue has content
      pi = game.prompt_instances.where(round: 1).first
      response = pi.responses.first
      response.update!(body: "A hilarious answer", status: "submitted") if response

      # Visit backstage as facilitator
      sign_in(facilitator)
      visit room_backstage_path(room.code)
      expect(page).to have_content("Backstage: #{room.code}")
      expect(page).to have_content("Playing")
      screenshot_checkpoint("backstage_game_in_progress")
    end
  end
end
