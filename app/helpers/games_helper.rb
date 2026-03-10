module GamesHelper
  GAME_THEMES = {
    Room::WRITE_AND_VOTE => "comedy-club",
    Room::SPEED_TRIVIA => "track-meet",
    Room::CATEGORY_LIST => "awards-gala"
  }.freeze

  def game_theme_name(room)
    return nil unless room&.game_type

    GAME_THEMES[room.game_type]
  end
end
