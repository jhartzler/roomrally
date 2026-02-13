FactoryBot.define do
  factory :trivia_question do
    trivia_pack
    body { "What is the capital of France?" }
    correct_answers { [ "Paris" ] }
    options { [ "Paris", "London", "Berlin", "Madrid" ] }
  end
end
