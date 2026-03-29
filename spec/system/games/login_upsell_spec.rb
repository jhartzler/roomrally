# spec/system/games/login_upsell_spec.rb
require 'rails_helper'

RSpec.describe "Post-game login upsell", :js, type: :system do
  let!(:room) { create(:room, game_type: "Speed Trivia", user: nil) }

  before do
    default_pack = create(:trivia_pack, :default)
    12.times do |i|
      create(:trivia_question,
        trivia_pack: default_pack,
        body: "Question #{i + 1}?",
        correct_answers: [ "Answer #{i + 1}" ],
        options: [ "Answer #{i + 1}", "Wrong A", "Wrong B", "Wrong C" ])
    end
  end

  def join_and_play_to_game_over
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

    Capybara.using_session(:player3) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Bob"
      click_on "Join Game"
    end

    # Host starts the game
    Capybara.using_session(:host) do
      unless page.has_button?("Start Game", wait: 3)
        visit current_path
      end
      click_on "Start Game"
      expect(page).to have_content("Get ready!")
      find("#start-from-instructions-btn", wait: 5).click
      expect(page).to have_button("Start First Question", wait: 5)
      click_on "Start First Question"
      expect(page).to have_content(/question 1/i, wait: 5)
    end

    # All players answer
    game = room.reload.current_game
    [ :host, :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        visit current_path
        find('[data-test-id="answer-option-0"]', match: :first, wait: 5).click
        expect(page).to have_content("Locked in!", wait: 5)
      end
    end

    # Fast-forward to game over
    game.update!(current_question_index: game.trivia_question_instances.count - 1)
    Games::SpeedTrivia.close_round(game: game.reload)
    Games::SpeedTrivia.next_question(game: game.reload)
    game
  end

  context "when host is logged out" do
    it "shows the upsell card" do
      join_and_play_to_game_over

      Capybara.using_session(:host) do
        visit current_path
        expect(page).to have_content(/game over/i, wait: 5).or have_content("Place", wait: 5)
        expect(page).to have_content("You just hosted like a pro")
        expect(page).to have_link("Sign up free", href: host_path)
      end
    end

    # Regression: "Sign up free" was inside <turbo-frame id="hand_screen">, so Turbo tried
    # to load /host into the frame instead of doing a full-page navigation, resulting in
    # "Content Missing". The link must carry data-turbo-frame="_top" to break out of the frame.
    it "navigates to the sign-up page on click, not 'content missing'" do
      join_and_play_to_game_over

      Capybara.using_session(:host) do
        visit current_path
        expect(page).to have_link("Sign up free", wait: 5)
        click_link "Sign up free"
        expect(page).not_to have_content("Content Missing", wait: 5)
        expect(page.current_path).to eq(host_path)
      end
    end
  end

  context "when player is not the host" do
    it "does not show the upsell card" do
      join_and_play_to_game_over

      Capybara.using_session(:player2) do
        visit current_path
        expect(page).to have_content(/game over/i, wait: 5).or have_content("Place", wait: 5)
        expect(page).not_to have_content("You just hosted like a pro")
      end
    end
  end

  context "when host is logged in (facilitator-owned room)" do
    let!(:facilitator) { create(:user) }
    let!(:room) { create(:room, game_type: "Speed Trivia", user: facilitator) }

    it "does not show the upsell card" do
      # Facilitator-owned rooms hide "Claim Host" — join players and set host directly
      Capybara.using_session(:host) do
        visit join_room_path(room)
        fill_in "player[name]", with: "Host"
        click_on "Join Game"
        expect(page).to have_content("Game Lobby")
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

      # Set host and drive game to finished via service methods
      host_player = room.players.find_by(name: "Host")
      room.update!(host: host_player)

      Games::SpeedTrivia.game_started(room:, timer_enabled: false, timer_increment: nil, show_instructions: false)
      game = room.reload.current_game
      Games::SpeedTrivia.start_question(game:)

      # All players answer
      game.trivia_question_instances.first.trivia_answers.create!(
        player: room.players.find_by(name: "Host"), selected_option: "Answer 1"
      )
      game.trivia_question_instances.first.trivia_answers.create!(
        player: room.players.find_by(name: "Alice"), selected_option: "Answer 1"
      )
      game.trivia_question_instances.first.trivia_answers.create!(
        player: room.players.find_by(name: "Bob"), selected_option: "Answer 1"
      )

      # Fast-forward to game over
      game.update!(current_question_index: game.trivia_question_instances.count - 1)
      Games::SpeedTrivia.close_round(game: game.reload)
      Games::SpeedTrivia.next_question(game: game.reload)

      Capybara.using_session(:host) do
        visit room_hand_path(room.code)
        expect(page).to have_content(/game over/i, wait: 5).or have_content("Place", wait: 5)
        expect(page).not_to have_content("You just hosted like a pro")
      end
    end
  end
end
