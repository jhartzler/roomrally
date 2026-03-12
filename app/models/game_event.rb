class GameEvent < ApplicationRecord
  belongs_to :eventable, polymorphic: true

  validates :event_name, presence: true

  def self.log(eventable, event_name, **metadata)
    create!(eventable:, event_name:, metadata:)
  rescue => e
    Rails.logger.warn("[GameEvent] Failed to log #{event_name}: #{e.message}")
  end
end
