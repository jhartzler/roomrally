class GameChannel < ApplicationCable::Channel
  def subscribed
    @room = Room.find_by(code: params[:code])

    if @room
      stream_for @room
    else
      reject
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
