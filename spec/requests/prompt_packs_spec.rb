require 'rails_helper'

RSpec.describe "PromptPacks", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe "GET /index" do
    let!(:global_pack) { create(:prompt_pack, user: nil, name: "System Pack") }

    it "returns http success", :aggregate_failures do
      get prompt_packs_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Library")
      expect(response.body).to include(global_pack.name)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get new_prompt_pack_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /create" do
    let(:valid_attributes) do
      {
        name: "New Pack",
        game_type: "Write And Vote",
        prompts_attributes: [
          { body: "Prompt 1" },
          { body: "Prompt 2" }
        ]
      }
    end

    it "creates a new PromptPack with prompts" do
      expect {
        post prompt_packs_path, params: { prompt_pack: valid_attributes }
      }.to change(PromptPack, :count).by(1).and change(Prompt, :count).by(2)

      expect(response).to redirect_to(prompt_packs_path)
    end
  end

  describe "GET /edit" do
    let(:prompt_pack) { create(:prompt_pack, user:) }

    it "returns http success" do
      get edit_prompt_pack_path(prompt_pack)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /update" do
    let(:prompt_pack) { create(:prompt_pack, user:) }

    it "updates the prompt pack" do
      patch prompt_pack_path(prompt_pack), params: { prompt_pack: { name: "Updated Name" } }
      expect(prompt_pack.reload.name).to eq("Updated Name")
      expect(response).to redirect_to(prompt_packs_path)
    end

    it "adds nested prompts" do
      patch prompt_pack_path(prompt_pack), params: { prompt_pack: { prompts_attributes: [ { body: "New Prompt" } ] } }
      expect(prompt_pack.prompts.count).to eq(1)
    end
  end

  describe "DELETE /destroy" do
    let!(:prompt_pack) { create(:prompt_pack, user:) }

    it "destroys the prompt pack" do
      expect {
        delete prompt_pack_path(prompt_pack)
      }.to change(PromptPack, :count).by(-1)

      expect(response).to redirect_to(prompt_packs_path)
    end
  end
end
