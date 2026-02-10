FactoryBot.define do
  factory :category_instance do
    sequence(:name) { |n| "Category #{n}" }
    sequence(:position) { |n| n }
    round { 1 }
    category_list_game
    category
  end
end
