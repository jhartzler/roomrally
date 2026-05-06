require 'rails_helper'

RSpec.describe "TriviaPacks", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe "GET /show" do
    let!(:global_pack) { create(:trivia_pack, :global) }

    it "returns http success for global packs" do
      get trivia_pack_path(global_pack)
      expect(response).to have_http_status(:success)
    end

    context "with another user's private pack" do
      let!(:private_pack) { create(:trivia_pack, user: create(:user)) }

      it "returns a 404" do
        get trivia_pack_path(private_pack)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /index" do
    let(:global_pack) { create(:trivia_pack, :global, name: "System Trivia") }

    it "returns http success" do
      get trivia_packs_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get new_trivia_pack_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /create" do
    let(:valid_attributes) do
      {
        name: "My Quiz",
        game_type: "Speed Trivia"
      }
    end

    it "creates a new TriviaPack" do
      expect {
        post trivia_packs_path, params: { trivia_pack: valid_attributes }
      }.to change(TriviaPack, :count).by(1)

      expect(response).to redirect_to(%r{/trivia_packs/\d+/edit})
    end

    context "with a valid return_to param" do
      it "redirects back with new_pack_id appended" do
        post trivia_packs_path,
          params: { trivia_pack: valid_attributes, return_to: "/game_templates/new" }
        expect(response).to redirect_to(%r{/game_templates/new\?.*new_pack_id=\d+})
      end
    end

    context "with an external return_to param" do
      it "falls back to pack edit (no open redirect)" do
        post trivia_packs_path,
          params: { trivia_pack: valid_attributes, return_to: "https://evil.com" }
        expect(response).to redirect_to(%r{/trivia_packs/\d+/edit})
      end
    end

    context "with a protocol-relative return_to param" do
      it "falls back to pack edit (no open redirect)" do
        post trivia_packs_path,
          params: { trivia_pack: valid_attributes, return_to: "//evil.com/path" }
        expect(response).to redirect_to(%r{/trivia_packs/\d+/edit})
      end
    end
  end

  describe "GET /edit" do
    let(:trivia_pack) { create(:trivia_pack, user:) }

    it "returns http success" do
      get edit_trivia_pack_path(trivia_pack)
      expect(response).to have_http_status(:success)
    end

    context "when another user owns the pack" do
      let(:other_pack) { create(:trivia_pack, user: create(:user)) }

      it "returns a 404" do
        get edit_trivia_pack_path(other_pack)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /update" do
    let(:trivia_pack) { create(:trivia_pack, user:) }

    it "updates and redirects" do
      patch trivia_pack_path(trivia_pack), params: { trivia_pack: { name: "Updated Name" } }
      expect(response).to redirect_to(trivia_packs_path)
    end

    context "when another user owns the pack" do
      let(:other_pack) { create(:trivia_pack, user: create(:user)) }

      it "returns a 404" do
        patch trivia_pack_path(other_pack), params: { trivia_pack: { name: "Updated Name" } }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /destroy" do
    let!(:trivia_pack) { create(:trivia_pack, user:) }

    it "destroys and redirects" do
      expect {
        delete trivia_pack_path(trivia_pack)
      }.to change(TriviaPack, :count).by(-1)
      expect(response).to redirect_to(trivia_packs_path)
    end

    context "when another user owns the pack" do
      let!(:other_pack) { create(:trivia_pack, user: create(:user)) }

      it "returns a 404" do
        delete trivia_pack_path(other_pack)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
