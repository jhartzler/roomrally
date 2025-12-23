require 'rails_helper'

RSpec.describe "Backstages", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:room) { create(:room, user:) }

  describe "GET /rooms/:code/backstage" do
    context "when not logged in" do
      it "redirects to root" do
        get room_backstage_path(room.code)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when logged in as a different user" do
      before do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(other_user)
        # rubocop:enable RSpec/AnyInstance
      end

      it "redirects to root with alert" do
        get room_backstage_path(room.code)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("You are not authorized")
      end
    end

    context "when logged in as the room owner" do
      before do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
        # rubocop:enable RSpec/AnyInstance
      end

      it "returns http success" do
        get room_backstage_path(room.code)
        expect(response).to have_http_status(:success)
      end

      it "displays room info" do
        get room_backstage_path(room.code)
        expect(response.body).to include(room.code)
      end

      it "displays player list" do
        create(:player, room:, name: "Alice")
        get room_backstage_path(room.code)
        expect(response.body).to include("Alice")
      end

      it "displays moderation queue" do
        get room_backstage_path(room.code)
        expect(response.body).to include("Moderation Queue")
      end
    end
  end
end
