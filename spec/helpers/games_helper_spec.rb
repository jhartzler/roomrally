require "rails_helper"

RSpec.describe GamesHelper do
  describe "#game_theme_name" do
    it "returns comedy-club for WriteAndVoteGame" do
      game = build(:write_and_vote_game)
      expect(helper.game_theme_name(game)).to eq("comedy-club")
    end

    it "returns track-meet for SpeedTriviaGame" do
      game = build(:speed_trivia_game)
      expect(helper.game_theme_name(game)).to eq("track-meet")
    end

    it "returns awards-gala for CategoryListGame" do
      game = build(:category_list_game)
      expect(helper.game_theme_name(game)).to eq("awards-gala")
    end

    it "returns nil when game is nil" do
      expect(helper.game_theme_name(nil)).to be_nil
    end
  end
end
