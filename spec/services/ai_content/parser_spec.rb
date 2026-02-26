require "rails_helper"

RSpec.describe AiContent::Parser do
  describe ".parse" do
    context "for prompt_pack" do
      let(:valid_json) do
        items = 10.times.map { |i| { "body" => "Prompt #{i}" } }
        { "items" => items }.to_json
      end

      it "returns the items array for valid JSON" do
        result = AiContent::Parser.parse(valid_json, "prompt_pack")
        expect(result).to be_an(Array)
        expect(result.length).to eq(10)
        expect(result.first).to eq({ "body" => "Prompt 0" })
      end

      it "returns nil when JSON is invalid" do
        expect(AiContent::Parser.parse("not json", "prompt_pack")).to be_nil
      end

      it "returns nil when items count is not 10" do
        json = { "items" => [ { "body" => "Only one" } ] }.to_json
        expect(AiContent::Parser.parse(json, "prompt_pack")).to be_nil
      end

      it "returns nil when any item is missing body" do
        items = 10.times.map { |i| i == 5 ? { "other" => "field" } : { "body" => "Prompt #{i}" } }
        expect(AiContent::Parser.parse({ "items" => items }.to_json, "prompt_pack")).to be_nil
      end
    end

    context "for trivia_pack" do
      let(:valid_item) do
        { "body" => "Question?", "options" => %w[A B C D], "correct_answers" => ["A"] }
      end
      let(:valid_json) { { "items" => Array.new(10, valid_item) }.to_json }

      it "returns items for valid trivia JSON" do
        result = AiContent::Parser.parse(valid_json, "trivia_pack")
        expect(result).to be_an(Array)
        expect(result.length).to eq(10)
      end

      it "returns nil when options count is not 4" do
        bad_item = valid_item.merge("options" => %w[A B C])
        json = { "items" => Array.new(10, bad_item) }.to_json
        expect(AiContent::Parser.parse(json, "trivia_pack")).to be_nil
      end

      it "returns nil when correct_answers is empty" do
        bad_item = valid_item.merge("correct_answers" => [])
        json = { "items" => Array.new(10, bad_item) }.to_json
        expect(AiContent::Parser.parse(json, "trivia_pack")).to be_nil
      end

      it "returns nil when correct_answers contains a value not in options" do
        bad_item = valid_item.merge("correct_answers" => ["Z"])
        json = { "items" => Array.new(10, bad_item) }.to_json
        expect(AiContent::Parser.parse(json, "trivia_pack")).to be_nil
      end
    end

    context "for category_pack" do
      let(:valid_json) do
        items = 10.times.map { |i| { "name" => "Category #{i}" } }
        { "items" => items }.to_json
      end

      it "returns items for valid category JSON" do
        result = AiContent::Parser.parse(valid_json, "category_pack")
        expect(result).to be_an(Array)
        expect(result.length).to eq(10)
      end

      it "returns nil when any item is missing name" do
        items = 10.times.map { |i| i == 0 ? { "other" => "x" } : { "name" => "Cat #{i}" } }
        expect(AiContent::Parser.parse({ "items" => items }.to_json, "category_pack")).to be_nil
      end
    end
  end
end
