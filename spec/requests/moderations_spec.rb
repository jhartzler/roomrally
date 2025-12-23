require 'rails_helper'

RSpec.describe "Moderations", type: :request do
  let(:user) { create(:user) }

  describe "PATCH /responses/:id/reject" do
    let(:room) { create(:room, user:) }
    # Setup full response chain to ensure associations exist
    let(:response_obj) { create(:response, status: "submitted", player: create(:player, room:)) }

    before do
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      # rubocop:enable RSpec/AnyInstance
    end

    it "rejects the response" do
      patch reject_response_path(response_obj)
      expect(response_obj.reload.status).to eq("rejected")
    end

    it "redirects back with notice" do
      patch reject_response_path(response_obj)
      expect(flash[:notice]).to eq("Response rejected.")
    end

    context "when not authorized" do
      before do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(create(:user))
        # rubocop:enable RSpec/AnyInstance
      end

      it "denies access" do
        patch reject_response_path(response_obj)
        expect(response).to redirect_to(root_path)
      end

      it "sets alert" do
        patch reject_response_path(response_obj)
        expect(flash[:alert]).to include("not authorized")
      end

      it "does not change status" do
        patch reject_response_path(response_obj)
        expect(response_obj.reload.status).to eq("submitted")
      end
    end
  end
end
