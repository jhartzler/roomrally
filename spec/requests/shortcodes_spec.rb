require "rails_helper"

# PARKED: the app is paused, so old 4-letter short URLs now land on the parked page.
RSpec.describe "Shortcodes", type: :request do
  describe "GET /:code" do
    let!(:room) { FactoryBot.create(:room) }

    it "redirects to the parked page" do
      get "/#{room.code}"
      expect(response).to redirect_to("/parked.html")
    end

    it "handles lowercase codes" do
      get "/#{room.code.downcase}"
      expect(response).to redirect_to("/parked.html")
    end

    it "redirects to the parked page for nonexistent room codes" do
      get "/ZZZZ"
      expect(response).to redirect_to("/parked.html")
    end
  end
end
