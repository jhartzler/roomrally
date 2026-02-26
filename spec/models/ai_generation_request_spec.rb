require "rails_helper"

RSpec.describe AiGenerationRequest, type: :model do
  let(:user) { create(:user) }
  let(:pack) { create(:prompt_pack, user: user) }

  describe "validations" do
    it "is valid with required attributes" do
      request = build(:ai_generation_request, user: user, pack_type: "prompt_pack", pack_id: pack.id, user_theme: "90s movies")
      expect(request).to be_valid
    end

    it "requires user" do
      request = build(:ai_generation_request, user: nil)
      expect(request).not_to be_valid
    end

    it "requires pack_type" do
      request = build(:ai_generation_request, pack_type: nil)
      expect(request).not_to be_valid
    end

    it "requires user_theme" do
      request = build(:ai_generation_request, user_theme: nil)
      expect(request).not_to be_valid
    end
  end

  describe "#target_pack" do
    it "returns the prompt pack for pack_type prompt_pack" do
      request = create(:ai_generation_request, user: user, pack_type: "prompt_pack", pack_id: pack.id)
      expect(request.target_pack).to eq(pack)
    end

    it "raises ActiveRecord::RecordNotFound for a pack not owned by the user" do
      other_pack = create(:prompt_pack)
      request = create(:ai_generation_request, user: user, pack_type: "prompt_pack", pack_id: other_pack.id)
      expect { request.target_pack }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#items_for_indices" do
    let(:items) { [ { "body" => "A" }, { "body" => "B" }, { "body" => "C" } ] }
    let(:request) { create(:ai_generation_request, user: user, parsed_items: items) }

    it "returns all items when indices is blank" do
      expect(request.items_for_indices(nil)).to eq(items)
    end

    it "returns only selected items by index" do
      expect(request.items_for_indices([ "0", "2" ])).to eq([ { "body" => "A" }, { "body" => "C" } ])
    end
  end
end
