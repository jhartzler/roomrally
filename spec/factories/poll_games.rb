FactoryBot.define do
  factory :poll_game do
    status { "instructions" }
    scoring_mode { "majority" }
    current_question_index { 0 }
    question_count { 5 }
    time_limit { 20 }
    timer_enabled { false }

    association :poll_pack
  end
end
