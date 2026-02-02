class AbandonedGameCleanupJob < ApplicationJob
  queue_as :default

  def perform
    stale_rooms = Room.where.not(status: "finished")
                      .where("updated_at < ?", 24.hours.ago)

    stale_rooms.find_each do |room|
      room.current_game&.finish_game! if room.current_game&.may_finish_game?
      room.finish! if room.may_finish?
    end
  end
end
