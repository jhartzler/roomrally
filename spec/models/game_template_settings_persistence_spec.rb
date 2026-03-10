require "rails_helper"

RSpec.describe "GameTemplate settings persistence through controller params", type: :model do
  let(:user) { create(:user) }
  let(:template) { create(:game_template, user:, game_type: "Speed Trivia") }

  let(:permitted_params) do
    params = ActionController::Parameters.new(
      game_template: {
        name: "Trivia Night", game_type: "Speed Trivia",
        settings: { "question_count" => "9", "timer_enabled" => "false",
                    "show_instructions" => "true", "timer_increment" => "90", "stage_only" => "false" }
      }
    )
    params.require(:game_template).permit(
      :name, :game_type, :prompt_pack_id, :trivia_pack_id, :category_pack_id,
      settings: GameTemplate::SETTING_DEFAULTS.keys
    )
  end

  it "persists question_count through nested settings params" do
    template.update!(permitted_params)
    template.reload
    expect(template.settings["question_count"]).to eq(9)
  end

  it "round-trips question_count through merged_settings" do
    template.update!(settings: { "question_count" => 9 })
    expect(template.merged_settings["question_count"]).to eq(9)
  end
end
