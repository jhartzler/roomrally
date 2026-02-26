FactoryBot.define do
  factory :ai_generation_request do
    association :user
    pack_type { "prompt_pack" }
    pack_id { 1 }
    user_theme { "90s movies" }
    status { :pending }
    counts_against_limit { true }
    parsed_items { nil }
  end
end
