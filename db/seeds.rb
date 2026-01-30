# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create starter master prompts
# Create starter master prompts
# Global "Standard Deck"
standard_pack = PromptPack.find_or_create_by!(
  name: "Standard Deck",
  game_type: "Write And Vote",
  user_id: nil,
  is_default: true,
  status: :live
)

standard_prompts = YAML.load_file(Rails.root.join("config/standard_prompts.yml"))

standard_prompts.each do |prompt_text|
  Prompt.find_or_create_by!(body: prompt_text, prompt_pack: standard_pack)
end

# Speed Trivia: "Standard Trivia" pack
trivia_pack = TriviaPack.find_or_create_by!(
  name: "Standard Trivia",
  game_type: "Speed Trivia",
  user_id: nil,
  is_default: true,
  status: :live
)

standard_trivia = YAML.load_file(Rails.root.join("config/standard_trivia.yml"))

standard_trivia.each do |question_data|
  TriviaQuestion.find_or_create_by!(
    body: question_data["body"],
    trivia_pack: trivia_pack
  ) do |q|
    q.correct_answer = question_data["correct_answer"]
    q.options = question_data["options"]
  end
end
