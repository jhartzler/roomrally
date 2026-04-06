# config/initializers/game_registry.rb
Rails.application.config.to_prepare do
  GameEventRouter.register_game("Write And Vote", Games::WriteAndVote)
  GameEventRouter.register_game("Speed Trivia", Games::SpeedTrivia)
  GameEventRouter.register_game("Category List", Games::CategoryList)
  GameEventRouter.register_game("Poll Game", Games::Poll)

  DevPlaytest::Registry.register(WriteAndVoteGame, Games::WriteAndVote::Playtest)
  DevPlaytest::Registry.register(SpeedTriviaGame, Games::SpeedTrivia::Playtest)
  DevPlaytest::Registry.register(CategoryListGame, Games::CategoryList::Playtest)
  DevPlaytest::Registry.register(PollGame, Games::Poll::Playtest)
end
