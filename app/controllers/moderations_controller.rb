class ModerationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_response
  before_action :authorize_facilitator!

  def reject
    rejection_reason = params[:rejection_reason] || "Rejected by facilitator."

    if @response.update(status: "rejected", rejection_reason:)
      # Broadcasts will be handled here (Task 7/8)
      redirect_back(fallback_location: root_path, notice: "Response rejected.")
    else
      redirect_back(fallback_location: root_path, alert: "Failed to reject response.")
    end
  end

  private

  def set_response
    @response = Response.find(params[:id])
  end

  def authorize_facilitator!
    room = @response.prompt_instance.write_and_vote_game.room
    unless room.user == current_user
      redirect_to root_path, alert: "You are not authorized to moderate this game."
    end
  end
end
