FactoryBot.define do
  factory :category_list_game do
    status { "instructions" }
    current_letter { "A" }
    current_round { 1 }
    total_rounds { 3 }
    categories_per_round { 6 }
    timer_enabled { false }
    timer_increment { 90 }
    show_instructions { true }
  end
end
