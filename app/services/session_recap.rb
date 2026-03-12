class SessionRecap
  Event = Struct.new(:timestamp, :event_type, :description, :metadata, keyword_init: true)

  def self.for(room)
    new(room).build
  end

  def initialize(room)
    @room = room
    @game = room.current_game
  end

  def build
    events = []
    events << room_created_event
    events.concat(player_events)
    events.concat(game_event_records)
    events.concat(answer_events)
    events.concat(vote_events)
    events.sort_by(&:timestamp)
  end

  private

  def room_created_event
    Event.new(
      timestamp: @room.created_at,
      event_type: "room_created",
      description: "Room created#{@room.user ? " by #{@room.user.email}" : ""}",
      metadata: { room_code: @room.code, game_type: @room.game_type }
    )
  end

  def player_events
    @room.players.order(:created_at).map do |player|
      Event.new(
        timestamp: player.created_at,
        event_type: "player_joined",
        description: "Player joined: #{player.name}",
        metadata: { player_id: player.id, player_name: player.name }
      )
    end
  end

  def game_event_records
    return [] unless @game

    @game.game_events.order(:created_at).map do |ge|
      Event.new(
        timestamp: ge.created_at,
        event_type: ge.event_name,
        description: format_game_event(ge),
        metadata: ge.metadata
      )
    end
  end

  def answer_events
    return [] unless @game

    case @game
    when SpeedTriviaGame
      trivia_answer_events
    when WriteAndVoteGame
      response_events
    when CategoryListGame
      category_answer_events
    else
      []
    end
  end

  def trivia_answer_events
    @game.trivia_answers
      .includes(:player, :trivia_question_instance)
      .where.not(submitted_at: nil)
      .order(:submitted_at)
      .map do |answer|
        Event.new(
          timestamp: answer.submitted_at,
          event_type: "answer_submitted",
          description: "#{answer.player.name} answered Q#{answer.trivia_question_instance.position}#{answer.correct? ? " (correct)" : ""}",
          metadata: { player_name: answer.player.name, correct: answer.correct?, points: answer.points_awarded }
        )
      end
  end

  def response_events
    @game.responses
      .includes(:player)
      .order(:created_at)
      .map do |response|
        Event.new(
          timestamp: response.created_at,
          event_type: "response_submitted",
          description: "#{response.player.name} submitted a response",
          metadata: { player_name: response.player.name, status: response.status }
        )
      end
  end

  def category_answer_events
    @game.category_answers
      .includes(:player, :category_instance)
      .order(:created_at)
      .map do |answer|
        Event.new(
          timestamp: answer.created_at,
          event_type: "answer_submitted",
          description: "#{answer.player.name} answered in #{answer.category_instance.name}",
          metadata: { player_name: answer.player.name, category: answer.category_instance.name }
        )
      end
  end

  def vote_events
    return [] unless @game.is_a?(WriteAndVoteGame)

    Vote.joins(response: :prompt_instance)
      .where(prompt_instances: { write_and_vote_game_id: @game.id })
      .includes(:player)
      .order(:created_at)
      .map do |vote|
        Event.new(
          timestamp: vote.created_at,
          event_type: "vote_cast",
          description: "#{vote.player.name} cast a vote",
          metadata: { player_name: vote.player.name }
        )
      end
  end

  def format_game_event(ge)
    case ge.event_name
    when "state_changed"
      "State: #{ge.metadata["from"]} → #{ge.metadata["to"]}"
    when "game_created"
      "Game started (#{ge.metadata["game_type"]})"
    when "game_finished"
      "Game finished (#{ge.metadata["duration_seconds"]}s)"
    else
      ge.event_name.humanize
    end
  end
end
