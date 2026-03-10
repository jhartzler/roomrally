require "rails_helper"

RSpec.describe GamesHelper do
  describe "#game_theme_name" do
    it "returns comedy-club for Write And Vote rooms" do
      room = build(:room, game_type: Room::WRITE_AND_VOTE)
      expect(helper.game_theme_name(room)).to eq("comedy-club")
    end

    it "returns track-meet for Speed Trivia rooms" do
      room = build(:room, game_type: Room::SPEED_TRIVIA)
      expect(helper.game_theme_name(room)).to eq("track-meet")
    end

    it "returns awards-gala for Category List rooms" do
      room = build(:room, game_type: Room::CATEGORY_LIST)
      expect(helper.game_theme_name(room)).to eq("awards-gala")
    end

    it "returns nil when room is nil" do
      expect(helper.game_theme_name(nil)).to be_nil
    end
  end
end
