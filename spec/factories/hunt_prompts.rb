FactoryBot.define do
  factory :hunt_prompt do
    hunt_pack
    body { "Take a photo reenacting a famous painting" }
    weight { 5 }
    sequence(:position) { |n| n }
  end
end
