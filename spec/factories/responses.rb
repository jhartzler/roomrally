FactoryBot.define do
  factory :response do
    player
    prompt_instance
    content { "MyText" }
  end
end
