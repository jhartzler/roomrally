FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    category_pack
  end
end
