# config/initializers/game_registry.rb
Rails.application.config.to_prepare do
  GameEventRouter.register_game("Write And Vote", Games::WriteAndVote)
  GameEventRouter.register_game("Speed Trivia", Games::SpeedTrivia)
end
