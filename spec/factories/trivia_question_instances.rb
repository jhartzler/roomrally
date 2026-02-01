FactoryBot.define do
  factory :trivia_question_instance do
    speed_trivia_game
    trivia_question
    body { "What is the capital of France?" }
    correct_answer { "Paris" }
    options { [ "Paris", "London", "Berlin", "Madrid" ] }
    sequence(:position) { |n| n }
  end
end
