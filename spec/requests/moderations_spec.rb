require 'rails_helper'

RSpec.describe "Moderations", type: :request do
  let(:user) { create(:user) }
  let(:room) { create(:room, user:) }
  let(:game) { create(:write_and_vote_game, room:) }
  let(:prompt) { create(:prompt_instance, write_and_vote_game: game) }
  let(:player) { create(:player, room:) }
  let(:response_obj) { create(:response, prompt_instance: prompt, player:, status: "submitted") }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  describe "PATCH /responses/:id/reject" do
    it "rejects the response and redirects back" do
      patch reject_response_path(response_obj)
      expect(response).to redirect_to(root_path) # Fallback since no HTTP_REFERER
      expect(response_obj.reload.status).to eq("rejected")
      expect(flash[:notice]).to eq("Response rejected.")
    end

    context "when not authorized" do
      let(:other_user) { create(:user) }

      before { allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(other_user) }

      it "denies access" do
        patch reject_response_path(response_obj)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("not authorized")
        expect(response_obj.reload.status).to eq("submitted")
      end
    end
  end
end
