FactoryBot.define do
  factory :trivia_answer do
    player
    trivia_question_instance
    selected_option { "Paris" }
    correct { true }
    points_awarded { 0 }
    submitted_at { Time.current }
  end
end
