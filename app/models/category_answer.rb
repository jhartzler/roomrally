class CategoryAnswer < ApplicationRecord
  belongs_to :player
  belongs_to :category_instance

  validates :player_id, uniqueness: { scope: :category_instance_id }

  enum :status, { pending: "pending", approved: "approved", rejected: "rejected", hidden: "hidden" }, default: :pending

  # Set by CategoryInstance#answers_with_duplicate_detection
  def auto_duplicate?
    instance_variable_get(:@auto_duplicate) || false
  end

  def effectively_struck?
    instance_variable_get(:@effectively_struck) || rejected? || duplicate?
  end
end
