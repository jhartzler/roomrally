require 'rails_helper'

RSpec.describe "PromptPacks", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe "GET /index" do
    it "returns http success", :aggregate_failures do
      get "/prompt_packs"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Library")
      expect(response.body).to include("Template Gallery")
      expect(response.body).to include("My Packs")
    end

    it "displays user's prompt packs", :aggregate_failures do
      create(:prompt_pack, user:, name: "My Awesome Pack")
      get "/prompt_packs"
      expect(response.body).to include("My Awesome Pack")
      expect(response.body).to include("Supports 0 Players")
    end
  end
end
