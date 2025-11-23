FactoryBot.define do
  factory :prompt_instance do
    room
    prompt
    body { prompt.body }
  end
end
