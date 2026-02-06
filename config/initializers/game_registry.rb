# config/initializers/game_registry.rb
Rails.application.config.to_prepare do
  GameEventRouter.register_game("Write And Vote", Games::WriteAndVote)
  GameEventRouter.register_game("Speed Trivia", Games::SpeedTrivia)
  GameEventRouter.register_game("Category List", Games::CategoryList)

  DevPlaytest::Registry.register(WriteAndVoteGame, DevPlaytest::WriteAndVote)
  DevPlaytest::Registry.register(SpeedTriviaGame, DevPlaytest::SpeedTrivia)
end
