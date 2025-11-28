require 'rails_helper'

RSpec.describe Vote, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:player) }
    it { is_expected.to belong_to(:response) }
  end

  describe "validations" do
    let(:prompt_instance) { create(:prompt_instance) }
    let(:voter) { create(:player) }
    let(:author) { create(:player) }
    let(:author_response) { create(:response, prompt_instance:, player: author) }

    it "is valid when voting for another player's response" do
      vote = described_class.new(player: voter, response: author_response)
      expect(vote).to be_valid
    end

    it "is invalid when voting for own response" do
      vote = described_class.new(player: author, response: author_response)
      expect(vote).not_to be_valid
      expect(vote.errors[:base]).to include("You cannot vote for your own response")
    end

    it "is invalid when voting twice for the same prompt instance" do
      other_response = create(:response, prompt_instance:)
      create(:vote, player: voter, response: other_response)

      vote = described_class.new(player: voter, response: author_response)
      expect(vote).not_to be_valid
      expect(vote.errors[:base]).to include("You have already voted for this prompt")
    end
  end
end
