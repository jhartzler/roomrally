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

      it "only shows active players in main player list" do
        create(:player, room:, name: "Active Alice", status: :active)
        pending_player = create(:player, room:, name: "Pending Bob", status: :pending_approval)
        get room_backstage_path(room.code)

        # Active Alice should be in the main player list
        expect(response.body).to include("Active Alice")

        # Pending Bob should be in waiting room section, not main player list
        # Check that the waiting room section exists and contains Pending Bob
        expect(response.body).to include("Waiting for Approval")
        expect(response.body).to include("Pending Bob")

        # Only 1 active player should be counted (not including pending)
        expect(response.body).to include("1 connected")
      end

      it "shows waiting room section when there are pending players" do
        create(:player, room:, status: :pending_approval, name: "Pending Bob")
        get room_backstage_path(room.code)
        expect(response.body).to include("Waiting for Approval")
        expect(response.body).to include("Pending Bob")
      end

      context "with Write And Vote game" do
        let(:game) { create(:write_and_vote_game) }

        before do
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
          room.update!(current_game: game)
        end

        it "does not display moderation queue" do
          get room_backstage_path(room.code)
          expect(response.body).not_to include("Moderation Queue")
        end
      end

      context "without a game" do
        it "does not display moderation queue" do
          get room_backstage_path(room.code)
          expect(response.body).not_to include("Moderation Queue")
        end
      end
    end
  end
end
