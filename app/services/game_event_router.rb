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
      handler_method = handler.method(event_name)
      params = handler_method.parameters

      # If the handler method explicitly requires a 'room' keyword argument,
      # we assume it wants the clean kwarg interface.
      if params.any? { |type, name| type == :keyreq && name == :room }
        handler.public_send(event_name, *args.drop(1), room:)
      else
        handler.public_send(event_name, *args)
      end
    else
      # Do nothing, just ignore the event
    end
  end

  def self.respond_to_missing?(method_name, include_private = false)
    # This is needed for method_missing to work correctly with wisper
    true
  end
end
