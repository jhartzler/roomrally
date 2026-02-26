require "rails_helper"

RSpec.describe GameTemplate, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:prompt_pack).optional }
    it { is_expected.to belong_to(:trivia_pack).optional }
    it { is_expected.to belong_to(:category_pack).optional }
    it { is_expected.to have_many(:rooms).dependent(:nullify) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:game_type) }

    it "validates game_type inclusion" do
      template = build(:game_template, game_type: "Invalid Game")
      expect(template).not_to be_valid
      expect(template.errors[:game_type]).to be_present
    end

    it "accepts valid game types" do
      Room::GAME_TYPES.each do |type|
        template = build(:game_template, game_type: type)
        expect(template).to be_valid
      end
    end

    it "validates name length" do
      template = build(:game_template, name: "a" * 101)
      expect(template).not_to be_valid
      expect(template.errors[:name]).to be_present
    end
  end

  describe "pack-type mismatch validation" do
    let(:user) { create(:user) }
    let(:prompt_pack) { create(:prompt_pack, user:) }
    let(:trivia_pack) { create(:trivia_pack, user:) }
    let(:category_pack) { create(:category_pack, user:) }

    it "allows prompt_pack for Write And Vote" do
      template = build(:game_template, user:, game_type: "Write And Vote", prompt_pack:)
      expect(template).to be_valid
    end

    it "rejects prompt_pack for Speed Trivia" do
      template = build(:game_template, user:, game_type: "Speed Trivia", prompt_pack:)
      expect(template).not_to be_valid
      expect(template.errors[:prompt_pack]).to include("doesn't match game type")
    end

    it "allows trivia_pack for Speed Trivia" do
      template = build(:game_template, user:, game_type: "Speed Trivia", trivia_pack:)
      expect(template).to be_valid
    end

    it "rejects trivia_pack for Write And Vote" do
      template = build(:game_template, user:, game_type: "Write And Vote", trivia_pack:)
      expect(template).not_to be_valid
      expect(template.errors[:trivia_pack]).to include("doesn't match game type")
    end

    it "allows category_pack for Category List" do
      template = build(:game_template, user:, game_type: "Category List", category_pack:)
      expect(template).to be_valid
    end

    it "rejects category_pack for Write And Vote" do
      template = build(:game_template, user:, game_type: "Write And Vote", category_pack:)
      expect(template).not_to be_valid
      expect(template.errors[:category_pack]).to include("doesn't match game type")
    end
  end

  describe "pack ownership validation" do
    let(:owner) { create(:user) }
    let(:other_user) { create(:user) }

    it "allows system packs (user_id nil)" do
      system_pack = create(:prompt_pack, user: nil)
      template = build(:game_template, user: owner, game_type: "Write And Vote", prompt_pack: system_pack)
      expect(template).to be_valid
    end

    it "allows own packs" do
      own_pack = create(:prompt_pack, user: owner)
      template = build(:game_template, user: owner, game_type: "Write And Vote", prompt_pack: own_pack)
      expect(template).to be_valid
    end

    it "rejects another user's private pack" do
      other_pack = create(:prompt_pack, user: other_user)
      template = build(:game_template, user: owner, game_type: "Write And Vote", prompt_pack: other_pack)
      expect(template).not_to be_valid
      expect(template.errors[:base]).to include("You don't have access to the selected pack")
    end
  end

  describe "#merged_settings" do
    it "preserves overridden values" do
      template = build(:game_template, settings: { "timer_enabled" => true })
      expect(template.merged_settings["timer_enabled"]).to be true
    end

    it "fills missing keys with defaults" do
      template = build(:game_template, settings: { "timer_enabled" => true })
      expect(template.merged_settings["timer_increment"]).to eq(90)
    end

    it "handles nil settings" do
      template = build(:game_template, settings: nil)
      expect(template.merged_settings).to eq(GameTemplate::SETTING_DEFAULTS)
    end
  end

  describe "settings range validation" do
    it "rejects timer_increment below 10" do
      template = build(:game_template, settings: { "timer_increment" => 5 })
      expect(template).not_to be_valid
      expect(template.errors[:settings]).to be_present
    end

    it "rejects timer_increment above 300" do
      template = build(:game_template, settings: { "timer_increment" => 301 })
      expect(template).not_to be_valid
      expect(template.errors[:settings]).to be_present
    end

    it "accepts timer_increment within range" do
      template = build(:game_template, settings: { "timer_increment" => 60 })
      expect(template).to be_valid
    end

    it "rejects question_count of zero" do
      template = build(:game_template, settings: { "question_count" => 0 })
      expect(template).not_to be_valid
      expect(template.errors[:settings]).to be_present
    end

    it "rejects question_count above 50" do
      template = build(:game_template, settings: { "question_count" => 51 })
      expect(template).not_to be_valid
      expect(template.errors[:settings]).to be_present
    end

    it "rejects total_rounds of zero" do
      template = build(:game_template, settings: { "total_rounds" => 0 })
      expect(template).not_to be_valid
      expect(template.errors[:settings]).to be_present
    end

    it "rejects total_rounds above 10" do
      template = build(:game_template, settings: { "total_rounds" => 11 })
      expect(template).not_to be_valid
      expect(template.errors[:settings]).to be_present
    end

    it "rejects categories_per_round of zero" do
      template = build(:game_template, settings: { "categories_per_round" => 0 })
      expect(template).not_to be_valid
      expect(template.errors[:settings]).to be_present
    end

    it "rejects categories_per_round above 12" do
      template = build(:game_template, settings: { "categories_per_round" => 13 })
      expect(template).not_to be_valid
      expect(template.errors[:settings]).to be_present
    end

    it "ignores unknown keys" do
      template = build(:game_template, settings: { "unknown_key" => 999 })
      expect(template).to be_valid
    end
  end

  describe "settings type casting" do
    it "casts string booleans to actual booleans" do
      template = create(:game_template, settings: { "timer_enabled" => "true", "stage_only" => "false" })
      expect(template.settings["timer_enabled"]).to be true
      expect(template.settings["stage_only"]).to be false
    end

    it "casts string integers to actual integers" do
      template = create(:game_template, settings: { "timer_increment" => "90", "total_rounds" => "5" })
      expect(template.settings["timer_increment"]).to eq(90)
      expect(template.settings["total_rounds"]).to eq(5)
    end
  end

  describe "#pack" do
    let(:user) { create(:user) }

    it "returns prompt_pack for Write And Vote" do
      pack = create(:prompt_pack, user:)
      template = build(:game_template, user:, game_type: "Write And Vote", prompt_pack: pack)
      expect(template.pack).to eq(pack)
    end

    it "returns trivia_pack for Speed Trivia" do
      pack = create(:trivia_pack, user:)
      template = build(:game_template, user:, game_type: "Speed Trivia", trivia_pack: pack)
      expect(template.pack).to eq(pack)
    end

    it "returns category_pack for Category List" do
      pack = create(:category_pack, user:)
      template = build(:game_template, user:, game_type: "Category List", category_pack: pack)
      expect(template.pack).to eq(pack)
    end
  end

  describe "#build_room" do
    let(:user) { create(:user) }
    let(:prompt_pack) { create(:prompt_pack, user:) }

    let(:template) do
      create(:game_template, user:, name: "Friday Fun",
        game_type: "Write And Vote", prompt_pack:, settings: { "stage_only" => true })
    end
    let(:room) { template.build_room }

    it "sets the game_type from template" do
      expect(room.game_type).to eq("Write And Vote")
    end

    it "sets the user from template" do
      expect(room.user).to eq(user)
    end

    it "links back to the template" do
      expect(room.game_template).to eq(template)
    end

    it "uses template name as display_name" do
      expect(room.display_name).to eq("Friday Fun")
    end

    it "passes the prompt_pack" do
      expect(room.prompt_pack).to eq(prompt_pack)
    end

    it "applies stage_only from settings" do
      expect(room.stage_only).to be true
    end

    it "defaults stage_only to false" do
      template = create(:game_template, user:, settings: {})
      room = template.build_room
      expect(room.stage_only).to be false
    end

    it "builds a saveable room" do
      template = create(:game_template, user:)
      room = template.build_room
      expect(room.save).to be true
      expect(room.code).to be_present
    end
  end
end
