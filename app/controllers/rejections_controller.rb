class RejectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_response
  before_action :authorize_facilitator!

  def new
  end

  def create
    rejection_reason = params[:rejection_reason] || "Rejected by facilitator."

    if @response.update(status: "rejected", rejection_reason:)
      GameBroadcaster.broadcast_response_rejection(response: @response)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove(ActionView::RecordIdentifier.dom_id(@response)),
            turbo_stream.update("modal", "")
          ]
        end
        format.html { redirect_back(fallback_location: root_path, notice: "Response rejected.") }
      end
    else
      redirect_back(fallback_location: root_path, alert: "Failed to reject response.")
    end
  end

  private

  def set_response
    @response = Response.find(params[:response_id])
  end

  def authorize_facilitator!
    room = @response.player.room
    unless room.user == current_user
      redirect_to root_path, alert: "You are not authorized to moderate this game."
    end
  end
end
