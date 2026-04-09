require "rails_helper"

RSpec.describe Analytics do
  describe ".referrer_domain" do
    it "returns the host from a valid referer URL" do
      request = double("request", referer: "https://www.google.com/search?q=room+rally")
      expect(described_class.referrer_domain(request)).to eq("www.google.com")
    end

    it "returns nil when referer is blank" do
      request = double("request", referer: nil)
      expect(described_class.referrer_domain(request)).to be_nil
    end

    it "returns nil for an invalid URI" do
      request = double("request", referer: "not a url %%")
      expect(described_class.referrer_domain(request)).to be_nil
    end
  end

  describe ".pack_properties" do
    context "when the room has no pack" do
      it "returns nil pack_id and pack_name" do
        room = build(:room, game_type: Room::WRITE_AND_VOTE, prompt_pack: nil)
        result = described_class.pack_properties(room)
        expect(result).to eq({ pack_id: nil, pack_name: nil })
      end
    end

    context "when the room has a prompt_pack (Write And Vote)" do
      it "returns the pack id and name" do
        pack = build(:prompt_pack, id: 42, name: "Office Gossip")
        room = build(:room, game_type: Room::WRITE_AND_VOTE, prompt_pack: pack)
        result = described_class.pack_properties(room)
        expect(result).to eq({ pack_id: 42, pack_name: "Office Gossip" })
      end
    end

    context "when the room has a trivia_pack (Speed Trivia)" do
      it "returns the pack id and name" do
        pack = build(:trivia_pack, id: 7, name: "Science Blitz")
        room = build(:room, game_type: Room::SPEED_TRIVIA, trivia_pack: pack)
        result = described_class.pack_properties(room)
        expect(result).to eq({ pack_id: 7, pack_name: "Science Blitz" })
      end
    end

    context "when the room has a category_pack (Category List)" do
      it "returns the pack id and name" do
        pack = build(:category_pack, id: 99, name: "Holiday Fun")
        room = build(:room, game_type: Room::CATEGORY_LIST, category_pack: pack)
        result = described_class.pack_properties(room)
        expect(result).to eq({ pack_id: 99, pack_name: "Holiday Fun" })
      end
    end
  end
end
