# frozen_string_literal: true

class ScoreTrackerEntriesController < ApplicationController
  before_action :set_room
  before_action :authorize_facilitator

  def create
    @entry = @room.score_tracker_entries.create!(entry_params)
    broadcast_score_tracker
    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to room_backstage_path(@room) }
    end
  end

  def update
    @entry = @room.score_tracker_entries.find(params[:id])

    if params[:increment]
      @entry.update!(score: @entry.score + params[:increment].to_i)
    else
      @entry.update!(entry_params)
    end

    broadcast_score_tracker
    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to room_backstage_path(@room) }
    end
  end

  def destroy
    @entry = @room.score_tracker_entries.find(params[:id])
    @entry.destroy!
    broadcast_score_tracker
    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to room_backstage_path(@room) }
    end
  end

  private

  def set_room
    @room = Room.find_by!(code: params[:room_code])
  end

  def authorize_facilitator
    return if current_user && current_user == @room.user

    redirect_to root_path, alert: "Not authorized."
  end

  def entry_params
    params.require(:score_tracker_entry).permit(:name, :score)
  end

  def broadcast_score_tracker
    Turbo::StreamsChannel.broadcast_update_to(
      @room,
      target: "score-tracker",
      partial: "score_tracker_entries/tracker",
      locals: { room: @room.reload }
    )
  end
end
