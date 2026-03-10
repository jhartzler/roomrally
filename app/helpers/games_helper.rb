module GamesHelper
  GAME_THEMES = {
    "WriteAndVoteGame" => "comedy-club",
    "SpeedTriviaGame" => "track-meet",
    "CategoryListGame" => "awards-gala"
  }.freeze

  def game_theme_name(game)
    return nil unless game

    GAME_THEMES[game.class.name]
  end
end
