class VotesController < ApplicationController
  def create
    unless current_player
      head :unauthorized
      return
    end

    room = current_player.room
    game = room.current_game

    if game.nil?
      Sentry.capture_message(
        "VotesController: no current game for room",
        level: :error,
        extra: { room_code: room.code }
      )
      head :unprocessable_content
      return
    end

    @response = Response.find(params[:vote][:response_id])

    Analytics.track(
      distinct_id: "player_#{current_player.session_id}",
      event: "vote_attempt",
      properties: {
        player_id: current_player.id,
        room_code: room.code,
        response_id: @response.id
      }
    )

    @vote = Vote.new(player: current_player, response: @response)

    unless @vote.save
      failure_reason = @vote.errors[:base].first || "unknown"
      Analytics.track(
        distinct_id: "player_#{current_player.session_id}",
        event: "vote_failed",
        properties: {
          player_id: current_player.id,
          room_code: room.code,
          response_id: @response.id,
          reason: failure_reason
        }
      )

      if @vote.errors[:base].include?("You cannot vote for your own response")
        head :forbidden
      elsif @vote.errors[:base].include?("You have already voted for this prompt")
        head :unprocessable_content
      else
        head :unprocessable_content
      end
      return
    end

    Games::WriteAndVote.process_vote(game:, vote: @vote)

    Analytics.track(
      distinct_id: "player_#{current_player.session_id}",
      event: "vote_cast",
      properties: {
        player_id: current_player.id,
        room_code: room.code,
        response_id: @response.id,
        game_id: game.id
      }
    )

    respond_to do |format|
      format.turbo_stream { head :ok }
    end
  end
end
