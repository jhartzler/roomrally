FactoryBot.define do
  factory :prompt_instance do
    write_and_vote_game
    prompt
    body { prompt.body }
  end
end
