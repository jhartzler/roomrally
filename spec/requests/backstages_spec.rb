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

      it "shows active players in main player list" do
        create(:player, room:, name: "Active Alice", status: :active)
        get room_backstage_path(room.code)
        expect(response.body).to include("Active Alice")
      end

      it "counts only active players" do
        create(:player, room:, status: :active)
        create(:player, room:, status: :pending_approval)
        get room_backstage_path(room.code)
        expect(response.body).to include("1 connected")
      end

      it "shows pending players in waiting room section" do
        create(:player, room:, status: :pending_approval, name: "Pending Bob")
        get room_backstage_path(room.code)
        expect(response.body).to include("Waiting Room")
        expect(response.body).to include("Pending Bob")
      end
    end

    context "with Write And Vote game" do
      let(:game) { create(:write_and_vote_game) }

      before do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
        # rubocop:enable RSpec/AnyInstance
        room.update!(current_game: game)
      end

      it "displays moderation queue" do
        get room_backstage_path(room.code)
        expect(response.body).to include("Moderation Queue")
      end
    end

    context "with Speed Trivia game" do
      let(:game) { create(:speed_trivia_game) }

      before do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
        # rubocop:enable RSpec/AnyInstance
        room.update!(current_game: game)
      end

      it "does not display moderation queue" do
        get room_backstage_path(room.code)
        expect(response.body).not_to include("Moderation Queue")
      end
    end

    context "without a game" do
      before do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
        # rubocop:enable RSpec/AnyInstance
      end

      it "does not display moderation queue" do
        get room_backstage_path(room.code)
        expect(response.body).not_to include("Moderation Queue")
      end
    end
  end
end
