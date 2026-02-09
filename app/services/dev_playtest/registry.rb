module DevPlaytest
  module Registry
    @handlers = {}
    @game_type_names = {}

    def self.register(game_class, handler)
      @handlers[game_class.name] = handler
      # Derive display name from class: "WriteAndVoteGame" → "Write And Vote"
      @game_type_names[game_class.name] = game_class.name.delete_suffix("Game").gsub(/([a-z])([A-Z])/, '\1 \2')
    end

    def self.handler_for(game)
      @handlers[game.class.name]
    end

    def self.handler_for_class_name(class_name)
      @handlers[class_name]
    end

    def self.game_types
      @game_type_names.values
    end

    def self.lobby_actions
      [ { label: "Start Game", action: :start, style: :primary } ]
    end
  end
end
