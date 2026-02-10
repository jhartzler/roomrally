require "rails_helper"

RSpec.describe CategoryPack, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to have_many(:categories).dependent(:destroy) }
  end

  describe ".default" do
    it "returns the pack with is_default true" do
      pack = create(:category_pack, :default)
      expect(described_class.default).to eq(pack)
    end

    it "falls back to first global pack if no default" do
      pack = create(:category_pack, :global)
      expect(described_class.default).to eq(pack)
    end
  end

  describe "scopes" do
    let(:user) { create(:user) }

    it ".global returns packs without a user" do
      global = create(:category_pack, :global)
      create(:category_pack, user:)
      expect(described_class.global).to eq([ global ])
    end

    it ".accessible_by returns user's packs and global packs" do
      global = create(:category_pack, :global)
      owned = create(:category_pack, user:)
      create(:category_pack, user: create(:user))
      expect(described_class.accessible_by(user)).to contain_exactly(global, owned)
    end
  end

  describe "default name" do
    it "sets a default name if blank" do
      pack = described_class.new(name: "")
      pack.valid?
      expect(pack.name).to eq("Untitled Category Pack")
    end
  end
end
