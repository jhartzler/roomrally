require "rails_helper"

RSpec.describe "End Game", :js, type: :system do
  describe "ending a game with scoreable data" do
    it "finishes speed trivia and shows game over screen" do
      room = create(:room, game_type: "Speed Trivia", status: "playing")
      game = create(:speed_trivia_game, status: "answering")
      host = create(:player, room:, name: "QuizHost")
      player1 = create(:player, room:, name: "Smarty")
      room.update!(current_game: game, host:)

      question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
      create(:trivia_answer, trivia_question_instance: question, player: player1, points_awarded: 1000)

      visit set_player_session_path(host)
      visit room_hand_path(room)

      accept_confirm do
        click_on "End Game"
      end

      expect(page).to have_content("STANDINGS")
      expect(game.reload.status).to eq("finished")
      expect(room.reload.status).to eq("finished")
    end
  end

  describe "ending a game without scoreable data" do
    it "resets speed trivia to lobby" do
      create(:trivia_pack, :default)
      room = create(:room, game_type: "Speed Trivia", status: "playing")
      game = create(:speed_trivia_game, status: "answering")
      host = create(:player, room:, name: "QuizHost")
      room.update!(current_game: game, host:)

      # No trivia answers — game has no scoreable data

      visit set_player_session_path(host)
      visit room_hand_path(room)

      accept_confirm do
        click_on "End Game"
      end

      expect(page).to have_content("You're the host")
      expect(room.reload.status).to eq("lobby")
      expect(room.current_game).to be_nil
    end
  end

  describe "confirmation dialog" do
    it "does not end the game when host declines confirmation" do
      room = create(:room, game_type: "Speed Trivia", status: "playing")
      game = create(:speed_trivia_game, status: "answering")
      host = create(:player, room:, name: "QuizHost")
      player1 = create(:player, room:, name: "Smarty")
      room.update!(current_game: game, host:)
      question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
      create(:trivia_answer, trivia_question_instance: question, player: player1, points_awarded: 1000)

      visit set_player_session_path(host)
      visit room_hand_path(room)

      dismiss_confirm do
        click_on "End Game"
      end

      # Game should still be in progress
      expect(game.reload.status).to eq("answering")
      expect(room.reload.status).to eq("playing")
      # End Game button should still be visible
      expect(page).to have_button("End Game")
    end
  end

  describe "non-host cannot end game" do
    it "does not show the End Game button to regular players" do
      room = create(:room, game_type: "Speed Trivia", status: "playing")
      game = create(:speed_trivia_game, status: "answering")
      host = create(:player, room:, name: "QuizHost")
      room.update!(current_game: game, host:)

      player = create(:player, room:, name: "Regular")

      visit set_player_session_path(player)
      visit room_hand_path(room)

      expect(page).not_to have_button("End Game")
    end
  end
end
