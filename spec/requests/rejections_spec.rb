require 'rails_helper'

RSpec.describe "Rejections", type: :request do
  let(:facilitator) { create(:user) }
  let(:room) { create(:room, user: facilitator) }
  # Chain creation to reduce memoized helpers count (max 5)
  # creating response implicitly creates player and prompt_instance
  # we just need to ensure they link to our room
  let(:player) { create(:player, room:) }
  let(:response_obj) do
    create(:response, status: "submitted",
      player:,
      prompt_instance: create(:prompt_instance,
        write_and_vote_game: create(:write_and_vote_game, room:)
      )
    )
  end

  describe "POST /responses/:response_id/rejections" do
    context "when acting as facilitator" do
      before do
        sign_in(facilitator)
      end

      it "rejects the response" do
        post response_rejections_path(response_obj)
        expect(response_obj.reload.status).to eq("rejected")
      end

      it "redirects back with notice" do
        post response_rejections_path(response_obj)
        expect(flash[:notice]).to eq("Response rejected.")
      end
    end

    context "when not authorized" do
      let(:other_user) { create(:user) }

      before do
        sign_in(other_user)
      end

      it "denies access" do
        post response_rejections_path(response_obj)
        expect(response).to redirect_to(root_path)
      end

      it "sets alert" do
        post response_rejections_path(response_obj)
        expect(flash[:alert]).to include("not authorized")
      end

      it "does not change status" do
        post response_rejections_path(response_obj)
        expect(response_obj.reload.status).to eq("submitted")
      end
    end
  end
end
