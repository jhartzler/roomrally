class SessionHealth
  STUCK_THRESHOLD = 30.minutes

  Flag = Struct.new(:severity, :description, keyword_init: true)

  def self.check(room)
    new(room).flags
  end

  def initialize(room)
    @room = room
    @game = room.current_game
  end

  def flags
    checks = []
    checks << check_stuck_state
    checks << check_never_started
    checks << check_abandoned_mid_game
    checks.concat(check_zero_submissions)
    checks.compact
  end

  private

  def check_stuck_state
    return unless @game
    return if @game.status.to_s == "finished"
    return if @game.updated_at > STUCK_THRESHOLD.ago

    Flag.new(
      severity: :error,
      description: "Game stuck in \"#{@game.status}\" for >30 min"
    )
  end

  def check_never_started
    return unless @room.players.any?
    return if @game

    Flag.new(
      severity: :warning,
      description: "Room has #{@room.players.count} player(s) but game never started"
    )
  end

  def check_abandoned_mid_game
    return unless @game
    return unless @room.status.to_s == "finished"
    return if @game.status.to_s == "finished"

    Flag.new(
      severity: :error,
      description: "Room closed but game abandoned in \"#{@game.status}\""
    )
  end

  def check_zero_submissions
    return [] unless @game
    return [] unless @game.status.to_s == "finished"

    @room.players.filter_map do |player|
      count = submission_count(player)
      next if count > 0

      Flag.new(
        severity: :warning,
        description: "#{player.name} had 0 submissions"
      )
    end
  end

  def submission_count(player)
    case @game
    when SpeedTriviaGame
      player.trivia_answers.where(trivia_question_instance: @game.trivia_question_instances).count
    when WriteAndVoteGame
      player.responses.where(prompt_instance: @game.prompt_instances).count
    when CategoryListGame
      CategoryAnswer.where(player:, category_instance: @game.category_instances).count
    else
      0
    end
  end
end
