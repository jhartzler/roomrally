FactoryBot.define do
  factory :score_tracker_entry do
    sequence(:name) { |n| "Team #{n}" }
    score { 0 }
    room
  end
end
