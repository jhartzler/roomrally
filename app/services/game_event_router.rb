# app/services/game_event_router.rb
module GameEventRouter
  @game_handlers = {}

  def self.register_game(game_type, handler)
    @game_handlers[game_type] = handler
    Rails.logger.info "Registered game handler for #{game_type}"
  end

  def self.handler_for(game_type)
    @game_handlers[game_type]
  end

  def self.method_missing(event_name, *args, **kwargs)
    # Extract room from arguments (either positional first arg or keyword :room)
    if kwargs.key?(:room)
      room = kwargs[:room]
    else
      room = args.first
    end

    return super unless room.is_a?(Room)

    handler = @game_handlers[room.game_type]
    if handler && handler.respond_to?(event_name)
      if kwargs.any?
        # If we received kwargs, pass them through directly.
        # This assumes the publisher is using the new kwarg interface.
        handler.public_send(event_name, *args, **kwargs)
      else
        # Legacy positional args path.
        # Check if the handler expects kwargs (specifically :room) and upgrade the call if needed.
        handler_method = handler.method(event_name)
        params = handler_method.parameters

        if params.any? { |type, name| type == :keyreq && name == :room }
          handler.public_send(event_name, *args.drop(1), room:)
        else
          handler.public_send(event_name, *args)
        end
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
