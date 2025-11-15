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
[
  "What's the best way to annoy a cat?",
  "Describe your ideal superpower and its biggest drawback.",
  "What's something everyone thinks is normal, but is actually really weird?",
  "Invent a new Olympic sport.",
  "What's the most ridiculous thing you've ever seen someone do for attention?",
  "If animals could talk, which would be the rudest?",
  "What's a common phrase that makes no sense if you think about it too hard?",
  "Describe your perfect sandwich.",
  "What's the weirdest thing you've ever eaten?",
  "If you could have any fictional character as your best friend, who would it be and why?"
].each do |prompt_text|
  Prompt.find_or_create_by!(body: prompt_text)
end
