require "rails_helper"

RSpec.describe "CategoryAnswers", type: :request do
  describe "PATCH /category_answers/:id" do
    let(:game) { create(:category_list_game, status: "reviewing") }
    let(:room) { create(:room, current_game: game, game_type: "Category List") }
    let(:host_player) { create(:player, room:) }
    let(:category_instance) { create(:category_instance, category_list_game: game) }
    let!(:category_answer) { create(:category_answer, player: host_player, category_instance:) }

    before do
      room.update!(host: host_player)
      get set_player_session_path(host_player)
    end

    it "moderates the answer when the caller is the host" do
      patch category_answer_url(category_answer),
            params: { category_answer: { status: "rejected" }, code: room.code },
            as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(category_answer.reload).to be_rejected
    end

    it "returns 404 when the answer belongs to another room" do
      other_room = create(:room, game_type: "Category List")
      other_game = create(:category_list_game, status: "reviewing")
      other_room.update!(current_game: other_game)
      other_ci = create(:category_instance, category_list_game: other_game)
      other_answer = create(:category_answer, category_instance: other_ci)

      patch category_answer_url(other_answer),
            params: { category_answer: { status: "rejected" }, code: room.code },
            as: :turbo_stream

      expect(response).to have_http_status(:not_found)
      expect(other_answer.reload).not_to be_rejected
    end
  end
end
