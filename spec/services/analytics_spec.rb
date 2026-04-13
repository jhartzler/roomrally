require "rails_helper"

RSpec.describe Analytics do
  describe ".referrer_domain" do
    it "returns the host from a valid referer URL" do
      request = instance_double(ActionDispatch::Request, referer: "https://www.google.com/search?q=room+rally")
      expect(described_class.referrer_domain(request)).to eq("www.google.com")
    end

    it "returns nil when referer is blank" do
      request = instance_double(ActionDispatch::Request, referer: nil)
      expect(described_class.referrer_domain(request)).to be_nil
    end

    it "returns nil for an invalid URI" do
      request = instance_double(ActionDispatch::Request, referer: "not a url %%")
      expect(described_class.referrer_domain(request)).to be_nil
    end
  end

  describe ".room_distinct_id" do
    it "uses the user id when the room belongs to a user" do
      room = build(:room, code: "ABCD", user_id: 12)

      expect(described_class.room_distinct_id(room)).to eq("user_12")
    end

    it "falls back to the room code for anonymous rooms" do
      room = build(:room, code: "ABCD", user_id: nil)

      expect(described_class.room_distinct_id(room)).to eq("room_ABCD")
    end
  end

  describe ".room_properties" do
    subject(:room_properties) { described_class.room_properties(room, player_count: 4) }

    let(:room) { build(:room, code: "ABCD", game_type: Room::SPEED_TRIVIA) }

    it "returns the shared room analytics properties merged with extra values" do
      expect(room_properties).to eq(
        game_type: Room::SPEED_TRIVIA,
        room_code: "ABCD",
        player_count: 4
      )
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
