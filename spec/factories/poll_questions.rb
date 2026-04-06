FactoryBot.define do
  factory :poll_question do
    poll_pack
    body { "Would you rather have a dog or a cat?" }
    options { [ "dog", "cat", "neither", "both" ] }
    position { 0 }
  end
end
