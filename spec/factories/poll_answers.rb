FactoryBot.define do
  factory :poll_answer do
    player
    poll_game
    poll_question
    selected_option { "dog" }
    points_awarded { 0 }
    submitted_at { Time.current }
  end
end
