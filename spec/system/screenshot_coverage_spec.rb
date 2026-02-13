require "rails_helper"

RSpec.describe "Screenshot Coverage", :js, type: :system do
  before do
    skip "Screenshot-only spec; run with SCREENSHOTS=1" unless ENV["SCREENSHOTS"] == "1"
  end

  describe "Landing page" do
    it "captures the landing page" do
      visit root_path
      expect(page).to have_content("Host epic group games")
      screenshot_checkpoint("landing_page")
    end
  end

  describe "Play page" do
    it "captures the play page" do
      visit play_path
      expect(page).to have_button("Create Room")
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
      expect(page).to have_content("My Comedy Pack")
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
          correct_answers: ["Answer #{i + 1}"],
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

  describe "Category List game over hand view" do
    let!(:room) { FactoryBot.create(:room, game_type: "Category List", user: nil) }

    before do
      default_pack = FactoryBot.create(:category_pack, :default)
      12.times do |i|
        FactoryBot.create(:category, name: "Category #{i + 1}", category_pack: default_pack)
      end
    end

    it "captures the game over screen" do
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

      # Start game and skip instructions
      Capybara.using_session(:host) do
        unless page.has_button?("Start Game", wait: 3)
          visit current_path
        end
        expect(page).to have_button("Start Game", wait: 5)
        click_on "Start Game"
        expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
        find("#start-from-instructions-btn").click
      end

      # Drive game to finished via service calls
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
      Games::CategoryList.finish_review(game: game.reload)
      game.reload.update!(current_round: game.total_rounds)
      Games::CategoryList.next_round(game: game.reload)

      # Capture game over on hand views
      [ :host, :player2, :player3 ].each do |session|
        Capybara.using_session(session) do
          visit room_hand_path(room)
          expect(page).to have_content(/game over/i, wait: 5)
          screenshot_checkpoint("game_over")
        end
      end
    end
  end
end
