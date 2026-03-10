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
    trivia_pack:
  ) do |q|
    q.correct_answers = question_data["correct_answers"]
    q.options = question_data["options"]
  end
end

# Category List: "Standard Categories" pack
category_pack = CategoryPack.find_or_create_by!(
  name: "Standard Categories",
  game_type: "Category List",
  user_id: nil,
  is_default: true,
  status: :live
)

standard_categories = YAML.load_file(Rails.root.join("config/standard_categories.yml"))

standard_categories.each do |category_name|
  Category.find_or_create_by!(name: category_name, category_pack:)
end

# Scavenger Hunt: "Classic Scavenger Hunt" pack
hunt_pack = HuntPack.find_or_create_by!(
  name: "Classic Scavenger Hunt",
  game_type: "Scavenger Hunt",
  user_id: nil,
  is_default: true,
  status: :live
)

hunt_prompts = [
  { body: "Take a team photo reenacting a famous painting", weight: 5 },
  { body: "Everyone in an elevator — make it dramatic", weight: 5 },
  { body: "Find a local landmark and pose like tourists", weight: 5 },
  { body: "Take a photo with a stranger (ask nicely!)", weight: 10 },
  { body: "Recreate a movie poster with your team", weight: 10 },
  { body: "Find something that starts with every letter of your team name", weight: 5 },
  { body: "Capture your best 'album cover' photo", weight: 5 },
  { body: "Team doing their best impression of a statue", weight: 5 },
  { body: "The most creative use of a common object", weight: 5 },
  { body: "Take a photo that tells a story in one frame", weight: 10 }
]

hunt_prompts.each_with_index do |prompt, index|
  hunt_pack.hunt_prompts.find_or_create_by!(body: prompt[:body]) do |p|
    p.weight = prompt[:weight]
    p.position = index
  end
end
