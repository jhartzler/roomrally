# config/initializers/wisper_subscriptions.rb

# This is where we subscribe our global listeners to publishers.
# The GameEventRouter is the central hub for all game-related events.
Rails.application.config.to_prepare do
  RoomsController.subscribe(GameEventRouter)
  GamesController.subscribe(GameEventRouter)
end
