# app/services/game_event_router.rb
module GameEventRouter
  @game_handlers = {}

  def self.register_game(game_type, handler)
    @game_handlers[game_type] = handler
    Rails.logger.info "Registered game handler for #{game_type}"
  end

  def self.method_missing(event_name, *args)
    room = args.first
    return super unless room.is_a?(Room)

    handler = @game_handlers[room.game_type]
    if handler && handler.respond_to?(event_name)
      handler.public_send(event_name, *args)
    else
      # Do nothing, just ignore the event
    end
  end

  def self.respond_to_missing?(method_name, include_private = false)
    # This is needed for method_missing to work correctly with wisper
    true
  end
end
