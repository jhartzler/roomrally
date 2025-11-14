# app/services/game_event_router.rb
module GameEventRouter
  @game_handlers = {}

  def self.register_game(game_type, handler)
    @game_handlers[game_type] = handler
    Rails.logger.info "Registered game handler for #{game_type}"
  end

  def self.publish(event_name, room, *args)
    handler = @game_handlers[room.game_type]
    if handler && handler.respond_to?(event_name)
      handler.public_send(event_name, room, *args)
    else
      Rails.logger.warn "No handler for event :#{event_name} in game type #{room.game_type}"
    end
  end
end
