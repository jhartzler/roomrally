FactoryBot.define do
  factory :category_answer do
    body { "Answer" }
    player
    category_instance
    status { "pending" }
    alliterative { false }
    duplicate { false }
    points_awarded { 0 }
  end
end
