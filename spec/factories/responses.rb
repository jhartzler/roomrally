FactoryBot.define do
  factory :response do
    player
    prompt_instance
    body { "MyText" }
  end
end
