require "rails_helper"

RSpec.describe "Shortcodes", type: :request do
  describe "GET /:code" do
    let!(:room) { FactoryBot.create(:room) }

    it "redirects to the stage view" do
      get "/#{room.code}"
      expect(response).to redirect_to(room_stage_path(room))
    end

    it "handles lowercase codes" do
      get "/#{room.code.downcase}"
      expect(response).to redirect_to(room_stage_path(room))
    end

    it "returns 404 for nonexistent room codes" do
      get "/ZZZZ"
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("not found")
    end
  end
end
