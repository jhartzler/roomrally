require "rails_helper"

RSpec.describe AiContent::Prompts do
  describe ".for" do
    it "returns a non-empty string for prompt_pack" do # rubocop:disable RSpec/MultipleExpectations
      prompt = described_class.for("prompt_pack")
      expect(prompt).to be_a(String)
      expect(prompt).to include("user_theme")
      expect(prompt).to include("13")
    end

    it "returns a non-empty string for trivia_pack" do
      prompt = described_class.for("trivia_pack")
      expect(prompt).to be_a(String)
      expect(prompt).to include("correct_answers")
    end

    it "returns a non-empty string for category_pack" do
      prompt = described_class.for("category_pack")
      expect(prompt).to be_a(String)
      expect(prompt).to include("category")
    end

    it "raises ArgumentError for unknown pack type" do
      expect { described_class.for("unknown") }.to raise_error(ArgumentError)
    end
  end
end
